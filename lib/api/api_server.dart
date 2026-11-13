import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../item/item_store.dart';
import 'item_api.dart';

/// Serves [ItemApi] to programs on this computer (see `docs/api.md`).
///
/// It listens on loopback on a port the system picks, with a token made for
/// this run; [_info] tells local programs both. Web pages are kept out: they
/// cannot read that file, every browser request carries an `Origin` or the
/// wrong `Host`, and no CORS header is ever sent.
class ApiServer {
  ApiServer(ItemStore store, this._info) : _api = ItemApi(store);

  static const int _maxBody = 1024 * 1024;

  final ItemApi _api;
  final File _info;

  HttpServer? _server;
  String _token = '';
  Future<void> _queue = Future.value();

  /// Starts or stops the server. Calls run in order, so a quick off and on
  /// cannot overlap. Turning off also clears a file left by a crash.
  Future<void> setEnabled(bool on) => _queue = _queue
      .then((_) => on ? _start() : _stop())
      .catchError((Object e) => debugPrint('OneHit: API: $e'));

  Future<void> _start() async {
    if (_server != null) return;
    final random = Random.secure();
    _token = base64UrlEncode([
      for (var i = 0; i < 32; i++) random.nextInt(256),
    ]);
    final server = _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen(_serve);

    // Through a temp file so a reader never sees half of it.
    await _info.parent.create(recursive: true);
    final tmp = File('${_info.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'port': server.port, 'token': _token}),
      flush: true,
    );
    await tmp.rename(_info.path);
  }

  Future<void> _stop() async {
    await _server?.close(force: true);
    _server = null;
    if (await _info.exists()) await _info.delete();
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    int status;
    Object? body;
    try {
      _guard(request);
      (status, body) = _api.handle(
        request.method,
        request.uri.pathSegments,
        await _readBody(request),
      );
    } on ApiError catch (e) {
      status = e.status;
      body = {
        'error': {'code': e.code, 'message': e.message},
      };
      if (status == HttpStatus.unauthorized) {
        response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
      }
    } on Object catch (e) {
      debugPrint('OneHit: API: $e');
      status = HttpStatus.internalServerError;
      body = {
        'error': {'code': 'internal', 'message': 'Something went wrong.'},
      };
    }
    try {
      response.statusCode = status;
      if (body != null) {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(body));
      }
      await response.close();
    } on Object catch (e) {
      // The caller went away; nothing is waiting for this answer.
      debugPrint('OneHit: API: $e');
    }
  }

  void _guard(HttpRequest request) {
    final headers = request.headers;
    final port = _server!.port;
    final host = headers.value(HttpHeaders.hostHeader);
    if (headers.value('origin') != null ||
        (host != '127.0.0.1:$port' && host != 'localhost:$port')) {
      throw const ApiError(
        403,
        'forbidden',
        'Only programs on this computer may call this API, not web pages.',
      );
    }
    final auth = headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!_sameText(auth, 'Bearer $_token')) {
      throw const ApiError(
        401,
        'unauthorized',
        'Send "Authorization: Bearer <token>", with the token from api.json.',
      );
    }
  }

  /// Takes the same time wherever the texts differ.
  bool _sameText(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<Object?> _readBody(HttpRequest request) async {
    // Read to the end even when over the limit: answering early resets the
    // connection, and the caller would never see the error.
    final bytes = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in request) {
      size += chunk.length;
      if (size <= _maxBody) bytes.add(chunk);
    }
    if (size > _maxBody) {
      throw const ApiError(
        413,
        'payload_too_large',
        'The body is over the 1 MiB limit.',
      );
    }
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes.takeBytes()));
    } on FormatException {
      throw const ApiError.badRequest('The body is not valid UTF-8 JSON.');
    }
  }
}
