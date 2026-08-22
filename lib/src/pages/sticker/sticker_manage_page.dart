import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/sticker/sticker_upload_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class StickerManagePage extends StatefulWidget {
  const StickerManagePage({super.key});

  @override
  State<StickerManagePage> createState() => _StickerManagePageState();
}

class _StickerManagePageState extends State<StickerManagePage> {
  @override
  void initState() {
    super.initState();
    UserStickerProvider.shared.addListener(_onChanged);
    UserStickerProvider.shared.refresh(force: true).then((_) {
      _publishPackages();
    });
  }

  @override
  void dispose() {
    UserStickerProvider.shared.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
      _publishPackages();
    }
  }

  void _publishPackages() {
    final data = Provider.of<CustomStickerPackageData>(context, listen: false);
    UserStickerProvider.shared.publishTo(data);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final provider = UserStickerProvider.shared;
    final packs = provider.serverPacks;
    final uploadPack = packs
        .where((p) => p.packId == StickerConstants.userUploadPackId)
        .cast<StickerPack?>()
        .firstOrNull;
    final uploads = uploadPack?.stickers ?? [];
    final sheetLabel = i18n.t(
      zhHans: '张',
      zhHant: '張',
      en: 'items',
      ja: '枚',
      ko: '개',
    );
    final titleStyle = TextStyle(
      color: AppColors.text(dark: dark),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = TextStyle(
      color: AppColors.text(dark: dark),
      fontSize: 16,
    );
    final subStyle = TextStyle(
      color: AppColors.subText(dark: dark),
      fontSize: 13,
    );
    final iconColor = AppColors.subText(dark: dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background(dark: dark),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.card(dark: dark),
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppColors.primaryBlue),
          title: Text(
            i18n.t(
              zhHans: '我的表情',
              zhHant: '我的表情',
              en: 'My Stickers',
              ja: 'マイスタンプ',
              ko: '내 스티커',
            ),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              i18n.t(
                zhHans: '表情包',
                zhHant: '表情包',
                en: 'Sticker Packs',
                ja: 'スタンプパック',
                ko: '스티커 팩',
              ),
              style: titleStyle,
            ),
            const SizedBox(height: 8),
            if (packs.isEmpty)
              Text(
                i18n.t(
                  zhHans: '暂无服务端表情包（后端未就绪时仅显示内置表情）',
                  zhHant: '暫無服務端表情包（後端未就緒時僅顯示內置表情）',
                  en: 'No server sticker packs yet (built-in stickers only when backend is unavailable).',
                  ja: 'サーバーのスタンプパックはありません（バックエンド未準備時は内蔵スタンプのみ表示）。',
                  ko: '서버 스티커 팩이 없습니다(백엔드 미준비 시 기본 스티커만 표시).',
                ),
                style: subStyle,
              )
            else
              ...packs.map((pack) {
                return ListTile(
                  title: Text(
                    pack.name.isNotEmpty ? pack.name : pack.packId,
                    style: bodyStyle,
                  ),
                  subtitle: Text(
                    '${pack.stickers.length} $sheetLabel',
                    style: subStyle,
                  ),
                  trailing: pack.removable
                      ? IconButton(
                          icon: Icon(Icons.delete_outline, color: iconColor),
                          onPressed: () async {
                            try {
                              await provider.uninstallPack(pack.packId);
                            } catch (_) {
                              ToastUtils.toast(i18n.t(
                                zhHans: '移除失败',
                                zhHant: '移除失敗',
                                en: 'Failed to remove.',
                                ja: '削除に失敗しました。',
                                ko: '제거에 실패했습니다.',
                              ));
                            }
                          },
                        )
                      : null,
                );
              }),
            Divider(height: 24, color: AppColors.line(dark: dark)),
            ListTile(
              title: Text(
                i18n.t(
                  zhHans: '我的上传',
                  zhHant: '我的上傳',
                  en: 'My Uploads',
                  ja: 'アップロード',
                  ko: '내 업로드',
                ),
                style: bodyStyle,
              ),
              subtitle: Text(
                uploads.isEmpty
                    ? i18n.t(
                        zhHans: '还没有上传表情',
                        zhHant: '還沒有上傳表情',
                        en: 'No uploaded stickers yet',
                        ja: 'アップロードしたスタンプはありません',
                        ko: '업로드한 스티커가 없습니다',
                      )
                    : '${uploads.length} $sheetLabel',
                style: subStyle,
              ),
              trailing: Icon(Icons.chevron_right, color: iconColor),
              onTap: () {
                Navigator.push(
                  context,
                  AppMaterialPageRoute(
                    builder: (_) => const StickerUploadPage(),
                  ),
                );
              },
            ),
            Divider(height: 24, color: AppColors.line(dark: dark)),
            Text(
              i18n.t(
                zhHans: '收藏',
                zhHant: '收藏',
                en: 'Favorites',
                ja: 'お気に入り',
                ko: '즐겨찾기',
              ),
              style: titleStyle,
            ),
            const SizedBox(height: 8),
            if (provider.favorites.isEmpty)
              Text(
                i18n.t(
                  zhHans: '暂无收藏',
                  zhHant: '暫無收藏',
                  en: 'No favorites yet',
                  ja: 'お気に入りはありません',
                  ko: '즐겨찾기가 없습니다',
                ),
                style: subStyle,
              )
            else
              ...provider.favorites.map((fav) {
                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: StickerImage(
                      item: fav.toStickerItem(),
                      preferAnimated: true,
                      width: 40,
                      height: 40,
                    ),
                  ),
                  title: Text(fav.stickerId, style: bodyStyle),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Color(0xFFF5A623)),
                    onPressed: () async {
                      try {
                        await provider.unfavorite(fav.stickerId);
                      } catch (_) {
                        ToastUtils.toast(i18n.t(
                          zhHans: '操作失败',
                          zhHant: '操作失敗',
                          en: 'Operation failed.',
                          ja: '操作に失敗しました。',
                          ko: '작업에 실패했습니다.',
                        ));
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) {
      return it.current;
    }
    return null;
  }
}
