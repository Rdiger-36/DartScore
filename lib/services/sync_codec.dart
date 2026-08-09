import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sync_service.dart';

// ── Wire prefixes ─────────────────────────────────────────────────────────────

/// Marks a QR payload that carries a whole packet in the v2 binary format.
const String kSyncPrefixV2 = 'DS2:';

/// Marks one frame of a payload streamed as an animated QR code.
const String kSyncFramePrefix = 'DS3:';

/// Marks a payload in the v1 format (gzipped JSON). Only ever decoded, never
/// written: older app versions still send it and must stay importable.
const String kSyncPrefixV1 = 'QR1:';

// ── Transport sizing ──────────────────────────────────────────────────────────

/// Largest payload still shown as a single QR code.
///
/// Payloads are base45 so that they fit the QR alphanumeric character set,
/// where a code holds 3391 characters at version 40 and error correction M
/// against 2331 in byte mode. Staying under that is not only about fitting: a
/// code near the limit is 177 modules wide, and a phone reading that off
/// another phone's screen needs the redundancy of level M to manage it.
const int kStaticQrMaxChars = 3200;

/// Bytes of the payload each source block of an animated transfer holds.
///
/// Base45 turns these into 540 characters, which together with the frame
/// header stays inside a version 15 code at level M: 600 alphanumeric
/// characters across 77 modules, about as dense as a code can get and still be
/// read reliably while it is moving.
const int kBlockSizeBytes = 360;

/// Largest frame [SyncFountainEncoder] may produce, header included.
const int kFrameMaxChars = 600;

/// How long an animated transfer may typically take.
///
/// Half a minute of holding two phones together is where the Wi-Fi transfer
/// starts being the friendlier option. Unlike the numbered sequence this
/// replaced, the figure is now a fair one: a fountain coded transfer finishes
/// when it has caught enough frames, whichever ones, rather than waiting out
/// another full loop for the one the camera blinked through.
const Duration kMaxTransferDuration = Duration(seconds: 30);

/// How long a single frame of an animated QR code stays on screen.
///
/// The floor here is not the sender but the camera reading it. The receiver
/// samples every [kScannerDetectionTimeout], so frames have to last longer
/// than that to be caught reliably, and at 60Hz a frame this long still covers
/// six display refreshes, which keeps the camera from catching a transition.
const Duration kChunkFrameDuration = Duration(milliseconds: 100);

/// How often the receiver's camera is allowed to report a decoded code.
///
/// Kept below [kChunkFrameDuration] so that every frame the sender shows falls
/// inside at least one sampling window, whatever the phase between the two.
const Duration kScannerDetectionTimeout = Duration(milliseconds: 50);

/// Frames a transfer typically takes per source block.
///
/// A fountain code needs somewhat more symbols than it has blocks before it can
/// decode, measured at about 1.25 for the block counts that matter here, and
/// the camera misses some of what passes it on top of that. This sets both the
/// duration shown to the user and, through it, [kMaxSourceBlocks].
const double kFramesPerBlock = 1.4;

/// Most source blocks an animated transfer may be split into, derived from how
/// long [kMaxTransferDuration] allows it to run.
final int kMaxSourceBlocks = (kMaxTransferDuration.inMilliseconds /
        (kFramesPerBlock * kChunkFrameDuration.inMilliseconds))
    .floor();

/// How a packet gets to the other device, chosen from its encoded size.
enum SyncTransport {
  /// One still QR code.
  staticQr,

  /// An endless stream of QR codes carrying a fountain coded payload.
  animatedQr,

  /// A local HTTP server the receiver connects to over Wi-Fi.
  server,
}

/// One packet, encoded and sized up, ready for whichever transport it needs.
class SyncTransmission {
  /// The compressed packet the animated transfer streams.
  final Uint8List data;

  /// The whole packet in one string, for the single code and the Wi-Fi reply.
  final String payload;

  /// How this packet should travel.
  final SyncTransport transport;

  /// Source blocks the animated transfer splits [data] into.
  final int sourceBlocks;

  const SyncTransmission({
    required this.data,
    required this.payload,
    required this.transport,
    required this.sourceBlocks,
  });

  /// Roughly how long an animated transfer takes, for the sender to show.
  Duration get estimatedDuration => Duration(
      milliseconds: (sourceBlocks *
              kFramesPerBlock *
              kChunkFrameDuration.inMilliseconds)
          .round());
}

/// Encodes [packet] and works out how it should travel.
SyncTransmission prepareTransmission(SyncPacket packet) {
  final data = encodeSyncBytes(packet);
  final payload = '$kSyncPrefixV2${base45Encode(data)}';
  final blocks = (data.length / kBlockSizeBytes).ceil();

  final transport = payload.length <= kStaticQrMaxChars
      ? SyncTransport.staticQr
      : blocks <= kMaxSourceBlocks
          ? SyncTransport.animatedQr
          : SyncTransport.server;

  return SyncTransmission(
    data: data,
    payload: payload,
    transport: transport,
    sourceBlocks: blocks,
  );
}

// ── Packet encoding ───────────────────────────────────────────────────────────

/// Wire format version written by [encodeSyncPayload].
const int _kBinaryFormatVersion = 2;

/// Bit flags packed into each throw's flag byte.
const int _kFlagDartsMask      = 0x03; // dartsUsed - 1, two bits
const int _kFlagBust           = 0x04;
const int _kFlagExplicitContext = 0x08;

/// Encodes [packet] into the string a QR code carries.
String encodeSyncPayload(SyncPacket packet) =>
    '$kSyncPrefixV2${base45Encode(encodeSyncBytes(packet))}';

/// Encodes [packet] into the compressed bytes every transport builds on.
///
/// The packet becomes a compact binary record, which is then gzipped. What the
/// transports add on top is only framing: base45 for a QR code's character set,
/// and the fountain code for an animated one.
Uint8List encodeSyncBytes(SyncPacket packet) {
  final w = _ByteWriter();

  w.u8(_kBinaryFormatVersion);
  w.varint(packet.rangeDays ?? 0);
  w.str(packet.senderDevice);
  w.str(packet.playerUuid);
  w.str(packet.playerName);
  w.str(packet.favoriteDoubles);

  final s = packet.stats;
  w.varint(s.totalDarts);
  w.varint(s.totalVisits);
  w.varint(s.legsWon);
  w.varint(s.highestVisit);
  w.varint(s.busts);
  w.varint(s.count180);
  w.varint((s.average * 100).round());

  // The snapshot stays an opaque string: it is a growing set of counters, and
  // unpacking it into fixed fields here would silently drop whichever counter
  // gets added to it next.
  w.str(packet.localStatsJson ?? '');

  final throws = packet.throws;
  w.varint(throws.length);
  w.varint(throws.isEmpty ? 0 : throws.first.thrownAt);

  int previousTime = throws.isEmpty ? 0 : throws.first.thrownAt;
  int? expectedRemaining;
  int previousLeg = -1;
  int previousSet = -1;

  for (final t in throws) {
    // Only what cannot be derived from the throw before it goes on the wire.
    final contextKnown = expectedRemaining == t.remainingBefore &&
        previousLeg == t.leg &&
        previousSet == t.set;

    var flags = (t.dartsUsed - 1) & _kFlagDartsMask;
    if (t.bust) flags |= _kFlagBust;
    if (!contextKnown) flags |= _kFlagExplicitContext;

    w.u8(t.score);
    w.u8(flags);
    w.zigzagVarint(t.thrownAt - previousTime);
    if (!contextKnown) {
      w.varint(t.leg);
      w.varint(t.set);
      w.varint(t.remainingBefore);
    }

    previousTime     = t.thrownAt;
    previousLeg      = t.leg;
    previousSet      = t.set;
    expectedRemaining = t.bust ? t.remainingBefore : t.remainingBefore - t.score;
  }

  return Uint8List.fromList(gzip.encode(w.takeBytes()));
}

/// Decodes a scanned or fetched [payload] back into a packet.
///
/// Accepts both the v2 binary format and the v1 gzipped JSON that older app
/// versions send. Throws a [FormatException] on anything else.
SyncPacket decodeSyncPayload(String payload) {
  if (payload.startsWith(kSyncPrefixV2)) {
    return decodeSyncBytes(base45Decode(payload.substring(kSyncPrefixV2.length)));
  }
  if (payload.startsWith(kSyncPrefixV1)) {
    final compressed = base64Url.decode(payload.substring(kSyncPrefixV1.length));
    final json = utf8.decode(gzip.decode(compressed));
    return SyncPacket.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
  throw const FormatException('Unknown sync payload format');
}

/// Reads the compressed bytes [encodeSyncBytes] produced back into a packet,
/// restoring the fields the encoder left out because they follow from the
/// throw before.
SyncPacket decodeSyncBytes(Uint8List compressed) {
  final r = _ByteReader(Uint8List.fromList(gzip.decode(compressed)));

  final version = r.u8();
  if (version != _kBinaryFormatVersion) {
    throw FormatException('Unsupported sync format version: $version');
  }

  final rangeDays       = r.varint();
  final senderDevice    = r.str();
  final playerUuid      = r.str();
  final playerName      = r.str();
  final favoriteDoubles = r.str();

  final stats = SyncStats(
    totalDarts:   r.varint(),
    totalVisits:  r.varint(),
    legsWon:      r.varint(),
    highestVisit: r.varint(),
    busts:        r.varint(),
    count180:     r.varint(),
    average:      r.varint() / 100,
  );

  final localStats = r.str();
  final throwCount = r.varint();

  var time = r.varint();
  var remaining = 0;
  var leg = 0;
  var set = 0;

  final throws = <SyncThrow>[];
  for (var i = 0; i < throwCount; i++) {
    final score = r.u8();
    final flags = r.u8();
    final bust  = flags & _kFlagBust != 0;

    time += r.zigzagVarint();

    if (flags & _kFlagExplicitContext != 0) {
      leg       = r.varint();
      set       = r.varint();
      remaining = r.varint();
    }

    throws.add(SyncThrow(
      score:           score,
      dartsUsed:       (flags & _kFlagDartsMask) + 1,
      remainingBefore: remaining,
      thrownAt:        time,
      bust:            bust,
      leg:             leg,
      set:             set,
    ));

    remaining = bust ? remaining : remaining - score;
  }

  return SyncPacket(
    version:         version,
    senderDevice:    senderDevice,
    playerUuid:      playerUuid,
    playerName:      playerName,
    favoriteDoubles: favoriteDoubles,
    stats:           stats,
    throws:          throws,
    localStatsJson:  localStats.isEmpty ? null : localStats,
    rangeDays:       rangeDays == 0 ? null : rangeDays,
  );
}

// ── Animated transfer ─────────────────────────────────────────────────────────

/// Streams a payload as an endless sequence of fountain coded frames.
///
/// Every frame is the exclusive or of a few source blocks, chosen by a seed the
/// frame carries. The receiver does not need a particular frame, only enough of
/// them: any set slightly larger than the block count decodes the whole
/// payload. That is what a plain numbered sequence cannot do, where one frame
/// the camera blinked through means waiting a full loop for it to come round
/// again, and where a hand tremor or a refocus in step with the loop can miss
/// the same frames pass after pass.
class SyncFountainEncoder {
  /// The padded source blocks, all [kBlockSizeBytes] long.
  final List<Uint8List> _blocks;

  /// Length of the original payload, so the receiver can drop the padding.
  final int _length;

  /// Checksum of the payload, identifying this transfer to the receiver.
  final int _checksum;

  /// Degree distribution the frame seeds draw from.
  final List<double> _degreeCdf;

  /// Where in the seed space this transfer starts.
  final int _origin;

  /// Wraps [data] for streaming, starting at [startOffset] in the seed space.
  ///
  /// The offset is random by default, and that matters. The seeds decide which
  /// blocks each frame combines, so a fixed start would give every transfer of
  /// a given block count the exact same sequence, and a block count whose
  /// sequence happens to be a poor one would be poor forever. A random start
  /// turns that into luck that differs from transfer to transfer.
  SyncFountainEncoder(Uint8List data, {int? startOffset})
      : _blocks = _splitIntoBlocks(data),
        _length = data.length,
        _checksum = _crc32(data),
        _degreeCdf = _robustSolitonCdf((data.length / kBlockSizeBytes).ceil()),
        _origin = startOffset ?? math.Random().nextInt(1 << 30);

  /// How many blocks the payload was split into.
  int get sourceBlocks => _blocks.length;

  /// The frame at stream position [index]. The sender only ever counts up.
  String frameAt(int index) {
    // Seeds start at 1: a zero state would leave the generator stuck there.
    final seed = _origin + index + 1;
    final combined = Uint8List(kBlockSizeBytes);
    for (final block in _pickBlocks(seed, _blocks.length, _degreeCdf)) {
      final source = _blocks[block];
      for (var i = 0; i < kBlockSizeBytes; i++) {
        combined[i] ^= source[i];
      }
    }

    final header = '$kSyncFramePrefix${_base36(seed)}:${_blocks.length}:'
        '${_base36(_length)}:${_base36(_checksum)}:';
    return '$header${base45Encode(combined)}';
  }
}

/// Collects fountain coded frames until the payload can be reconstructed.
///
/// Frames are solved as they arrive: one that combines a single unknown block
/// reveals it, which may in turn reduce frames held back earlier, so the work
/// is spread over the transfer rather than done in one pass at the end.
class SyncFountainDecoder {
  /// Blocks recovered so far, by index.
  final Map<int, Uint8List> _solved = {};

  /// Frames that still combine more than one unknown block.
  final List<_PendingFrame> _pending = [];

  int _sourceBlocks = 0;
  int _length = 0;
  int? _checksum;
  List<double>? _degreeCdf;

  /// Blocks recovered so far.
  int get solved => _solved.length;

  /// Blocks the payload consists of, or 0 before the first frame.
  int get sourceBlocks => _sourceBlocks;

  /// Whether every block has been recovered.
  bool get isComplete => _sourceBlocks > 0 && _solved.length == _sourceBlocks;

  /// Whether [raw] looks like a frame of an animated transfer.
  static bool isFrame(String raw) => raw.startsWith(kSyncFramePrefix);

  /// Takes one scanned frame and reports whether it recovered anything new.
  ///
  /// A frame from a different transfer starts the collection over rather than
  /// being dropped: the sender may well have restarted with different data, and
  /// then it is what has been collected so far that is stale.
  bool add(String raw) {
    if (!isFrame(raw)) return false;

    final parts = raw.substring(kSyncFramePrefix.length).split(':');
    if (parts.length < 5) return false;

    final seed     = _parseBase36(parts[0]);
    final blocks   = int.tryParse(parts[1]);
    final length   = _parseBase36(parts[2]);
    final checksum = _parseBase36(parts[3]);
    if (seed == null || blocks == null || length == null || checksum == null) {
      return false;
    }
    if (seed <= 0 || blocks <= 0 || blocks > kMaxSourceBlocks || length <= 0) {
      return false;
    }

    final Uint8List value;
    try {
      value = base45Decode(parts.sublist(4).join(':'));
    } on FormatException {
      return false;
    }
    if (value.length != kBlockSizeBytes) return false;

    if (_checksum != checksum) {
      _solved.clear();
      _pending.clear();
      _checksum    = checksum;
      _sourceBlocks = blocks;
      _length      = length;
      _degreeCdf   = _robustSolitonCdf(blocks);
    }

    return _absorb(_PendingFrame(
      unknowns: _pickBlocks(seed, _sourceBlocks, _degreeCdf!).toSet(),
      value: value,
    ));
  }

  /// Folds [frame] into what is known, cascading through the frames held back
  /// whenever a block is recovered. Returns whether anything was recovered.
  bool _absorb(_PendingFrame frame) {
    var recoveredAny = false;
    var next = frame;

    while (true) {
      // Strip the blocks that are already known out of this frame.
      for (final index in next.unknowns.toList()) {
        final block = _solved[index];
        if (block == null) continue;
        for (var i = 0; i < kBlockSizeBytes; i++) {
          next.value[i] ^= block[i];
        }
        next.unknowns.remove(index);
      }

      if (next.unknowns.length != 1) {
        // Nothing to learn from it yet, but it may become useful later.
        if (next.unknowns.isNotEmpty) _pending.add(next);
        return recoveredAny;
      }

      final index = next.unknowns.first;
      _solved[index] = next.value;
      recoveredAny = true;

      // A recovered block may reduce a frame held back earlier to one unknown.
      final ready = _pending.where((f) => f.unknowns.contains(index)).toList();
      if (ready.isEmpty) return recoveredAny;
      _pending.removeWhere((f) => f.unknowns.contains(index));

      // Continue with the first, queue the rest by absorbing them in turn.
      next = ready.first;
      for (final other in ready.skip(1)) {
        if (_absorb(other)) recoveredAny = true;
      }
    }
  }

  /// Reassembles the payload once [isComplete], verifying the checksum.
  Uint8List assemble() {
    if (!isComplete) {
      throw const FormatException('Sync transfer is still incomplete');
    }

    final out = Uint8List(_sourceBlocks * kBlockSizeBytes);
    for (var i = 0; i < _sourceBlocks; i++) {
      out.setRange(i * kBlockSizeBytes, (i + 1) * kBlockSizeBytes, _solved[i]!);
    }

    final payload = Uint8List.sublistView(out, 0, _length);
    if (_crc32(payload) != _checksum) {
      throw const FormatException('Sync transfer failed its checksum');
    }
    return Uint8List.fromList(payload);
  }

  /// Drops everything collected so far.
  void reset() {
    _solved.clear();
    _pending.clear();
    _sourceBlocks = 0;
    _length = 0;
    _checksum = null;
    _degreeCdf = null;
  }
}

/// A received frame that still combines more than one unrecovered block.
class _PendingFrame {
  final Set<int> unknowns;
  final Uint8List value;

  _PendingFrame({required this.unknowns, required this.value});
}

/// Cuts [data] into equal blocks, zero padding the last one.
List<Uint8List> _splitIntoBlocks(Uint8List data) {
  final count = (data.length / kBlockSizeBytes).ceil();
  return List.generate(count, (i) {
    final block = Uint8List(kBlockSizeBytes);
    final start = i * kBlockSizeBytes;
    final end   = (start + kBlockSizeBytes).clamp(0, data.length);
    if (start < data.length) {
      block.setRange(0, end - start, data, start);
    }
    return block;
  });
}

/// The block indices the frame with [seed] combines.
///
/// Both sides derive this from the seed alone, so a frame needs to carry only
/// the seed rather than the list. The generator is written out here instead of
/// using `Random`, whose sequence for a given seed is not promised to stay the
/// same across Dart versions, and the two devices may well not run the same one.
List<int> _pickBlocks(int seed, int blockCount, List<double> degreeCdf) {
  // The seeds are consecutive, and a raw xorshift started on 1, 2, 3 in turn
  // produces near identical first outputs, which would make consecutive frames
  // near identical too. Scrambling the seed first breaks that up.
  var state = _scramble(seed);
  if (state == 0) state = 1;

  int nextRandom() {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state;
  }

  double nextDouble() => nextRandom() / 0x100000000;

  // Degree first, then that many distinct blocks by partial shuffle.
  final roll = nextDouble();
  var degree = 1;
  while (degree < degreeCdf.length && degreeCdf[degree - 1] < roll) {
    degree++;
  }
  if (degree > blockCount) degree = blockCount;

  final pool = List.generate(blockCount, (i) => i);
  for (var i = 0; i < degree; i++) {
    final j = i + nextRandom() % (blockCount - i);
    final swap = pool[i];
    pool[i] = pool[j];
    pool[j] = swap;
  }
  return pool.sublist(0, degree);
}

/// Cumulative robust soliton distribution over degrees 1 to [blockCount].
///
/// The shape matters: mostly small degrees so frames keep revealing blocks one
/// at a time, with a deliberate spike at a larger degree that sweeps up the
/// blocks the small ones keep missing. Without that spike a transfer stalls
/// near the end with a handful of blocks no frame ever touches.
List<double> _robustSolitonCdf(int blockCount) {
  if (blockCount <= 1) return [1];

  const delta = 0.5;
  const c = 0.1;
  final spikeAt =
      (c * math.log(blockCount / delta) * math.sqrt(blockCount)).round().clamp(1, blockCount);

  final weights = List<double>.filled(blockCount + 1, 0);
  for (var d = 1; d <= blockCount; d++) {
    // Ideal soliton.
    weights[d] = d == 1 ? 1 / blockCount : 1 / (d * (d - 1));
    // Robust part.
    if (d < spikeAt) {
      weights[d] += spikeAt / (d * blockCount);
    } else if (d == spikeAt) {
      weights[d] += spikeAt * math.log(1 / delta) / blockCount;
    }
  }

  final total = weights.reduce((a, b) => a + b);
  final cdf = List<double>.filled(blockCount, 0);
  var running = 0.0;
  for (var d = 1; d <= blockCount; d++) {
    running += weights[d] / total;
    cdf[d - 1] = running;
  }
  cdf[blockCount - 1] = 1;
  return cdf;
}

/// Spreads consecutive integers across the 32 bit range.
///
/// The avalanche step of a hash, without the hash: neighbouring inputs come out
/// entirely unrelated, which is what turns a counter into usable seeds.
int _scramble(int value) {
  var x = value & 0xFFFFFFFF;
  x = ((x ^ (x >> 16)) * 0x7FEB352D) & 0xFFFFFFFF;
  x = ((x ^ (x >> 15)) * 0x846CA68B) & 0xFFFFFFFF;
  return (x ^ (x >> 16)) & 0xFFFFFFFF;
}

/// Uppercase base36, which the QR alphanumeric mode carries.
String _base36(int value) => value.toRadixString(36).toUpperCase();

/// Parses [_base36], returning null when it is not a number.
int? _parseBase36(String value) => int.tryParse(value, radix: 36);

// ── Base45 ────────────────────────────────────────────────────────────────────

/// The 45 characters a QR code can carry in its alphanumeric mode.
///
/// That mode spends 5.5 bits per character against the byte mode's 8, and
/// base45 fills it almost exactly: two bytes become three characters, so a
/// payload costs 16.5 bits per two bytes instead of 21.3. The result is about
/// a third more data in a code of the same size, which is the difference
/// between one still code and a sequence of them.
const String _kBase45Alphabet =
    r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

/// Character to value lookup for [base45Decode].
final Map<int, int> _base45Values = {
  for (var i = 0; i < _kBase45Alphabet.length; i++)
    _kBase45Alphabet.codeUnitAt(i): i,
};

/// Whether [data] consists only of characters a QR code can carry in its
/// alphanumeric mode.
bool isAlphanumericSafe(String data) =>
    data.codeUnits.every(_base45Values.containsKey);

/// Encodes [bytes] as base45, per RFC 9285.
///
/// Pairs of bytes become three characters holding the value least significant
/// digit first; a trailing odd byte becomes two.
String base45Encode(List<int> bytes) {
  final out = StringBuffer();

  var i = 0;
  for (; i + 1 < bytes.length; i += 2) {
    var value = bytes[i] * 256 + bytes[i + 1];
    out.write(_kBase45Alphabet[value % 45]);
    value ~/= 45;
    out.write(_kBase45Alphabet[value % 45]);
    out.write(_kBase45Alphabet[value ~/ 45]);
  }

  if (i < bytes.length) {
    final value = bytes[i];
    out.write(_kBase45Alphabet[value % 45]);
    out.write(_kBase45Alphabet[value ~/ 45]);
  }

  return out.toString();
}

/// Decodes a base45 string back into bytes.
///
/// Throws a [FormatException] on an unknown character, a length that cannot
/// have come from [base45Encode], or a group whose value is out of range,
/// which is what a corrupted or truncated payload looks like.
Uint8List base45Decode(String input) {
  final values = <int>[];
  for (final unit in input.codeUnits) {
    final value = _base45Values[unit];
    if (value == null) {
      throw const FormatException('Invalid character in base45 payload');
    }
    values.add(value);
  }

  final out = BytesBuilder(copy: false);

  var i = 0;
  for (; i + 2 < values.length; i += 3) {
    final value = values[i] + values[i + 1] * 45 + values[i + 2] * 2025;
    if (value > 0xFFFF) {
      throw const FormatException('Base45 group out of range');
    }
    out.addByte(value >> 8);
    out.addByte(value & 0xFF);
  }

  switch (values.length - i) {
    case 0:
      break;
    case 2:
      final value = values[i] + values[i + 1] * 45;
      if (value > 0xFF) {
        throw const FormatException('Base45 group out of range');
      }
      out.addByte(value);
    default:
      throw const FormatException('Truncated base45 payload');
  }

  return out.takeBytes();
}

// ── Checksum ──────────────────────────────────────────────────────────────────

/// Lazily built CRC-32 lookup table (IEEE polynomial, reflected).
final List<int> _crcTable = List.generate(256, (i) {
  var c = i;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// CRC-32 of [bytes], used to identify a transfer and to verify it at the end.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// ── Byte plumbing ─────────────────────────────────────────────────────────────

/// Appends primitives to a growing byte buffer.
class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  /// Writes one byte.
  void u8(int value) => _builder.addByte(value & 0xFF);

  /// Writes an unsigned integer as LEB128, seven bits per byte.
  void varint(int value) {
    var v = value;
    while (v >= 0x80) {
      _builder.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _builder.addByte(v);
  }

  /// Writes a signed integer, mapping it onto an unsigned one first so that
  /// small negative values stay short.
  void zigzagVarint(int value) => varint((value << 1) ^ (value >> 63));

  /// Writes a length-prefixed UTF-8 string.
  void str(String value) {
    final bytes = utf8.encode(value);
    varint(bytes.length);
    _builder.add(bytes);
  }

  /// Returns everything written and empties the buffer.
  Uint8List takeBytes() => _builder.takeBytes();
}

/// Reads back what [_ByteWriter] produced.
class _ByteReader {
  final Uint8List _bytes;
  int _pos = 0;

  _ByteReader(this._bytes);

  /// Reads one byte.
  int u8() {
    if (_pos >= _bytes.length) {
      throw const FormatException('Sync payload ended early');
    }
    return _bytes[_pos++];
  }

  /// Reads an LEB128 unsigned integer.
  int varint() {
    var result = 0;
    var shift  = 0;
    while (true) {
      final byte = u8();
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
      if (shift > 63) throw const FormatException('Malformed sync payload');
    }
  }

  /// Reads a zigzag encoded signed integer.
  int zigzagVarint() {
    final v = varint();
    return (v >> 1) ^ -(v & 1);
  }

  /// Reads a length-prefixed UTF-8 string.
  String str() {
    final length = varint();
    if (_pos + length > _bytes.length) {
      throw const FormatException('Sync payload ended early');
    }
    final value = utf8.decode(_bytes.sublist(_pos, _pos + length));
    _pos += length;
    return value;
  }
}
