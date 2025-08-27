// lib/services/image_service_cache.dart
// If your file is named image_cache_service.dart, keep the path consistent with imports.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  ImageCacheService._();
  static final instance = ImageCacheService._();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Returns an ImageProvider that:
  /// - uses a local file if present,
  /// - otherwise downloads from Firebase Storage, caches it, then decodes.
  ImageProvider imageProvider(String fileName) {
    return FileImageWithFallback(fileName, _downloadAndCache);
  }

  /// NEW: prefetch and await decode via Flutter's image cache.
  Future<void> prefetch(String fileName, BuildContext context) async {
    final provider = imageProvider(fileName);
    await precacheImage(provider, context);
  }

  /// Downloads the image from Firebase Storage and caches it.
  Future<File> _downloadAndCache(String fileName) async {
    final url = await _storage.ref('model/$fileName').getDownloadURL();
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for $fileName');
    }
    final bytes = response.bodyBytes;
    final file = await _cacheFileFor(fileName);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Returns the local File path intended for cache.
  Future<File> _cacheFileFor(String fileName) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/model_cache/$fileName');
  }

  /// Checks if an image file already exists in local cache.
  Future<bool> isImageCached(String fileName) async {
    final file = await _localFile(fileName);
    return file.exists();
  }

  /// Local cached file accessor.
  Future<File> _localFile(String fileName) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/model_cache/$fileName');
  }
}

class FileImageWithFallback extends ImageProvider<FileImageWithFallback> {
  final String fileName;
  final Future<File> Function(String fileName) downloadAndCache;

  FileImageWithFallback(this.fileName, this.downloadAndCache);

  @override
  Future<FileImageWithFallback> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FileImageWithFallback>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    FileImageWithFallback key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
      },
    );
  }

  Future<ui.Codec> _loadCodec() async {
    File file = await ImageCacheService.instance._localFile(fileName);
    if (!await file.exists()) {
      file = await downloadAndCache(fileName);
    }
    final bytes = await file.readAsBytes();
    return ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileImageWithFallback && other.fileName == fileName;

  @override
  int get hashCode => fileName.hashCode;
}
