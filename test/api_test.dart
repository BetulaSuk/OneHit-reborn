import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/api/api_server.dart';
import 'package:onehit/config.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/item_store.dart';

void main() {
  late Directory dir;
  late File info;
  late ItemStore store;
  late ApiServer server;
  late int port;
  late String token;
  var saves = 0;

  Future<(int, Object?)> call(
    String method,
    String path, {
    Object? body,
    String? rawBody,
    Map<String, String>? headers,
    String? bearer,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.open(method, '127.0.0.1', port, path);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${bearer ?? token}',
      );
      headers?.forEach(request.headers.set);
      if (body != null) request.add(utf8.encode(jsonEncode(body)));
      if (rawBody != null) request.add(utf8.encode(rawBody));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, Object?>> create(Map<String, Object?> body) async {
    final (status, json) = await call('POST', '/v1/items', body: body);
    expect(status, 201, reason: '$json');
    return json! as Map<String, Object?>;
  }

  Future<void> expectError(
    Future<(int, Object?)> reply,
    int status,
    String code,
  ) async {
    final (actual, json) = await reply;
    expect(actual, status, reason: '$json');
    expect(((json! as Map)['error'] as Map)['code'], code);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('onehit_api');
    info = File('${dir.path}/api.json');
    saves = 0;
    store = ItemStore([
      InfoItem(id: 'first', text: 'first'),
      InfoItem(id: 'second', text: 'x'),
    ], onSave: (_) => saves++);
    server = ApiServer(store, info);
    await server.setEnabled(true);
    final json = jsonDecode(await info.readAsString()) as Map;
    port = json['port'] as int;
    token = json['token'] as String;
  });

  tearDown(() async {
    await server.setEnabled(false);
    store.dispose();
    await dir.delete(recursive: true);
  });

  group('who may call', () {
    test('a missing or wrong token is refused', () async {
      await expectError(
        call('GET', '/v1/items', bearer: 'wrong'),
        401,
        'unauthorized',
      );
    });

    test('web pages are refused even with the token', () async {
      await expectError(
        call('GET', '/v1/items', headers: {'Origin': 'https://evil.example'}),
        403,
        'forbidden',
      );
      // DNS rebinding: the browser sends the attacker's name as the host.
      await expectError(
        call('GET', '/v1/items', headers: {'Host': 'evil.example:$port'}),
        403,
        'forbidden',
      );
    });

    test('refused writes change nothing', () async {
      await call(
        'DELETE',
        '/v1/items/first',
        headers: {'Origin': 'https://evil.example'},
      );
      expect(store.byId('first'), isNotNull);
    });

    test('the network cards of this machine cannot reach it', () async {
      // A VPN adapter may accept any connection itself, so what counts is
      // whether the API answers, not whether the connection opens.
      Future<String> replyVia(InternetAddress address) async {
        try {
          final socket = await Socket.connect(
            address,
            port,
            timeout: const Duration(seconds: 1),
          );
          socket.write('GET /v1/items HTTP/1.0\r\nHost: x\r\n\r\n');
          final reply = await utf8.decoder
              .bind(socket)
              .join()
              .timeout(const Duration(seconds: 1), onTimeout: () => '');
          socket.destroy();
          return reply;
        } on SocketException {
          return '';
        }
      }

      // The check itself works: over loopback the API refuses that Host.
      expect(
        await replyVia(InternetAddress.loopbackIPv4),
        contains('forbidden'),
      );
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          expect(
            await replyVia(address),
            isNot(contains('forbidden')),
            reason: '${address.address} reached the API',
          );
        }
      }
    });
  });

  group('lifecycle', () {
    test('stopping closes the port and removes the file', () async {
      await server.setEnabled(false);
      expect(await info.exists(), isFalse);
      await expectLater(
        call('GET', '/v1/items'),
        throwsA(isA<SocketException>()),
      );
    });

    test('quick toggles settle on the last one, with a new token', () async {
      final old = token;
      server.setEnabled(false);
      server.setEnabled(true);
      server.setEnabled(false);
      await server.setEnabled(true);
      final json = jsonDecode(await info.readAsString()) as Map;
      expect(json['token'], isNot(old));
      port = json['port'] as int;
      token = json['token'] as String;
      final (status, _) = await call('GET', '/v1/items');
      expect(status, 200);
    });

    test('turning off clears a file left by a crash', () async {
      final other = File('${dir.path}/stale.json')..writeAsStringSync('{}');
      final idle = ApiServer(store, other);
      await idle.setEnabled(false);
      expect(await other.exists(), isFalse);
    });
  });

  group('routes', () {
    test('lists in display order with the local time', () async {
      store.setSunk(store.byId('first')!, true);
      final (status, json) = await call('GET', '/v1/items');
      expect(status, 200);
      final body = json! as Map;
      expect(
        DateTime.parse(body['now'] as String).difference(DateTime.now()).abs(),
        lessThan(const Duration(minutes: 1)),
      );
      final items = body['items'] as List;
      expect(items.map((i) => (i as Map)['id']), ['second', 'first']);
      expect((items.first as Map)['pinned'], isTrue);
    });

    test('a new item waits behind the others unless pinned', () async {
      final quiet = await create({'text': '  quiet  '});
      expect(quiet['text'], 'quiet');
      expect(quiet['pinned'], isFalse);
      expect(store.pinned!.id, 'first');
      expect(store.all.last.id, quiet['id']);

      final loud = await create({'text': 'loud', 'pin': true});
      expect(loud['pinned'], isTrue);
      expect(store.pinned!.id, loud['id']);
    });

    test('a pinned timer keeps running when an item is added', () async {
      store.setTime(
        store.byId('first')!,
        const Duration(hours: 1),
        TimeKind.timer,
      );
      await create({'text': 'new'});
      expect(store.byId('first')!.time!.isRunning, isTrue);
    });

    test('a burst of creates gets different ids', () async {
      final made = await Future.wait([
        for (var i = 0; i < 20; i++) create({'text': 'n$i'}),
      ]);
      expect(made.map((m) => m['id']).toSet(), hasLength(20));
    });

    test('text outside ASCII survives the trip', () async {
      final made = await create({'text': '给妈妈打电话 📞'});
      expect(made['text'], '给妈妈打电话 📞');
      final (_, got) = await call('GET', '/v1/items/${made['id']}');
      expect((got! as Map)['text'], '给妈妈打电话 📞');
    });

    test('update changes only what it names, and saves', () async {
      final (status, json) = await call(
        'PATCH',
        '/v1/items/second',
        body: {'text': 'new text', 'detail': true},
      );
      expect(status, 200);
      final item = store.byId('second')!;
      expect(item.text, 'new text');
      expect(item.detail, isTrue);
      expect(item.icon, 'notes');
      expect((json! as Map)['detail'], isTrue);
      expect(saves, greaterThan(0));
    });

    test('a glyph replaces a picture, as in the editor', () async {
      final item = store.byId('second')!;
      store.setImage(item, Uint8List.fromList([1, 2, 3]));
      final (_, before) = await call('GET', '/v1/items/second');
      expect((before! as Map)['hasImage'], isTrue);
      await call('PATCH', '/v1/items/second', body: {'icon': 'star'});
      expect(item.image, isNull);
    });

    test('pin moves it to the top and floats it', () async {
      store.setSunk(store.byId('second')!, true);
      final (status, json) = await call('POST', '/v1/items/second/pin');
      expect(status, 200);
      expect((json! as Map)['pinned'], isTrue);
      expect((json as Map)['sunk'], isFalse);
      expect(store.pinned!.id, 'second');
    });

    test('delete removes it, then it is gone', () async {
      final (status, json) = await call('DELETE', '/v1/items/second');
      expect(status, 204);
      expect(json, isNull);
      expect(store.byId('second'), isNull);
      await expectError(call('DELETE', '/v1/items/second'), 404, 'not_found');
    });

    test('unknown routes and methods say so', () async {
      await expectError(call('GET', '/v2/items'), 404, 'not_found');
      await expectError(call('GET', '/v1/items/none'), 404, 'not_found');
      await expectError(call('PUT', '/v1/items'), 405, 'method_not_allowed');
      await expectError(
        call('GET', '/v1/items/first/pin'),
        405,
        'method_not_allowed',
      );
    });
  });

  group('countdowns', () {
    test('a new one is a running reminder by default', () async {
      final made = await create({
        'text': 't',
        'time': {'seconds': 90},
      });
      final time = made['time']! as Map;
      expect(time['kind'], 'reminder');
      expect(time['state'], 'running');
      expect(time['remainingSeconds'], inInclusiveRange(89, 90));
    });

    test('a timer away from the strip follows the auto rule', () async {
      final made = await create({
        'text': 't',
        'time': {'seconds': 90, 'kind': 'timer'},
      });
      expect((made['time']! as Map)['state'], 'paused');
    });

    test('state is a target, so repeating it does not flip it', () async {
      await call(
        'PATCH',
        '/v1/items/first',
        body: {
          'time': {'seconds': 60},
        },
      );
      for (var i = 0; i < 2; i++) {
        final (_, json) = await call(
          'PATCH',
          '/v1/items/first',
          body: {
            'time': {'state': 'paused'},
          },
        );
        expect(((json! as Map)['time'] as Map)['state'], 'paused');
      }
      final tag = store.byId('first')!.time!;
      expect(tag.manual, isTrue);
    });

    test('kind alone keeps the time left', () async {
      store.setTime(
        store.byId('first')!,
        const Duration(minutes: 10),
        TimeKind.reminder,
      );
      final (_, json) = await call(
        'PATCH',
        '/v1/items/first',
        body: {
          'time': {'kind': 'timer'},
        },
      );
      final time = (json! as Map)['time'] as Map;
      expect(time['kind'], 'timer');
      expect(time['remainingSeconds'], inInclusiveRange(598, 600));
    });

    test('null removes it', () async {
      store.setTime(
        store.byId('first')!,
        const Duration(minutes: 1),
        TimeKind.reminder,
      );
      final (_, json) = await call(
        'PATCH',
        '/v1/items/first',
        body: {'time': null},
      );
      expect((json! as Map)['time'], isNull);
      expect(store.byId('first')!.time, isNull);
    });

    test('a sunk countdown cannot be started', () async {
      final item = store.byId('second')!;
      store.setTime(item, const Duration(minutes: 1), TimeKind.reminder);
      store.setSunk(item, true);
      await expectError(
        call(
          'PATCH',
          '/v1/items/second',
          body: {
            'time': {'state': 'running'},
          },
        ),
        409,
        'conflict',
      );
    });

    test('floating and starting in one call works', () async {
      final item = store.byId('second')!;
      store.setTime(item, const Duration(minutes: 1), TimeKind.reminder);
      store.setSunk(item, true);
      final (status, json) = await call(
        'PATCH',
        '/v1/items/second',
        body: {
          'sunk': false,
          'time': {'state': 'running'},
        },
      );
      expect(status, 200, reason: '$json');
      expect(item.time!.isRunning, isTrue);
    });

    test('an ended one restarts only with new seconds', () async {
      final item = store.byId('first')!;
      item.time = TimeTag(
        kind: TimeKind.reminder,
        remaining: Duration.zero,
        running: false,
      );
      await expectError(
        call(
          'PATCH',
          '/v1/items/first',
          body: {
            'time': {'state': 'running'},
          },
        ),
        409,
        'conflict',
      );
      final (status, json) = await call(
        'PATCH',
        '/v1/items/first',
        body: {
          'time': {'seconds': 30, 'state': 'running'},
        },
      );
      expect(status, 200, reason: '$json');
      expect(((json! as Map)['time'] as Map)['state'], 'running');
    });
  });

  group('bad input is refused and changes nothing', () {
    final bad = <String, Map<String, Object?>>{
      'blank text': {'text': '   '},
      'text of the wrong type': {'text': 3},
      'a misspelt field': {'txet': 'a'},
      'pin on update': {'pin': true},
      'an unknown icon': {'icon': 'nope'},
      'sunk of the wrong type': {'sunk': 'yes'},
      'time of the wrong type': {'time': 60},
      'a misspelt time field': {
        'time': {'second': 60},
      },
      'zero seconds': {
        'time': {'seconds': 0},
      },
      'over 12 hours': {
        'time': {'seconds': 43201},
      },
      'fractional seconds': {
        'time': {'seconds': 1.5},
      },
      'an unknown kind': {
        'time': {'seconds': 60, 'kind': 'alarm'},
      },
      'the ended state': {
        'time': {'seconds': 60, 'state': 'ended'},
      },
      'a countdown without seconds': {
        'time': {'kind': 'timer'},
      },
    };
    for (final MapEntry(key: name, value: body) in bad.entries) {
      test(name, () async {
        // A valid field beside the bad one must not be applied either.
        await expectError(
          call('PATCH', '/v1/items/second', body: {'detail': true, ...body}),
          400,
          'bad_request',
        );
        final item = store.byId('second')!;
        expect(item.detail, isFalse);
        expect(item.text, 'x');
        expect(item.time, isNull);
      });
    }

    test('creating needs text', () async {
      await expectError(
        call('POST', '/v1/items', body: {'icon': 'star'}),
        400,
        'bad_request',
      );
      expect(store.all, hasLength(2));
    });

    test('pinned and sunk at once', () async {
      await expectError(
        call(
          'POST',
          '/v1/items',
          body: {'text': 'a', 'pin': true, 'sunk': true},
        ),
        400,
        'bad_request',
      );
      expect(store.all, hasLength(2));
    });

    test('a body that is not a JSON object', () async {
      await expectError(
        call('POST', '/v1/items', rawBody: '{not json'),
        400,
        'bad_request',
      );
      await expectError(
        call('POST', '/v1/items', rawBody: '[1]'),
        400,
        'bad_request',
      );
      await expectError(call('POST', '/v1/items'), 400, 'bad_request');
    });

    test('a body over the limit', () async {
      await expectError(
        call('POST', '/v1/items', body: {'text': 'a' * (1024 * 1024)}),
        413,
        'payload_too_large',
      );
      expect(store.all, hasLength(2));
    });
  });

  test('config keeps the switch and defaults it off', () {
    expect(const OneHitConfig().apiEnabled, isFalse);
    expect(OneHitConfig.fromJson({'apiEnabled': 'yes'}).apiEnabled, isFalse);
    final on = OneHitConfig.fromJson({'apiEnabled': true});
    expect(on.apiEnabled, isTrue);
    expect(on.toJson()['apiEnabled'], isTrue);
  });
}
