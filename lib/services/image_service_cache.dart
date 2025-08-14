// lib/services/image_cache_service.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  ImageCacheService._();
  static final instance = ImageCacheService._();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Returns an ImageProvider that:
  /// - first looks for the file in the local cache,
  /// - otherwise downloads it from Firebase Storage, stores it, and then displays it.
  ImageProvider imageProvider(String fileName) {
    return FileImageWithFallback(fileName, _downloadAndCache);
  }

  /// Downloads the image from Firebase Storage and caches it.
  Future<File> _downloadAndCache(String fileName) async {
    final url = await _storage.ref('model/$fileName').getDownloadURL();
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    final file = await _cacheFileFor(fileName);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Returns the local File for the cache (without guaranteeing it exists).
  Future<File> _cacheFileFor(String fileName) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/model_cache/$fileName');
  }

  /// Checks if an image is already cached locally.
  Future<bool> isImageCached(String fileName) async {
    final file = await _localFile(fileName);
    return file.exists();
  }

  /// Returns the local File for the cache.
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
    // Try to get the file from the local cache
    File file = await ImageCacheService.instance._localFile(fileName);
    if (!await file.exists()) {
      // Otherwise, download and cache it
      file = await downloadAndCache(fileName);
    }
    final bytes = await file.readAsBytes();
    return await ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileImageWithFallback && other.fileName == fileName;

  @override
  int get hashCode => fileName.hashCode;
}
