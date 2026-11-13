import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/api/api_server.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/item_store.dart';

import '../mcp/bin/onehit_mcp.dart' as mcp;

void main() {
  late Directory dir;
  late File info;
  late ItemStore store;
  late ApiServer server;

  /// Sends [messages] to the bridge and returns every line it writes.
  Future<List<Map<String, Object?>>> talk(List<Object> messages) async {
    final input = Stream.fromIterable([
      for (final m in messages)
        utf8.encode('${m is String ? m : jsonEncode(m)}\n'),
    ]);
    final out = <Map<String, Object?>>[];
    await mcp.serve(
      input,
      (line) => out.add(jsonDecode(line) as Map<String, Object?>),
      info,
    );
    return out;
  }

  Future<Map<String, Object?>> ask(String method, [Object? params]) async {
    final out = await talk([
      {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': ?params},
    ]);
    return out.single;
  }

  Future<Map<String, Object?>> callTool(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    final reply = await ask('tools/call', {'name': name, 'arguments': args});
    return reply['result']! as Map<String, Object?>;
  }

  String textOf(Map<String, Object?> result) =>
      ((result['content']! as List).single as Map)['text'] as String;

  const modernMeta = {
    '_meta': {
      'io.modelcontextprotocol/protocolVersion': '2026-07-28',
      'io.modelcontextprotocol/clientCapabilities': <String, Object?>{},
    },
  };

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('onehit_mcp');
    info = File('${dir.path}/api.json');
    store = ItemStore([InfoItem(id: 'first', text: 'first')]);
    server = ApiServer(store, info);
    await server.setEnabled(true);
  });

  tearDown(() async {
    await server.setEnabled(false);
    store.dispose();
    await dir.delete(recursive: true);
  });

  group('protocol', () {
    test('initialize echoes a version it knows', () async {
      final reply = await ask('initialize', {
        'protocolVersion': '2025-06-18',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': 't', 'version': '1'},
      });
      final result = reply['result']! as Map;
      expect(result['protocolVersion'], '2025-06-18');
      expect(result['capabilities'], {'tools': <String, Object?>{}});
      expect((result['serverInfo'] as Map)['name'], 'onehit');
      expect(result, isNot(contains('resultType')));
    });

    test('initialize offers its newest for a version it does not', () async {
      final reply = await ask('initialize', {'protocolVersion': '1999-01-01'});
      expect((reply['result']! as Map)['protocolVersion'], '2025-11-25');
    });

    test('server/discover answers the stateless revision', () async {
      final reply = await ask('server/discover', modernMeta);
      final result = reply['result']! as Map;
      expect(result['resultType'], 'complete');
      expect(result['supportedVersions'], ['2026-07-28']);
      expect(result['capabilities'], {'tools': <String, Object?>{}});
      expect(result['ttlMs'], isA<int>());
      expect(result['cacheScope'], 'public');
      expect(
        ((result['_meta'] as Map)['io.modelcontextprotocol/serverInfo']
            as Map)['name'],
        'onehit',
      );
    });

    test('an unsupported version names the ones that work', () async {
      final reply = await ask('tools/list', {
        '_meta': {'io.modelcontextprotocol/protocolVersion': '1900-01-01'},
      });
      final error = reply['error']! as Map;
      expect(error['code'], -32022);
      expect(error['data'], {
        'supported': ['2026-07-28'],
        'requested': '1900-01-01',
      });
    });

    test('tools/list has each era\'s shape, in a fixed order', () async {
      const names = [
        'list_items',
        'create_item',
        'update_item',
        'pin_item',
        'delete_item',
      ];
      final legacy = (await ask('tools/list'))['result']! as Map;
      expect((legacy['tools'] as List).map((t) => (t as Map)['name']), names);
      expect(legacy, isNot(contains('resultType')));

      final modern = (await ask('tools/list', modernMeta))['result']! as Map;
      expect((modern['tools'] as List).map((t) => (t as Map)['name']), names);
      expect(modern['resultType'], 'complete');
      expect(modern['ttlMs'], isA<int>());
      expect(modern['cacheScope'], 'public');
    });

    test('ping is only for the older revisions', () async {
      expect((await ask('ping'))['result'], isEmpty);
      expect(
        ((await ask('ping', modernMeta))['error']! as Map)['code'],
        -32601,
      );
    });

    test('notifications get no answer; junk gets the right error', () async {
      final out = await talk([
        {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
        '{not json',
        '[1]',
        {'jsonrpc': '2.0', 'id': 7, 'method': 'no/such'},
        {
          'jsonrpc': '2.0',
          'id': 8,
          'method': 'tools/call',
          'params': {'name': 'no_such_tool'},
        },
      ]);
      expect(out.map((m) => (m['error']! as Map)['code']), [
        -32700,
        -32600,
        -32601,
        -32602,
      ]);
      expect(out.map((m) => m['id']), [null, null, 7, 8]);
    });
  });

  group('tools', () {
    test('every tool reaches the app', () async {
      final made = jsonDecode(
        textOf(
          await callTool('create_item', {
            'text': '给妈妈打电话',
            'time': {'seconds': 600},
          }),
        ),
      ) as Map;
      final id = made['id'] as String;
      expect(store.byId(id)!.text, '给妈妈打电话');
      expect(store.pinned!.id, 'first');

      final listed = jsonDecode(textOf(await callTool('list_items'))) as Map;
      expect(listed['items'], hasLength(2));
      expect(listed['now'], isA<String>());

      await callTool('update_item', {
        'id': id,
        'text': 'changed',
        'time': null,
      });
      expect(store.byId(id)!.text, 'changed');
      expect(store.byId(id)!.time, isNull);

      await callTool('pin_item', {'id': id});
      expect(store.pinned!.id, id);

      final deleted = await callTool('delete_item', {'id': id});
      expect(deleted['isError'], isFalse);
      expect(textOf(deleted), 'Deleted item "$id".');
      expect(store.byId(id), isNull);
    });

    test('an API refusal is a tool error the model can read', () async {
      final result = await callTool('create_item', {'text': '  '});
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('blank'));
    });

    test('a missing id is a tool error', () async {
      final result = await callTool('delete_item');
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('id'));
    });

    test('an id cannot walk to another route', () async {
      final result = await callTool('delete_item', {'id': '../items/first'});
      expect(result['isError'], isTrue);
      expect(store.byId('first'), isNotNull);
    });

    test('tools carry the current revision\'s fields when asked', () async {
      final reply = await ask('tools/call', {
        ...modernMeta,
        'name': 'list_items',
      });
      final result = reply['result']! as Map;
      expect(result['resultType'], 'complete');
      expect(result['isError'], isFalse);
    });

    test('with the API off, the error says what to do', () async {
      await server.setEnabled(false);
      final result = await callTool('list_items');
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('Settings > Automation'));
    });

    test('a file left by a crash reads as not running', () async {
      final json = await info.readAsString();
      await server.setEnabled(false);
      await info.writeAsString(json);
      final result = await callTool('list_items');
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('Settings > Automation'));
    });

    test('a damaged file reads as not running', () async {
      await info.writeAsString('{"port":');
      final result = await callTool('list_items');
      expect(result['isError'], isTrue);
      expect(textOf(result), contains('Settings > Automation'));
    });
  });

  // The Windows console code page would turn this text to question marks if
  // main ever wrote strings to stdout, which an in-process test cannot see.
  test('the real process speaks UTF-8 over its pipes', () async {
    store.setText(store.byId('first')!, '给妈妈打电话 📞');
    final process = await Process.start(
      'dart',
      ['run', 'bin/onehit_mcp.dart'],
      workingDirectory: 'mcp',
      environment: {'ONEHIT_API_FILE': info.path},
      runInShell: Platform.isWindows,
    );
    unawaited(process.stderr.drain<void>());
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    process.stdin.add(
      utf8.encode(
        '${jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': 'list_items'},
        })}\n',
      ),
    );
    final reply = jsonDecode(await lines.first) as Map;
    await process.stdin.close();
    expect(await process.exitCode, 0);
    final text = textOf(reply['result'] as Map<String, Object?>);
    expect(text, contains('给妈妈打电话 📞'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
