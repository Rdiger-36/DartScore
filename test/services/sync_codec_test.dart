import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartscore_app/services/sync_codec.dart';
import 'package:dartscore_app/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sync payload is the one place where a throw is not stored but described,
/// so a field the encoder forgets is gone for good on the receiving device.
/// These tests pin the round trip field by field, and pin the size too: how many
/// throws fit into one QR code is what decides whether a sync needs the camera
/// for a moment or a shared Wi-Fi.
void main() {
  /// A throw with sensible defaults, so each test only states what it is about.
  SyncThrow t({
    int score = 60,
    int dartsUsed = 3,
    required int remainingBefore,
    required int thrownAt,
    bool bust = false,
    int leg = 1,
    int set = 1,
  }) =>
      SyncThrow(
        score: score,
        dartsUsed: dartsUsed,
        remainingBefore: remainingBefore,
        thrownAt: thrownAt,
        bust: bust,
        leg: leg,
        set: set,
      );

  /// A packet around [throws], with every non-throw field filled in.
  SyncPacket packetOf(List<SyncThrow> throws, {int? rangeDays}) => SyncPacket(
        version: 2,
        senderDevice: 'iPhone',
        playerUuid: '3f2a1c9e-7b4d-4e51-9a08-6c2d5f7b1e33',
        playerName: 'Björn',
        favoriteDoubles: 'D20,D16',
        localStatsJson: '{"total_darts":1200,"count_180":7}',
        rangeDays: rangeDays,
        stats: const SyncStats(
          totalDarts: 1200,
          totalVisits: 400,
          average: 62.37,
          legsWon: 18,
          highestVisit: 180,
          busts: 21,
          count180: 7,
        ),
        throws: throws,
      );

  /// Asserts that [packet] survives encoding and decoding unchanged.
  void expectRoundTrip(SyncPacket packet) {
    final decoded = decodeSyncPayload(encodeSyncPayload(packet));

    expect(decoded.senderDevice,    packet.senderDevice);
    expect(decoded.playerUuid,      packet.playerUuid);
    expect(decoded.playerName,      packet.playerName);
    expect(decoded.favoriteDoubles, packet.favoriteDoubles);
    expect(decoded.localStatsJson,  packet.localStatsJson);
    expect(decoded.rangeDays,       packet.rangeDays);

    expect(decoded.stats.totalDarts,   packet.stats.totalDarts);
    expect(decoded.stats.totalVisits,  packet.stats.totalVisits);
    expect(decoded.stats.average,      closeTo(packet.stats.average, 0.005));
    expect(decoded.stats.legsWon,      packet.stats.legsWon);
    expect(decoded.stats.highestVisit, packet.stats.highestVisit);
    expect(decoded.stats.busts,        packet.stats.busts);
    expect(decoded.stats.count180,     packet.stats.count180);

    expect(decoded.throws.length, packet.throws.length);
    for (var i = 0; i < packet.throws.length; i++) {
      final a = packet.throws[i];
      final b = decoded.throws[i];
      final at = 'throw $i';
      expect(b.score,           a.score,           reason: at);
      expect(b.dartsUsed,       a.dartsUsed,       reason: at);
      expect(b.remainingBefore, a.remainingBefore, reason: at);
      expect(b.thrownAt,        a.thrownAt,        reason: at);
      expect(b.bust,            a.bust,            reason: at);
      expect(b.leg,             a.leg,             reason: at);
      expect(b.set,             a.set,             reason: at);
    }
  }

  group('base45', () {
    test('round trips bytes of both even and odd length', () {
      for (final length in [0, 1, 2, 3, 4, 5, 255, 256, 1000, 1001]) {
        final bytes = List.generate(length, (i) => (i * 37 + 11) % 256);
        expect(base45Decode(base45Encode(bytes)), bytes,
            reason: 'length $length');
      }
    });

    test('covers the whole byte range', () {
      final bytes = List.generate(256, (i) => i);
      expect(base45Decode(base45Encode(bytes)), bytes);
    });

    test('matches the examples in RFC 9285', () {
      expect(base45Encode(utf8.encode('AB')), 'BB8');
      expect(base45Encode(utf8.encode('Hello!!')), '%69 VD92EX0');
      expect(base45Encode(utf8.encode('base-45')), 'UJCLQE7W581');
      expect(utf8.decode(base45Decode('QED8WEX0')), 'ietf!');
    });

    test('produces only characters a QR code can carry densely', () {
      final bytes = List.generate(2000, (i) => (i * 91 + 7) % 256);
      expect(isAlphanumericSafe(base45Encode(bytes)), isTrue);
    });

    test('rejects a corrupted payload', () {
      expect(() => base45Decode('AB_'), throwsFormatException,
          reason: 'underscore is not in the alphabet');
      expect(() => base45Decode('A'), throwsFormatException,
          reason: 'a single character cannot be a group');
      expect(() => base45Decode(':::'), throwsFormatException,
          reason: 'group value above 0xFFFF');
    });
  });

  group('packet round trip', () {
    test('carries a leg with a bust and a checkout', () {
      const start = 1770000000000;
      expectRoundTrip(packetOf([
        t(score: 180, remainingBefore: 501, thrownAt: start),
        t(score: 180, remainingBefore: 321, thrownAt: start + 41000),
        // Busts leave the remaining score untouched, which the decoder has to
        // reproduce rather than subtract.
        t(score: 60, remainingBefore: 141, thrownAt: start + 77000, bust: true),
        t(score: 60, remainingBefore: 141, thrownAt: start + 118000),
        t(score: 81, dartsUsed: 3, remainingBefore: 81, thrownAt: start + 155000),
      ]));
    });

    test('carries leg and set changes', () {
      const start = 1770000000000;
      expectRoundTrip(packetOf([
        t(score: 100, remainingBefore: 501, thrownAt: start, leg: 1, set: 1),
        t(score: 140, remainingBefore: 501, thrownAt: start + 60000, leg: 2, set: 1),
        t(score: 45, remainingBefore: 501, thrownAt: start + 130000, leg: 1, set: 2),
      ]));
    });

    test('carries one and two dart visits', () {
      const start = 1770000000000;
      expectRoundTrip(packetOf([
        t(score: 40, dartsUsed: 1, remainingBefore: 40, thrownAt: start),
        t(score: 32, dartsUsed: 2, remainingBefore: 32, thrownAt: start + 55000),
        t(score: 0, dartsUsed: 3, remainingBefore: 170, thrownAt: start + 96000),
      ]));
    });

    test('carries a packet without throws', () {
      expectRoundTrip(packetOf([]));
    });

    test('carries a range and a missing snapshot', () {
      final packet = SyncPacket(
        version: 2,
        senderDevice: 'Android',
        playerUuid: 'a1',
        playerName: 'A',
        favoriteDoubles: '',
        rangeDays: 7,
        stats: const SyncStats(
          totalDarts: 0, totalVisits: 0, average: 0,
          legsWon: 0, highestVisit: 0, busts: 0, count180: 0,
        ),
        throws: [t(remainingBefore: 501, thrownAt: 1770000000000)],
      );
      expectRoundTrip(packet);
      expect(decodeSyncPayload(encodeSyncPayload(packet)).localStatsJson, isNull);
    });

    test('keeps timestamps to the millisecond, they are the dedup key', () {
      const start = 1770000000123;
      final packet = packetOf([
        t(remainingBefore: 501, thrownAt: start),
        t(remainingBefore: 441, thrownAt: start + 40317),
        t(remainingBefore: 381, thrownAt: start + 91004),
      ]);
      final decoded = decodeSyncPayload(encodeSyncPayload(packet));
      expect(decoded.throws.map((x) => x.thrownAt),
          [start, start + 40317, start + 91004]);
    });
  });

  group('payload size', () {
    /// 500 visits shaped like real play: a 501 leg finished in 15 to 18 visits,
    /// the usual spread of scores, an occasional bust, roughly 40 seconds
    /// between one visit and the player's next.
    List<SyncThrow> realisticThrows(int count) {
      final random = Random(42);
      const scores = [26, 41, 45, 55, 60, 60, 66, 81, 85, 95, 100, 121, 140, 180];

      final throws = <SyncThrow>[];
      var time = 1770000000000;
      var leg = 1;
      var remaining = 501;

      while (throws.length < count) {
        final bust = random.nextInt(12) == 0;
        var score = scores[random.nextInt(scores.length)];
        if (score > remaining) score = bust ? score : remaining;

        throws.add(SyncThrow(
          score: score,
          dartsUsed: 3,
          remainingBefore: remaining,
          thrownAt: time,
          bust: bust,
          leg: leg,
          set: 1,
        ));

        time += 35000 + random.nextInt(15000);
        if (!bust) remaining -= score;
        if (remaining <= 1) {
          leg++;
          remaining = 501;
        }
      }
      return throws;
    }

    /// A lifetime snapshot of the shape `local_stats_json` really has: about
    /// two dozen counters plus the twenty most recent throws. It rides along in
    /// every sync, so it eats into what is left for the throws themselves.
    String realisticSnapshot() {
      final buffer = StringBuffer('{');
      for (var i = 0; i < 25; i++) {
        buffer.write('"counter_number_$i":${1000 + i},');
      }
      buffer.write('"recent_throws":[');
      for (var i = 0; i < 20; i++) {
        buffer.write('{"score":${60 + i},"darts_used":3,"bust":0,'
            '"remaining_before":${501 - i * 20},'
            '"thrown_at":${1770000000000 + i * 41000}}');
        if (i < 19) buffer.write(',');
      }
      buffer.write(']}');
      return buffer.toString();
    }

    test('a long evening of play fits into a single QR code', () {
      final encoded = encodeSyncPayload(SyncPacket(
        version: 2,
        senderDevice: 'iPhone',
        playerUuid: '3f2a1c9e-7b4d-4e51-9a08-6c2d5f7b1e33',
        playerName: 'Björn',
        favoriteDoubles: 'D20,D16',
        localStatsJson: realisticSnapshot(),
        stats: const SyncStats(
          totalDarts: 1200, totalVisits: 400, average: 62.37,
          legsWon: 18, highestVisit: 180, busts: 21, count180: 7,
        ),
        throws: realisticThrows(330),
      ));

      expect(transportFor(encoded), SyncTransport.staticQr,
          reason: 'encoded length was ${encoded.length}, '
              'the static limit is $kStaticQrMaxChars');
    });

    /// Guards the cost per throw against a change that quietly makes the format
    /// wordy again. About four of these bytes are the throw's timestamp, which
    /// is close to real randomness and does not compress; the rest is the score,
    /// the flags and the occasional leg change. Base45 costs 1.5 characters per
    /// byte against base64's 1.33, and buys back far more than that in what a
    /// code of the same size can hold.
    test('costs no more than seven characters per throw', () {
      final base = encodeSyncPayload(packetOf([])).length;
      final full = encodeSyncPayload(packetOf(realisticThrows(500))).length;

      final perThrow = (full - base) / 500;
      expect(perThrow, lessThan(7.0), reason: '$perThrow chars per throw');
    });

    test('is less than half the size of the JSON format it replaces', () {
      final throws = realisticThrows(500);
      final binary = encodeSyncPayload(packetOf(throws)).length;
      final json = 'QR1:${base64Url.encode(gzip.encode(
        utf8.encode(jsonEncode(packetOf(throws).toJson())),
      ))}'
          .length;

      expect(binary * 2, lessThan(json),
          reason: 'binary $binary chars vs json $json chars');
    });
  });

  group('animated transfer', () {
    /// Enough throws to need several frames.
    SyncPacket bigPacket() => packetOf(List.generate(
          900,
          (i) => t(
            score: 60 - (i % 7),
            remainingBefore: 501 - (i % 8) * 60,
            thrownAt: 1770000000000 + i * 41000,
            leg: 1 + i ~/ 16,
          ),
        ));

    test('splits and reassembles a payload', () {
      final payload = encodeSyncPayload(bigPacket());
      final frames  = splitIntoFrames(payload);

      expect(frames.length, greaterThan(1));
      expect(frames.length, frameCountFor(payload));

      final collector = SyncFrameCollector();
      for (final frame in frames) {
        collector.add(frame);
      }

      expect(collector.isComplete, isTrue);
      expect(collector.assemble(), payload);
    });

    test('every frame fits the size a QR code can show', () {
      for (final frame in splitIntoFrames(encodeSyncPayload(bigPacket()))) {
        expect(frame.length, lessThanOrEqualTo(kChunkFrameMaxChars),
            reason: 'a version 15 code at level M holds 600 of these');
        expect(isAlphanumericSafe(frame), isTrue,
            reason: 'a frame outside the alphanumeric set loses a third of '
                'its capacity to the byte mode');
      }
    });

    test('tolerates frames arriving out of order and more than once', () {
      final payload = encodeSyncPayload(bigPacket());
      final frames  = splitIntoFrames(payload);

      final collector = SyncFrameCollector();
      // The camera catches whatever passes it, including the same frame twice.
      for (final frame in frames.reversed) {
        collector.add(frame);
      }
      for (final frame in frames) {
        expect(collector.add(frame), isFalse, reason: 'already collected');
      }

      expect(collector.assemble(), payload);
    });

    test('reports progress while frames are still missing', () {
      final frames    = splitIntoFrames(encodeSyncPayload(bigPacket()));
      final collector = SyncFrameCollector();

      collector.add(frames.first);
      expect(collector.received, 1);
      expect(collector.total, frames.length);
      expect(collector.isComplete, isFalse);
      expect(collector.assemble, throwsFormatException);
    });

    test('starts over when frames come from a different transfer', () {
      final first  = splitIntoFrames(encodeSyncPayload(bigPacket()));
      final second = splitIntoFrames(
          encodeSyncPayload(packetOf([t(remainingBefore: 501, thrownAt: 1)])),
          chunkSize: 20);

      final collector = SyncFrameCollector();
      collector.add(first.first);
      collector.add(first[1]);
      for (final frame in second) {
        collector.add(frame);
      }

      expect(collector.isComplete, isTrue);
      expect(collector.total, second.length);
      expect(decodeSyncPayload(collector.assemble()).throws.single.thrownAt, 1);
    });

    test('rejects a payload stitched together from mismatched frames', () {
      final frames = splitIntoFrames(
          encodeSyncPayload(bigPacket()), chunkSize: 200);

      final collector = SyncFrameCollector();
      for (var i = 0; i < frames.length; i++) {
        // Same transfer id, but one frame carries the wrong chunk.
        collector.add(i == 1 ? frames[i].replaceRange(
            frames[i].length - 4, null, 'XXXX') : frames[i]);
      }

      expect(collector.isComplete, isTrue);
      expect(collector.assemble, throwsFormatException);
    });

    test('ignores anything that is not a frame', () {
      final collector = SyncFrameCollector();
      expect(collector.add('https://example.com'), isFalse);
      expect(collector.add('DS2C:oops'), isFalse);
      expect(collector.add('DS2C:5:3:abc:xx'), isFalse,
          reason: 'sequence outside the frame count');
      expect(collector.received, 0);
    });
  });

  group('transport choice', () {
    test('grows from one code to a loop to the server', () {
      expect(transportFor('DS2:${'x' * 100}'), SyncTransport.staticQr);
      expect(transportFor('DS2:${'x' * (kStaticQrMaxChars + 1)}'),
          SyncTransport.animatedQr);
      expect(
          transportFor('DS2:${'x' * (kMaxChunkFrames * kChunkPayloadChars + 1)}'),
          SyncTransport.server);
    });
  });

  group('older senders', () {
    test('a v1 JSON payload still imports', () {
      final packet = packetOf([
        t(score: 180, remainingBefore: 501, thrownAt: 1770000000000),
        t(score: 60, remainingBefore: 321, thrownAt: 1770000041000, bust: true),
      ]);

      final legacy = 'QR1:${base64Url.encode(gzip.encode(
        utf8.encode(jsonEncode(packet.toJson())),
      ))}';

      final decoded = decodeSyncPayload(legacy);
      expect(decoded.playerName, packet.playerName);
      expect(decoded.throws.length, 2);
      expect(decoded.throws.last.bust, isTrue);
      expect(decoded.throws.last.thrownAt, 1770000041000);
    });

    test('an unknown payload is rejected', () {
      expect(() => decodeSyncPayload('hello'), throwsFormatException);
    });
  });
}
