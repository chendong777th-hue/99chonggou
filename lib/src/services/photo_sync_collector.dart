import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../platform/permission_guard.dart';
import 'photo_compress_util.dart';
import 'sync_fingerprint.dart';

/// One local media asset prepared for device backup.
///
/// Images are compressed before upload and hashed from the uploaded bytes.
/// Videos are uploaded as original files and hashed from the original bytes.
class PreparedPhotoUpload {
  PreparedPhotoUpload({
    required this.localAssetId,
    required this.uploadFile,
    required this.deleteAfterUpload,
    required this.contentHash,
    required this.sizeBytes,
    required this.mediaType,
    required this.mimeType,
    this.takenAt,
    this.width,
    this.height,
    this.durationSeconds,
  });

  final String localAssetId;
  final File uploadFile;
  final bool deleteAfterUpload;
  final String contentHash;
  final int sizeBytes;

  /// Backend enum value: IMAGE | VIDEO.
  final String mediaType;
  final String mimeType;
  final DateTime? takenAt;
  final int? width;
  final int? height;

  /// Required by backend for VIDEO. Unit: seconds.
  final int? durationSeconds;

  bool get isVideo => mediaType == 'VIDEO';

  Future<void> dispose() async {
    if (deleteAfterUpload) {
      try {
        if (await uploadFile.exists()) {
          await uploadFile.delete();
        }
      } catch (_) {}
    }
  }
}

class PhotoAlbumSession {
  PhotoAlbumSession(this._album);

  final AssetPathEntity _album;
  int? _totalCount;

  Future<int> totalCount() async {
    _totalCount ??= await _album.assetCountAsync;
    return _totalCount!;
  }

  /// Reads the system album page by page, newest first.
  Future<List<AssetEntity>> loadAssetPage({
    required int page,
    int pageSize = PhotoSyncCollector.pageSize,
  }) async {
    return _album.getAssetListPaged(page: page, size: pageSize);
  }
}

class PhotoSyncCollector {
  PhotoSyncCollector._();

  /// Each page is small to avoid blocking the UI thread on large albums.
  static const int pageSize = 24;

  static String _platformLocalAssetId(String rawId) {
    if (Platform.isAndroid) {
      return rawId.startsWith('android:') ? rawId : 'android:$rawId';
    }
    if (Platform.isIOS) {
      return rawId.startsWith('ios:') ? rawId : 'ios:$rawId';
    }
    return rawId;
  }

  static Future<PhotoAlbumSession?> openAlbum() async {
    if (kIsWeb) {
      return null;
    }
    if (!await PermissionGuard.hasPhotosForDeviceSync()) {
      debugPrint('PhotoSyncCollector: media permission is not granted');
      return null;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      debugPrint('PhotoSyncCollector: no media album found');
      return null;
    }
    final album = paths.first;
    debugPrint(
      'PhotoSyncCollector: open album id=${album.id} name=${album.name}',
    );
    return PhotoAlbumSession(album);
  }

  static Future<List<PreparedPhotoUpload>> preparePage(
    List<AssetEntity> assets,
  ) async {
    final prepared = <PreparedPhotoUpload>[];
    for (final asset in assets) {
      final item = await prepareOne(asset);
      if (item != null) {
        prepared.add(item);
      }
      await _yieldToUi();
    }
    return prepared;
  }

  static String _guessVideoMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'video/3gpp';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  static String? _normalizeVideoMimeType(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'video/mov') return 'video/quicktime';
    if (value == 'video/3gp') return 'video/3gpp';
    if (value == 'video/mp4' ||
        value == 'video/quicktime' ||
        value == 'video/webm' ||
        value == 'video/3gpp' ||
        value == 'video/x-m4v') {
      return value;
    }
    if (value.startsWith('video/')) return value;
    return null;
  }

  static String _normalizeImageMimeType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'image/jpg') return 'image/jpeg';
    if (value.startsWith('image/')) return value;
    return 'image/jpeg';
  }

  /// iOS [AssetEntity.file] decodes and re-encodes JPEG on the main thread.
  /// [originFile] copies the original resource asynchronously instead.
  static Future<File?> _openOriginFile(AssetEntity asset) async {
    if (Platform.isIOS) {
      final local = await asset.isLocallyAvailable(isOrigin: true);
      if (!local) {
        debugPrint(
          'PhotoSyncCollector: asset ${asset.id} not locally available, defer',
        );
        return null;
      }
    }
    return asset.originFile;
  }

  static Future<void> _yieldToUi() async {
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  static Future<PreparedPhotoUpload?> prepareOne(AssetEntity asset) async {
    try {
      await _yieldToUi();
      final origin = await _openOriginFile(asset);
      if (origin == null || !await origin.exists()) {
        debugPrint(
          'PhotoSyncCollector: asset ${asset.id} file unavailable type=${asset.type}',
        );
        return null;
      }

      final localAssetId = _platformLocalAssetId(asset.id);

      if (asset.type == AssetType.video) {
        final sizeBytes = await origin.length();
        if (sizeBytes <= 0) {
          debugPrint('PhotoSyncCollector: video $localAssetId skipped zero size');
          return null;
        }
        final hash = await SyncFingerprint.fileContentHash(origin);
        final assetMimeType = await asset.mimeTypeAsync;
        final mimeType =
            _normalizeVideoMimeType(assetMimeType) ?? _guessVideoMimeType(origin.path);
        final durationSeconds = asset.videoDuration.inSeconds;
        debugPrint(
          'PhotoSyncCollector: video asset ${asset.id} '
          'localAssetId=$localAssetId size=$sizeBytes '
          'mimeType=$mimeType duration=${durationSeconds}s',
        );
        return PreparedPhotoUpload(
          localAssetId: localAssetId,
          uploadFile: origin,
          deleteAfterUpload: false,
          contentHash: hash,
          sizeBytes: sizeBytes,
          mediaType: 'VIDEO',
          mimeType: mimeType,
          takenAt: asset.createDateTime,
          width: asset.width,
          height: asset.height,
          durationSeconds: durationSeconds,
        );
      }

      if (asset.type != AssetType.image) {
        debugPrint(
          'PhotoSyncCollector: skip unsupported asset ${asset.id} type=${asset.type}',
        );
        return null;
      }

      final compressed = await PhotoCompressUtil.compressForUpload(origin);
      if (compressed == null) {
        debugPrint('PhotoSyncCollector: image $localAssetId compress failed');
        return null;
      }
      final uploadFile = compressed.file;
      final sizeBytes = await uploadFile.length();
      if (sizeBytes <= 0) {
        if (compressed.deleteAfterUpload) {
          await uploadFile.delete();
        }
        debugPrint('PhotoSyncCollector: image $localAssetId skipped zero size');
        return null;
      }
      final hash = await SyncFingerprint.fileContentHash(uploadFile);
      final mimeType = _normalizeImageMimeType(compressed.mimeType);
      debugPrint(
        'PhotoSyncCollector: image asset ${asset.id} '
        'localAssetId=$localAssetId size=$sizeBytes mimeType=$mimeType',
      );
      return PreparedPhotoUpload(
        localAssetId: localAssetId,
        uploadFile: uploadFile,
        deleteAfterUpload: compressed.deleteAfterUpload,
        contentHash: hash,
        sizeBytes: sizeBytes,
        mediaType: 'IMAGE',
        mimeType: mimeType,
        takenAt: asset.createDateTime,
        width: asset.width,
        height: asset.height,
      );
    } catch (e) {
      debugPrint('PhotoSyncCollector: prepare ${asset.id} failed: $e');
      return null;
    }
  }
}
