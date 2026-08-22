import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/widgets/favorite_media_preview.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/favorite_message_api.dart';
import 'package:tencent_cloud_chat_demo/utils/favorite_message_chat_sender.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';

/// 聊天「更多」面板：选择收藏并发送到当前会话。
class FavoritePickerSheet extends StatefulWidget {
  const FavoritePickerSheet({
    super.key,
    required this.chatController,
    required this.convId,
    required this.convType,
  });

  final TIMUIKitChatController chatController;
  final String convId;
  final ConvType convType;

  static Future<void> show(
    BuildContext context, {
    required TIMUIKitChatController chatController,
    required String convId,
    required ConvType convType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FavoritePickerSheet(
        chatController: chatController,
        convId: convId,
        convType: convType,
      ),
    );
  }

  @override
  State<FavoritePickerSheet> createState() => _FavoritePickerSheetState();
}

class _FavoritePickerSheetState extends State<FavoritePickerSheet> {
  List<FavoriteMessageItem> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _sendingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await FavoriteMessageApi.instance.listAll();
      if (!mounted) return;
      setState(() {
        _items = items..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
        _loading = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtils.toast(FavoriteMessageApi.errorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static const int _textPreviewThreshold = 72;

  void _openTextPreview(FavoriteMessageItem item) {
    final text = item.text?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final i18n = AppI18n.of(ctx);
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line(dark: dark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t(
                          zhHans: '全文',
                          zhHant: '全文',
                          en: 'Full Text',
                          ja: '全文',
                          ko: '전체 텍스트',
                        ),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(dark: dark),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close,
                        color: AppColors.subText(dark: dark),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.6, color: AppColors.line(dark: dark)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: AppColors.text(dark: dark),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _sendItem(item);
                            },
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text(i18n.t(
                        zhHans: '发送',
                        zhHant: '發送',
                        en: 'Send',
                        ja: '送信',
                        ko: '보내기',
                      )),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendItem(FavoriteMessageItem item) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendingId = item.id;
    });
    try {
      final ok = await FavoriteMessageChatSender.send(
        item: item,
        chatController: widget.chatController,
        convId: widget.convId,
        convType: widget.convType,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '已发送',
          zhHant: '已發送',
          en: 'Sent',
          ja: '送信しました',
          ko: '전송됨',
        ));
      } else {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '发送失败',
          zhHant: '發送失敗',
          en: 'Failed to send',
          ja: '送信に失敗しました',
          ko: '전송 실패',
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line(dark: dark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.t(
                      zhHans: '收藏',
                      zhHant: '收藏',
                      en: 'Favorites',
                      ja: 'お気に入り',
                      ko: '즐겨찾기',
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(dark: dark),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.subText(dark: dark),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0.6, color: AppColors.line(dark: dark)),
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _items.isEmpty
                    ? AppEmptyState(
                        message: i18n.t(
                          zhHans: '暂无收藏，可在「我」中添加',
                          zhHant: '暫無收藏，可在「我」中添加',
                          en: 'No favorites yet. Add them from Me.',
                          ja: 'お気に入りはありません。「マイページ」から追加できます。',
                          ko: '즐겨찾기가 없습니다. 「나」에서 추가할 수 있습니다.',
                        ),
                        imageWidth: 120,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 0.6,
                          color: AppColors.line(dark: dark),
                        ),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final sendingThis =
                              _sending && _sendingId == item.id;
                          return _FavoritePickerTile(
                            item: item,
                            dark: dark,
                            sending: sendingThis,
                            onTap: _sending
                                ? null
                                : () {
                                    if (item.type ==
                                        FavoriteMessageType.text) {
                                      _openTextPreview(item);
                                    } else {
                                      _sendItem(item);
                                    }
                                  },
                            onSend: _sending
                                ? null
                                : () => _sendItem(item),
                            onViewFullText: item.type ==
                                    FavoriteMessageType.text &&
                                (item.text?.trim().length ?? 0) >
                                    _textPreviewThreshold
                                ? () => _openTextPreview(item)
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FavoritePickerTile extends StatelessWidget {
  const _FavoritePickerTile({
    required this.item,
    required this.dark,
    required this.onTap,
    this.onSend,
    this.onViewFullText,
    this.sending = false,
  });

  final FavoriteMessageItem item;
  final bool dark;
  final VoidCallback? onTap;
  final VoidCallback? onSend;
  final VoidCallback? onViewFullText;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final isText = item.type == FavoriteMessageType.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isText) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FavoriteMediaPreview(
                          pathOrUrl: item.displayThumbPathOrUrl,
                          dark: dark,
                          fit: BoxFit.cover,
                        ),
                        if (item.type == FavoriteMessageType.video)
                          Container(
                            color: Colors.black.withValues(alpha: 0.25),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.listPreview,
                      maxLines: isText ? 4 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: AppColors.text(dark: dark),
                      ),
                    ),
                    if (onViewFullText != null) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onViewFullText,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          i18n.t(
                            zhHans: '查看全文',
                            zhHant: '查看全文',
                            en: 'View Full Text',
                            ja: '全文を見る',
                            ko: '전체 보기',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _sourceLine(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subText(dark: dark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timeLine(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subText(dark: dark),
                      ),
                    ),
                  ],
                ),
              ),
              if (sending)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: IconButton(
                    onPressed: onSend,
                    icon: Icon(
                      Icons.send_rounded,
                      size: 22,
                      color: AppColors.primaryBlue.withValues(alpha: 0.9),
                    ),
                    tooltip: i18n.t(
                      zhHans: '发送',
                      zhHant: '發送',
                      en: 'Send',
                      ja: '送信',
                      ko: '보내기',
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLine(BuildContext context) {
    final i18n = AppI18n.of(context);
    final sender = item.sourceSenderName?.trim() ?? '';
    final conv = item.sourceConvLabel?.trim() ?? '';
    final parts = <String>[];
    if (sender.isNotEmpty) parts.add(sender);
    if (conv.isNotEmpty && conv != sender) parts.add(conv);
    final source = parts.isEmpty
        ? i18n.t(
            zhHans: '手动添加',
            zhHant: '手動新增',
            en: 'Manual',
            ja: '手動追加',
            ko: '직접 추가',
          )
        : parts.join(' · ');
    return '${i18n.t(
      zhHans: '来源',
      zhHant: '來源',
      en: 'Source',
      ja: 'ソース',
      ko: '출처',
    )}：$source';
  }

  String _timeLine(BuildContext context) {
    final i18n = AppI18n.of(context);
    return '${i18n.t(
      zhHans: '收藏时间',
      zhHant: '收藏時間',
      en: 'Saved at',
      ja: '保存日時',
      ko: '저장 시간',
    )}：${DateFormat('yyyy-MM-dd HH:mm').format(item.favoritedAt.toLocal())}';
  }
}
