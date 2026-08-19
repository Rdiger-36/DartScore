import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

  /// Posts [bytes] zeros to the token path, in slices so the test never holds
  /// the whole body.
  ///
  /// Any failure is swallowed. A server that stops reading mid-body breaks the
  /// connection under the peer's own writes, so the caller asserts on what the
  /// server kept rather than on what came back.
  Future<void> postBytes(String token, int bytes) async {
    final client = HttpClient();
    try {
      final req = await client
          .postUrl(Uri.parse('http://127.0.0.1:${connection.port}/$token'));
      const slice = 256 * 1024;
      for (var written = 0; written < bytes; written += slice) {
        req.add(Uint8List(min(slice, bytes - written)));
        await req.flush();
      }
      await req.close();
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

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

  group('size limits', () {
    /// A peer that is not this app: answers 200 on anything, announces
    /// [announced] as the length and then writes [sends] bytes.
    ///
    /// The two are separate on purpose, and that is why the response is
    /// written onto a raw socket rather than through `HttpServer`: a peer is
    /// free to name one length and send another, which is exactly what
    /// `HttpServer` refuses to let a test do.
    Future<(ServerSocket, SyncConnection)> liar(
        {required int announced, required int sends}) async {
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      listener.listen((socket) async {
        socket.listen((_) {}, onError: (_) {}, cancelOnError: false);
        socket.write('HTTP/1.1 200 OK\r\n');
        if (announced > 0) socket.write('Content-Length: $announced\r\n');
        // Without a length the body runs to the close, which is how a peer
        // asks the receiver to keep reading for as long as it keeps sending.
        socket.write('Connection: close\r\n\r\n');

        const slice = 64 * 1024;
        for (var written = 0; written < sends; written += slice) {
          socket.add(Uint8List(min(slice, sends - written)));
          await socket.flush();
        }
        await socket.close();
      });
      return (listener, SyncConnection('127.0.0.1', listener.port, 'TOKEN'));
    }

    test('an announced length above the ceiling is refused before it arrives',
        () async {
      final (peer, conn) = await liar(announced: 4096, sends: 0);
      addTearDown(peer.close);

      await expectLater(
        SyncClient().fetchBytes(conn, maxBytes: 1024),
        throwsA(isA<SyncPayloadTooLargeException>()),
      );
    });

    test('a body that grows past the ceiling is refused as it arrives',
        () async {
      // No announced length at all, which is what a peer sends when it wants
      // the receiver to keep reading. Only weighing the chunks catches it.
      final (peer, conn) = await liar(announced: 0, sends: 512 * 1024);
      addTearDown(peer.close);

      await expectLater(
        SyncClient().fetchBytes(conn, maxBytes: 1024),
        throwsA(isA<SyncPayloadTooLargeException>()),
      );
    });

    test('a body inside the ceiling still arrives whole', () async {
      final (peer, conn) = await liar(announced: 1024, sends: 1024);
      addTearDown(peer.close);

      expect(await SyncClient().fetchBytes(conn, maxBytes: 1024),
          hasLength(1024));
    });

    test('an oversized answer on the return leg is refused', () async {
      final client = SyncClient();
      final fetch = client.fetch(loopback(connection.token));
      await _until(() => server.state.value == SyncServerState.pending);
      server.approve();
      await fetch;

      await postBytes(connection.token, kMaxSyncTransferBytes + 1024 * 1024);

      // What the peer sees is deliberately not pinned. The server stops
      // reading mid-body, so whether the 413 gets back or the socket breaks
      // under the peer's own writes is up to the timing. What has to hold is
      // that nothing was kept: this device's own side is already out, and only
      // the direction back is lost, which is the same outcome as a peer that
      // never answered and which the return timer already covers.
      expect(server.state.value, SyncServerState.served);
      expect(server.returnedPayload, isNull);
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
