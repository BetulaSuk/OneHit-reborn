import '../item/info_item.dart';
import '../item/item_store.dart';

/// A request the API refuses; becomes `{"error": {"code", "message"}}`.
class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);

  const ApiError.badRequest(String message) : this(400, 'bad_request', message);

  final int status;
  final String code;
  final String message;
}

/// The routes of `docs/api.md`, free of HTTP so they stay about items. Every
/// write is checked in full before the first change, so a refused request
/// changes nothing.
class ItemApi {
  ItemApi(this._store);

  final ItemStore _store;

  (int, Object?) handle(String method, List<String> path, Object? body) {
    return switch ((method, path)) {
      ('GET', ['v1', 'items']) => (200, _list()),
      ('POST', ['v1', 'items']) => (201, _create(_object(body))),
      ('GET', ['v1', 'items', final id]) => (200, _json(_find(id))),
      ('PATCH', ['v1', 'items', final id]) => (200, _update(id, _object(body))),
      ('DELETE', ['v1', 'items', final id]) => _delete(id),
      ('POST', ['v1', 'items', final id, 'pin']) => (200, _pin(id)),
      (_, ['v1', 'items']) ||
      (_, ['v1', 'items', _]) ||
      (_, ['v1', 'items', _, 'pin']) => throw const ApiError(
        405,
        'method_not_allowed',
        'This route does not take that method.',
      ),
      _ => throw const ApiError(404, 'not_found', 'No such route.'),
    };
  }

  Map<String, Object?> _list() => {
    'now': _localIso(DateTime.now()),
    'items': [for (final i in _store.all) _json(i)],
  };

  Map<String, Object?> _create(Map<String, Object?> body) {
    final changes = _Changes.parse(body, creating: true);
    if (changes.text == null) {
      throw const ApiError.badRequest('text is required.');
    }
    final pin = _bool(body, 'pin') ?? false;
    if (pin && changes.sunk == true) {
      throw const ApiError.badRequest('An item cannot be pinned and sunk.');
    }
    _check(null, changes);
    final item = _store.add(changes.text!);
    _apply(item, changes);
    if (pin) _store.pin(item);
    return _json(item);
  }

  Map<String, Object?> _update(String id, Map<String, Object?> body) {
    final item = _find(id);
    final changes = _Changes.parse(body, creating: false);
    _check(item, changes);
    _apply(item, changes);
    return _json(item);
  }

  (int, Object?) _delete(String id) {
    _store.remove(_find(id));
    return (204, null);
  }

  Map<String, Object?> _pin(String id) {
    final item = _find(id);
    _store.pin(item);
    return _json(item);
  }

  InfoItem _find(String id) =>
      _store.byId(id) ??
      (throw ApiError(404, 'not_found', 'No item with id "$id".'));

  /// Refuses what [_apply] could not carry out on [item] (null when creating).
  void _check(InfoItem? item, _Changes changes) {
    final time = changes.time;
    if (time == null) return;
    final tag = item?.time;
    if (tag == null && time.seconds == null) {
      throw const ApiError.badRequest(
        'time.seconds is required to add a countdown.',
      );
    }
    if (time.state == null) return;
    if (changes.sunk ?? item?.sunk ?? false) {
      throw const ApiError(
        409,
        'conflict',
        "A sunk item's countdown stays paused; float the item first.",
      );
    }
    if (time.seconds == null && tag?.state(DateTime.now()) == TimeState.ended) {
      throw const ApiError(
        409,
        'conflict',
        'The countdown has ended; send time.seconds to restart it.',
      );
    }
  }

  void _apply(InfoItem item, _Changes changes) {
    if (changes.text case final text?) _store.setText(item, text);
    if (changes.icon case final icon?) _store.setIcon(item, icon);
    if (changes.detail case final detail?) _store.setDetail(item, detail);
    if (changes.sunk case final sunk?) _store.setSunk(item, sunk);
    if (changes.clearsTime) _store.clearTime(item);

    final time = changes.time;
    if (time == null) return;
    if (time.seconds != null || time.kind != null) {
      _store.setTime(
        item,
        time.seconds != null
            ? Duration(seconds: time.seconds!)
            : item.time!.remaining(DateTime.now()),
        time.kind ?? item.time?.kind ?? TimeKind.reminder,
      );
    }
    if (time.state != null && item.time!.state(DateTime.now()) != time.state) {
      _store.toggleTime(item);
    }
  }

  Map<String, Object?> _json(InfoItem item) {
    final tag = item.time;
    return {
      'id': item.id,
      'text': item.text,
      'icon': item.icon,
      'hasImage': item.image != null,
      'sunk': item.sunk,
      'detail': item.detail,
      'pinned': identical(item, _store.pinned),
      'time': tag == null ? null : _timeJson(tag, DateTime.now()),
    };
  }

  /// Rounded up, so 0 only ever means ended.
  Map<String, Object?> _timeJson(TimeTag tag, DateTime now) => {
    'kind': tag.kind.name,
    'state': tag.state(now).name,
    'remainingSeconds': (tag.remaining(now).inMilliseconds / 1000).ceil(),
  };
}

/// The fields a create or update asks to change, validated.
class _Changes {
  _Changes._({
    this.text,
    this.icon,
    this.sunk,
    this.detail,
    this.time,
    required this.clearsTime,
  });

  factory _Changes.parse(Map<String, Object?> body, {required bool creating}) {
    _onlyKeys(body, {
      'text',
      'icon',
      'sunk',
      'detail',
      'time',
      if (creating) 'pin',
    }, '');

    final text = _string(body, 'text')?.trim();
    if (text != null && text.isEmpty) {
      throw const ApiError.badRequest('text cannot be blank.');
    }
    final icon = _string(body, 'icon');
    if (icon != null && !itemIcons.containsKey(icon)) {
      throw ApiError.badRequest(
        'icon must be one of: ${itemIcons.keys.join(', ')}.',
      );
    }
    final rawTime = body['time'];
    if (rawTime != null && rawTime is! Map<String, Object?>) {
      throw const ApiError.badRequest('time must be an object or null.');
    }
    return _Changes._(
      text: text,
      icon: icon,
      sunk: _bool(body, 'sunk'),
      detail: _bool(body, 'detail'),
      time: rawTime == null
          ? null
          : _TimeChange.parse(rawTime as Map<String, Object?>),
      clearsTime: rawTime == null && body.containsKey('time'),
    );
  }

  final String? text;
  final String? icon;
  final bool? sunk;
  final bool? detail;
  final _TimeChange? time;
  final bool clearsTime;
}

class _TimeChange {
  _TimeChange._(this.seconds, this.kind, this.state);

  factory _TimeChange.parse(Map<String, Object?> json) {
    _onlyKeys(json, {'seconds', 'kind', 'state'}, 'time.');

    final seconds = json['seconds'];
    final max = TimeTag.max.inSeconds;
    if (seconds != null && (seconds is! int || seconds < 1 || seconds > max)) {
      throw ApiError.badRequest(
        'time.seconds must be a whole number from 1 to $max (12 hours).',
      );
    }
    final kind = json['kind'];
    final parsedKind = TimeKind.values.asNameMap()[kind];
    if (kind != null && parsedKind == null) {
      throw const ApiError.badRequest(
        'time.kind must be "reminder" or "timer".',
      );
    }
    final state = switch (json['state']) {
      null => null,
      'running' => TimeState.running,
      'paused' => TimeState.paused,
      _ => throw const ApiError.badRequest(
        'time.state must be "running" or "paused".',
      ),
    };
    return _TimeChange._(seconds as int?, parsedKind, state);
  }

  final int? seconds;
  final TimeKind? kind;
  final TimeState? state;
}

Map<String, Object?> _object(Object? body) => body is Map<String, Object?>
    ? body
    : throw const ApiError.badRequest('The body must be a JSON object.');

/// A misspelt field would otherwise be dropped while the call reports success.
void _onlyKeys(Map<String, Object?> json, Set<String> known, String prefix) {
  for (final key in json.keys) {
    if (!known.contains(key)) {
      throw ApiError.badRequest('Unknown field "$prefix$key".');
    }
  }
}

String? _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw ApiError.badRequest('$key must be a string.');
}

bool? _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is bool) return value as bool?;
  throw ApiError.badRequest('$key must be true or false.');
}

/// Local time with its offset, so a caller can work out "at 3 pm" itself.
String _localIso(DateTime t) {
  final offset = t.timeZoneOffset;
  String two(int n) => n.toString().padLeft(2, '0');
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${t.toIso8601String().substring(0, 19)}'
      '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
