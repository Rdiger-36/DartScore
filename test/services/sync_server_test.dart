import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartscore_app/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Wi-Fi transfer opens a socket on the local network and hands over a
/// player's whole history, so who gets an answer out of it is the one thing
/// here worth pinning down. These tests drive the real server over real HTTP.
void main() {
  late SyncServer server;
  late SyncConnection connection;

  const payload = 'DS2:PAYLOAD';

  /// Reaches the server on loopback, whatever address it reported.
  SyncConnection loopback(String token) =>
      SyncConnection('127.0.0.1', connection.port, token);

  /// One raw request, returning the status and the body.
  Future<(int, String)> get(String path) async {
    final client = HttpClient();
    try {
      final res = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:${connection.port}$path')))
          .close();
      return (res.statusCode, await res.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }

  setUp(() async {
    server = SyncServer();
    connection = await server.start(utf8.encode(payload));
  });

  tearDown(() async {
    await server.stop();
    server.dispose();
  });

  group('who gets in', () {
    test('a request without the token is refused', () async {
      final (status, body) = await get('/');

      expect(status, HttpStatus.forbidden);
      expect(body, isEmpty);
      expect(server.state.value, SyncServerState.waiting,
          reason: 'a stranger must not even raise a prompt on the sender');
    });

    test('a request with the wrong token is refused', () async {
      final (status, _) = await get('/${connection.token}X');

      expect(status, HttpStatus.forbidden);
      expect(server.state.value, SyncServerState.waiting);
    });

    test('the token alone does not hand over the payload', () async {
      final (status, body) = await get('/${connection.token}');

      expect(status, HttpStatus.accepted);
      expect(body, contains(server.pin));
      expect(body, isNot(contains(payload)));
      expect(server.state.value, SyncServerState.pending);
    });

    test('every session gets its own token and number', () async {
      final other = SyncServer();
      final second = await other.start(utf8.encode(payload));

      expect(second.token, isNot(connection.token));
      expect(second.token.length, 16);
      expect(server.pin, hasLength(4));

      await other.stop();
      other.dispose();
    });
  });

  group('pairing', () {
    test('the payload follows once the sender approves', () async {
      final fetch = SyncClient().fetch(loopback(connection.token));

      // The sender sees the request and lets it through.
      await _until(() => server.state.value == SyncServerState.pending);
      server.approve();

      expect(await fetch, payload);
      expect(server.state.value, SyncServerState.served);
    });

    test('the receiver is told the number to compare', () async {
      String? seen;
      final fetch = SyncClient()
          .fetch(loopback(connection.token), onPin: (pin) => seen = pin);

      await _until(() => server.state.value == SyncServerState.pending);
      server.approve();
      await fetch;

      expect(seen, isNotNull);
      expect(seen, server.pin,
          reason: 'both screens have to show the same digits');
    });

    test('a payload of a realistic size arrives whole', () async {
      // The transfer only reaches this transport when it is too large for a QR
      // code, so a short test string proves nothing: the failure this guards
      // against is the server closing while the body is still going out, and
      // that only shows up once the body no longer fits in one buffer.
      final big = 'DS2:${'W' * 250000}';
      final other = SyncServer();
      final where = await other.start(utf8.encode(big));

      // The screen stops the server the moment it reports the hand-over, so
      // that has to be the moment the last byte is out.
      final stopped = Completer<void>();
      other.state.addListener(() {
        if (other.state.value == SyncServerState.served && !stopped.isCompleted) {
          stopped.complete(other.stop());
        }
      });

      final fetch = SyncClient()
          .fetch(SyncConnection('127.0.0.1', where.port, where.token));
      await _until(() => other.state.value == SyncServerState.pending);
      other.approve();

      expect(await fetch, hasLength(big.length));
      await stopped.future;
      other.dispose();
    });

    test('declining turns the receiver away', () async {
      final fetch = SyncClient().fetch(loopback(connection.token));

      await _until(() => server.state.value == SyncServerState.pending);
      server.reject();

      await expectLater(fetch, throwsA(isA<SyncRejectedException>()));
    });
  });

  group('the return leg', () {
    /// Plays the receiver: takes the payload, then answers with [reply].
    Future<void> exchange(String reply) async {
      final client = SyncClient();
      final fetch = client.fetch(loopback(connection.token));
      await _until(() => server.state.value == SyncServerState.pending);
      server.approve();
      await fetch;
      await client.post(loopback(connection.token), reply);
    }

    test('the peer answers with its own side, and that ends the session',
        () async {
      await exchange('DS2:THEIRS');

      await _until(() => server.state.value == SyncServerState.returned);
      expect(server.returnedPayload, 'DS2:THEIRS');
    });

    test('an empty answer ends the wait with nothing to import', () async {
      // What a receiver sends when it does not know the player at all. It has
      // to answer anyway, or the sender sits on its timeout for no reason.
      await exchange('');

      await _until(() => server.state.value == SyncServerState.returned);
      expect(server.returnedPayload, isNull);
    });

    test('nothing is taken before the payload has gone out', () async {
      final client = SyncClient();

      await expectLater(
        client.post(loopback(connection.token), 'DS2:THEIRS'),
        throwsA(isA<Exception>()),
        reason: 'an unapproved peer holding the token must not push data in',
      );
      expect(server.state.value, SyncServerState.waiting);
      expect(server.returnedPayload, isNull);
    });

    test('an answer without the token is refused', () async {
      final client = SyncClient();
      final fetch = client.fetch(loopback(connection.token));
      await _until(() => server.state.value == SyncServerState.pending);
      server.approve();
      await fetch;

      await expectLater(
        client.post(loopback('${connection.token}X'), 'DS2:THEIRS'),
        throwsA(isA<Exception>()),
      );
      expect(server.state.value, SyncServerState.served);
      expect(server.returnedPayload, isNull);
    });

    test('the payload is not handed out again once the exchange is over',
        () async {
      await exchange('DS2:THEIRS');
      await _until(() => server.state.value == SyncServerState.returned);

      final (status, body) = await get('/${connection.token}');

      expect(status, HttpStatus.gone);
      expect(body, isNot(contains(payload)));
    });
  });

  group('the connection code', () {
    test('round trips through the QR payload', () {
      final parsed = SyncConnection.parse(connection.qrPayload);

      expect(parsed, isNotNull);
      expect(parsed!.ip, connection.ip);
      expect(parsed.port, connection.port);
      expect(parsed.token, connection.token);
    });

    test('is not confused by another kind of code', () {
      expect(SyncConnection.parse('DS2:something'), isNull);
      expect(SyncConnection.parse('DSW:only:two'), isNull);
      expect(SyncConnection.parse('DSW:1.2.3.4:notaport:TOKEN'), isNull);
    });

    test('stays inside the dense QR character set', () {
      // Lower case or braces would push the code into the byte mode, which is
      // a third less dense for no reason.
      expect(RegExp(r'^[0-9A-Z $%*+\-./:]+$').hasMatch(connection.qrPayload),
          isTrue,
          reason: connection.qrPayload);
    });
  });
}

/// Waits until [condition] holds, so a test can react to the server rather
/// than sleep for a fixed time and hope.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the server never reached the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
