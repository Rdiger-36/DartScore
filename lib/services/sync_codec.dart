import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'sync_service.dart';

// ── Wire prefixes ─────────────────────────────────────────────────────────────

/// Marks a QR payload that carries a whole packet in the v2 binary format.
const String kSyncPrefixV2 = 'DS2:';

/// Marks one frame of a v2 payload that was too large for a single QR code.
const String kSyncChunkPrefixV2 = 'DS2C:';

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

/// Payload characters carried by one frame of an animated QR code.
///
/// Together with the frame header this stays inside a version 15 code at level
/// M, which holds 600 alphanumeric characters across 77 modules. That is about
/// as dense as a code can get and still be read reliably while it is moving.
const int kChunkPayloadChars = 570;

/// Largest frame [splitIntoFrames] may produce, headers included.
const int kChunkFrameMaxChars = 600;

/// Most frames an animated transfer may use.
///
/// One full pass takes this many times [kChunkFrameDuration], so the number is
/// really a limit on patience: half a minute of holding two phones together is
/// where the Wi-Fi transfer starts being the friendlier option. Expect a little
/// more than one pass in practice, because a frame the camera misses only comes
/// round again on the next one.
const int kMaxChunkFrames = 300;

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

/// How a packet gets to the other device, chosen from its encoded size.
enum SyncTransport {
  /// One still QR code.
  staticQr,

  /// A looping sequence of QR codes.
  animatedQr,

  /// A local HTTP server the receiver connects to over Wi-Fi.
  server,
}

/// Picks the transport for an already encoded [payload].
SyncTransport transportFor(String payload) {
  if (payload.length <= kStaticQrMaxChars) return SyncTransport.staticQr;
  if (frameCountFor(payload) <= kMaxChunkFrames) return SyncTransport.animatedQr;
  return SyncTransport.server;
}

/// Number of frames [payload] needs when sent as an animated QR code.
int frameCountFor(String payload) =>
    (payload.length / kChunkPayloadChars).ceil();

// ── Packet encoding ───────────────────────────────────────────────────────────

/// Wire format version written by [encodeSyncPayload].
const int _kBinaryFormatVersion = 2;

/// Bit flags packed into each throw's flag byte.
const int _kFlagDartsMask      = 0x03; // dartsUsed - 1, two bits
const int _kFlagBust           = 0x04;
const int _kFlagExplicitContext = 0x08;

/// Encodes [packet] into the string a QR code carries.
///
/// The packet becomes a compact binary record, which is then gzipped and
/// base64url encoded so it survives a QR code's character set. Compared to the
/// v1 JSON format this is roughly eight times smaller per throw, which is what
/// decides whether a sync fits into a single code.
String encodeSyncPayload(SyncPacket packet) {
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

  final compressed = gzip.encode(w.takeBytes());
  return '$kSyncPrefixV2${base45Encode(compressed)}';
}

/// Decodes a scanned or fetched [payload] back into a packet.
///
/// Accepts both the v2 binary format and the v1 gzipped JSON that older app
/// versions send. Throws a [FormatException] on anything else.
SyncPacket decodeSyncPayload(String payload) {
  if (payload.startsWith(kSyncPrefixV2)) {
    return _decodeBinary(
        gzip.decode(base45Decode(payload.substring(kSyncPrefixV2.length))));
  }
  if (payload.startsWith(kSyncPrefixV1)) {
    final compressed = base64Url.decode(payload.substring(kSyncPrefixV1.length));
    final json = utf8.decode(gzip.decode(compressed));
    return SyncPacket.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
  throw const FormatException('Unknown sync payload format');
}

/// Reads a v2 binary record back into a packet, restoring the fields the
/// encoder left out because they follow from the throw before.
SyncPacket _decodeBinary(List<int> bytes) {
  final r = _ByteReader(Uint8List.fromList(bytes));

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

// ── Chunked transfer ──────────────────────────────────────────────────────────

/// Splits [payload] into the frames an animated QR code cycles through.
///
/// Every frame names the transfer it belongs to by the checksum of the whole
/// payload, so a receiver that catches frames from two different senders, or
/// from the same sender after the data changed, can tell them apart instead of
/// stitching a corrupt packet together.
List<String> splitIntoFrames(String payload,
    {int chunkSize = kChunkPayloadChars}) {
  final total = (payload.length / chunkSize).ceil();
  // Uppercase, because every character of a frame has to stay inside the QR
  // alphanumeric set for the dense encoding to apply.
  final id = _crc32(payload).toRadixString(36).toUpperCase();

  return List.generate(total, (i) {
    final start = i * chunkSize;
    final end   = start + chunkSize;
    final chunk =
        payload.substring(start, end > payload.length ? payload.length : end);
    return '$kSyncChunkPrefixV2$i:$total:$id:$chunk';
  });
}

/// Collects the frames of an animated QR code until the payload is complete.
///
/// Frames arrive in whatever order the camera happens to catch them, the same
/// frame usually arrives many times, and the sender loops forever, so this only
/// has to keep what it has not seen yet and notice when nothing is missing.
class SyncFrameCollector {
  final Map<int, String> _chunks = {};
  String? _transferId;
  int _total = 0;

  /// Frames collected so far.
  int get received => _chunks.length;

  /// Frames the current transfer consists of, or 0 before the first frame.
  int get total => _total;

  /// Whether every frame has arrived.
  bool get isComplete => _total > 0 && _chunks.length == _total;

  /// Whether [raw] looks like a frame of an animated transfer.
  static bool isFrame(String raw) => raw.startsWith(kSyncChunkPrefixV2);

  /// Takes one scanned frame and reports whether it added anything new.
  ///
  /// A frame from a different transfer starts the collection over rather than
  /// being dropped: the sender may well have restarted with different data,
  /// and then the frames already held are the stale ones.
  bool add(String raw) {
    if (!isFrame(raw)) return false;

    final body  = raw.substring(kSyncChunkPrefixV2.length);
    final parts = body.split(':');
    if (parts.length < 4) return false;

    final seq   = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    final id    = parts[2];
    if (seq == null || total == null || total <= 0) return false;
    if (seq < 0 || seq >= total) return false;

    // The chunk itself may contain no colon, but rejoining is cheaper than
    // trusting that and it keeps the format free to grow another header field.
    final chunk = parts.sublist(3).join(':');

    if (_transferId != id) {
      _chunks.clear();
      _transferId = id;
      _total = total;
    }

    if (_chunks.containsKey(seq)) return false;
    _chunks[seq] = chunk;
    return true;
  }

  /// Reassembles the payload once [isComplete], verifying the checksum.
  ///
  /// Throws a [FormatException] when the reassembled payload does not match the
  /// checksum every frame carried, which means frames from different transfers
  /// got mixed up.
  String assemble() {
    if (!isComplete) {
      throw const FormatException('Sync transfer is still incomplete');
    }
    final payload = List.generate(_total, (i) => _chunks[i]!).join();
    if (_crc32(payload).toRadixString(36).toUpperCase() != _transferId) {
      throw const FormatException('Sync transfer failed its checksum');
    }
    return payload;
  }

  /// Drops everything collected so far.
  void reset() {
    _chunks.clear();
    _transferId = null;
    _total = 0;
  }
}

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

/// CRC-32 of [input]'s UTF-8 bytes, used to identify and verify a transfer.
int _crc32(String input) {
  var crc = 0xFFFFFFFF;
  for (final byte in utf8.encode(input)) {
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
