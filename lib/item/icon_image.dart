import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Icons are stored as square PNGs this many pixels wide: about twice the
/// disc's size, enough for a sharp disc and the detail view.
const int iconPixels = 128;

const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.bmp',
  '.webp',
  '.tif',
  '.tiff',
  '.ico',
};

bool looksLikeImagePath(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      _imageExtensions.contains(path.substring(dot).toLowerCase());
}

Uri? httpUrl(String text) {
  final uri = Uri.tryParse(text.trim().split(RegExp(r'\s')).first);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return uri;
}

/// Decodes any common format, crops the centre square and shrinks it to
/// [iconPixels]. Runs off the UI thread. Returns null for non-images.
Future<Uint8List?> makeIcon(Uint8List bytes) => compute(_makeIcon, bytes);

Uint8List? _makeIcon(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = side > iconPixels
      ? img.copyResize(
          square,
          width: iconPixels,
          height: iconPixels,
          interpolation: img.Interpolation.average,
        )
      : square;
  return img.encodePng(small, level: 9);
}

Future<Uint8List?> iconFromFile(String path) async {
  try {
    return await makeIcon(await File(path).readAsBytes());
  } on Object catch (e) {
    debugPrint('OneHit: could not read image $path: $e');
    return null;
  }
}

/// Downloads at most 10 MB from [url] and turns it into an icon.
Future<Uint8List?> iconFromUrl(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(url);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      builder.add(chunk);
      if (builder.length > 10 * 1024 * 1024) return null;
    }
    return await makeIcon(builder.takeBytes());
  } on Object catch (e) {
    debugPrint('OneHit: could not fetch image $url: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}
