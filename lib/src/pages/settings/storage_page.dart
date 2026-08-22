import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:provider/provider.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  bool _loading = true;
  bool _cleaning = false;

  int _mediaBytes = 0;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  Future<void> _refreshUsage() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final usage = await _collectUsage();
      if (!mounted) return;
      setState(() {
        _mediaBytes = usage.mediaBytes;
        _cacheBytes = usage.cacheBytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _clearCache() async {
    if (_cleaning) return;
    final i18n = AppI18n.of(context);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '清理缓存',
        zhHant: '清理快取',
        en: 'Clear Cache',
        ja: 'キャッシュを削除',
        ko: '캐시 삭제',
      ),
      message: i18n.t(
        zhHans: '将清理本地缓存文件，但不会删除账号信息。是否继续？',
        zhHant: '將清理本機快取檔案，但不會刪除帳號資訊。是否繼續？',
        en: 'This will clear local cached files but will not delete your account information. Continue?',
        ja: 'ローカルのキャッシュファイルを削除しますが、アカウント情報は削除されません。続行しますか？',
        ko: '로컬 캐시 파일이 삭제되지만 계정 정보는 삭제되지 않습니다. 계속하시겠습니까?',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '清理',
        zhHant: '清理',
        en: 'Clear',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );

    if (!confirmed) return;

    if (!mounted) return;
    setState(() => _cleaning = true);
    try {
      await _deleteCacheTargets();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _refreshUsage();
      if (!mounted) return;
      _showMessage(i18n.t(
        zhHans: '缓存已清理',
        zhHant: '快取已清理',
        en: 'Cache cleared',
        ja: 'キャッシュを削除しました',
        ko: '캐시를 삭제했습니다',
      ));
    } catch (_) {
      if (!mounted) return;
      _showMessage(i18n.t(
        zhHans: '清理失败，请稍后重试',
        zhHant: '清理失敗，請稍後再試',
        en: 'Failed to clear cache. Please try again later.',
        ja: 'キャッシュの削除に失敗しました。しばらくしてからもう一度お試しください。',
        ko: '캐시 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    } finally {
      if (mounted) {
        setState(() => _cleaning = false);
      }
    }
  }

  Future<_StorageUsage> _collectUsage() async {
    final tempDir = await getTemporaryDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final docsDir = await getApplicationDocumentsDirectory();
    final chatRoot = _resolveChatStorageRoot(supportDir, docsDir);
    final mediaRoot = _resolveMediaRoot(chatRoot);

    final mediaTargets = <String>{
      if (mediaRoot != null) mediaRoot.path,
      if (chatRoot != null) _joinIfExists(chatRoot.path, 'screenshots'),
    }.where((e) => e.isNotEmpty).toList();

    final cacheTargets = <String>{
      tempDir.path,
      if (chatRoot != null) chatRoot.path,
      _joinIfExists(supportDir.path, 'libCachedImageData'),
      _joinIfExists(supportDir.path, 'flutter_image_compress'),
      _joinIfExists(supportDir.path, 'image_picker'),
      _joinIfExists(supportDir.path, 'wechat_assets_picker'),
    }.where((e) => e.isNotEmpty).toList();

    final mediaBytes = await _sumDirectories(mediaTargets);
    final cacheBytes = await _sumDirectories(cacheTargets);
    return _StorageUsage(
      mediaBytes: mediaBytes,
      cacheBytes: cacheBytes,
    );
  }

  Future<void> _deleteCacheTargets() async {
    final tempDir = await getTemporaryDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final docsDir = await getApplicationDocumentsDirectory();
    final chatRoot = _resolveChatStorageRoot(supportDir, docsDir);
    final screenshotsDir = chatRoot == null
        ? null
        : Directory(p.join(chatRoot.path, 'screenshots'));

    final cacheTargets = <String>{
      tempDir.path,
      _joinIfExists(supportDir.path, 'libCachedImageData'),
      _joinIfExists(supportDir.path, 'flutter_image_compress'),
      _joinIfExists(supportDir.path, 'image_picker'),
      _joinIfExists(supportDir.path, 'wechat_assets_picker'),
    }.where((e) => e.isNotEmpty).toList();

    for (final path in cacheTargets) {
      final entity = Directory(path);
      if (!await entity.exists()) continue;

      if (path == tempDir.path) {
        await for (final child in entity.list(followLinks: false)) {
          try {
            await child.delete(recursive: true);
          } catch (_) {}
        }
      } else {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }

    if (screenshotsDir != null && await screenshotsDir.exists()) {
      try {
        await screenshotsDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<int> _sumDirectories(List<String> paths) async {
    final seen = <String>{};
    var total = 0;
    for (final path in paths) {
      if (path.isEmpty || !seen.add(path)) continue;
      total += await _directorySize(Directory(path));
    }
    return total;
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  String _joinIfExists(String base, String child) {
    return p.join(base, child);
  }

  Directory? _resolveChatStorageRoot(
    Directory supportDir,
    Directory docsDir,
  ) {
    try {
      final appFileDir = CommonUtils.appFileDir;
      return appFileDir;
    } catch (_) {
      final supportTencent =
          Directory(p.join(supportDir.path, '.TencentCloudChat'));
      if (supportTencent.existsSync()) {
        return supportTencent;
      }
      final docsTencent = Directory(p.join(docsDir.path, '.TencentCloudChat'));
      if (docsTencent.existsSync()) {
        return docsTencent;
      }
      return Platform.isAndroid ? supportDir : docsDir;
    }
  }

  Directory? _resolveMediaRoot(Directory? chatRoot) {
    if (chatRoot == null) return null;
    final sdkAppId = CommonUtils.getSDKAppID();
    final loginUser = CommonUtils.getLoginUser();
    if (sdkAppId != null && loginUser.isNotEmpty) {
      final scoped = Directory(p.join(chatRoot.path, '$sdkAppId', loginUser));
      if (scoped.existsSync()) {
        return scoped;
      }
    }
    return chatRoot;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    final digits = value >= 100 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
  }

  void _showMessage(String text) {
    ToastUtils.toast(text);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LoginUserInfo>();
    final dark = settingsIsDark(context);
    final totalBytes = _mediaBytes + _cacheBytes;
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '储存空间',
        zhHant: '儲存空間',
        en: 'Storage',
        ja: 'ストレージ',
        ko: '저장 공간',
      ),
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            border: Border(
              top: BorderSide(
                color: AppColors.line(dark: dark),
                width: 0.6,
              ),
              bottom: BorderSide(
                color: AppColors.line(dark: dark),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                size: 36,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t(
                        zhHans: '已用空间',
                        zhHant: '已用空間',
                        en: 'Used Space',
                        ja: '使用済み容量',
                        ko: '사용 중인 공간',
                      ),
                      style: TextStyle(
                        color: AppColors.text(dark: dark),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loading
                          ? i18n.t(
                              zhHans: '正在统计本地聊天图片、视频和缓存',
                              zhHant: '正在統計本機聊天圖片、影片與快取',
                              en: 'Calculating local chat media and cache usage...',
                              ja: 'ローカルのチャット画像、動画、キャッシュ容量を集計しています...',
                              ko: '로컬 채팅 이미지, 동영상 및 캐시 사용량을 계산하는 중입니다...',
                            )
                          : _formatBytes(totalBytes),
                      style: TextStyle(
                        color: AppColors.subText(dark: dark),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _refreshUsage,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.primaryBlue,
                ),
            ],
          ),
        ),
        SettingsGroup(
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '聊天图片和视频',
                zhHant: '聊天圖片與影片',
                en: 'Chat Photos and Videos',
                ja: 'チャット画像と動画',
                ko: '채팅 사진 및 동영상',
              ),
              value: _loading
                  ? i18n.t(
                      zhHans: '统计中',
                      zhHant: '統計中',
                      en: 'Calculating',
                      ja: '集計中',
                      ko: '계산 중',
                    )
                  : _formatBytes(_mediaBytes),
              showArrow: false,
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '缓存数据',
                zhHant: '快取資料',
                en: 'Cached Data',
                ja: 'キャッシュデータ',
                ko: '캐시 데이터',
              ),
              value: _loading
                  ? i18n.t(
                      zhHans: '统计中',
                      zhHant: '統計中',
                      en: 'Calculating',
                      ja: '集計中',
                      ko: '계산 중',
                    )
                  : _formatBytes(_cacheBytes),
              showArrow: false,
              showDivider: false,
            ),
          ],
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.line(dark: dark),
              disabledForegroundColor: AppColors.subText(dark: dark),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: (_loading || _cleaning || _cacheBytes == 0)
                ? null
                : _clearCache,
            child: Text(
              _cleaning
                  ? i18n.t(
                      zhHans: '清理中...',
                      zhHant: '清理中...',
                      en: 'Clearing...',
                      ja: '削除中...',
                      ko: '정리 중...',
                    )
                  : i18n.t(
                      zhHans: '清理缓存',
                      zhHant: '清理快取',
                      en: 'Clear Cache',
                      ja: 'キャッシュを削除',
                      ko: '캐시 삭제',
                    ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageUsage {
  final int mediaBytes;
  final int cacheBytes;

  const _StorageUsage({
    required this.mediaBytes,
    required this.cacheBytes,
  });
}
