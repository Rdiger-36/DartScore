import 'dart:convert';

import 'package:dartscore_app/screens/sync_screen.dart';
import 'package:dartscore_app/services/sync_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The size limits the transport choice works from are only real if the codes
/// actually render at the version they were sized for. These tests build the
/// codes the sender would show, because the failure otherwise appears on a
/// phone screen as a blank box and nowhere else.
void main() {
  /// A payload of exactly [chars] characters from the base45 alphabet.
  String payloadOf(int chars) => 'DS2:${'W' * (chars - 4)}';

  group('rendering sync codes', () {
    test('a full frame stays inside version 15', () {
      final frame = 'DS2C:119:120:ZZZZZZZ:${'W' * kChunkPayloadChars}';
      expect(frame.length, lessThanOrEqualTo(kChunkFrameMaxChars));

      final qr = buildQrCode(frame);
      expect(qr.typeNumber, lessThanOrEqualTo(15),
          reason: 'a denser code than this stalls while it is moving');
      expect(qr.errorCorrectLevel, QrErrorCorrectLevel.M);
    });

    test('frames of equal length all resolve to the same version', () {
      // What lets the version be resolved once per transfer instead of once
      // per shown frame, which at ten frames a second is the difference
      // between one QR code built and fifteen thrown away.
      final versions = {
        for (var seq = 0; seq < 3; seq++)
          buildQrCode('DS2C:$seq:120:ZZZZZZZ:${'W' * kChunkPayloadChars}')
              .typeNumber,
      };

      expect(versions, hasLength(1));
    });

    test('the largest static payload still renders', () {
      final qr = buildQrCode(payloadOf(kStaticQrMaxChars));
      expect(qr.typeNumber, lessThanOrEqualTo(40));
    });

    test('a payload uses fewer modules than the same data in byte mode', () {
      final data = payloadOf(2000);

      final alphanumeric = buildQrCode(data);
      final byteMode = () {
        for (var version = 1; version <= 40; version++) {
          final qr = QrCode(version, QrErrorCorrectLevel.M)..addData(data);
          try {
            QrImage(qr);
            return qr;
          } on InputTooLongException {
            continue;
          }
        }
        fail('byte mode should still fit');
      }();

      expect(alphanumeric.typeNumber, lessThan(byteMode.typeNumber),
          reason: 'the dense mode is the whole point of base45');
    });

    test('the Wi-Fi connection code falls back to the byte mode', () {
      // Lower case and braces put this outside the alphanumeric set.
      final data = jsonEncode({'ip': '192.168.1.42', 'port': 54321});
      expect(isAlphanumericSafe(data), isFalse);
      expect(() => buildQrCode(data), returnsNormally);
    });

    test('a real packet at the static limit renders', () {
      // Grows a payload up to the limit the transport choice allows, then
      // renders it, which is the case that used to fail silently.
      final data = payloadOf(kStaticQrMaxChars);
      expect(transportFor(data), SyncTransport.staticQr);
      expect(() => buildQrCode(data), returnsNormally);
    });
  });
}
