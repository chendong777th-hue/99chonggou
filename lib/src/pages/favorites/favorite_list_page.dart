import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/api/favorite_message_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/favorite_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/favorite_message_detail_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/widgets/favorite_media_preview.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

/// 微信风格「收藏」列表（`GET /me/favorites`）。
class FavoriteListPage extends StatefulWidget {
  const FavoriteListPage({super.key});

  @override
  State<FavoriteListPage> createState() => _FavoriteListPageState();
}

class _FavoriteListPageState extends State<FavoriteListPage> {
  List<FavoriteMessageItem> _items = [];
  bool _loading = true;
  String? _loadError;
  bool _editing = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await FavoriteMessageApi.instance.listAll();
      if (!mounted) return;
      setState(() {
        _items = items..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
        _loading = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = FavoriteMessageApi.errorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = DioErrorMessage.forApp(e);
        _loading = false;
      });
    }
  }

  Future<void> _upsert(FavoriteMessageItem item) async {
    setState(() {
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.insert(0, item);
      }
      _items.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
    });
  }

  Future<bool> _confirmDeleteDialog({int count = 1}) async {
    final i18n = AppI18n.of(context);
    return AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除收藏',
        zhHant: '刪除收藏',
        en: 'Delete Favorite',
        ja: 'お気に入りを削除',
        ko: '즐겨찾기 삭제',
      ),
      message: count > 1
          ? i18n.format(
              zhHans: '确定删除选中的 {count} 条收藏吗？删除后无法恢复。',
              zhHant: '確定刪除選中的 {count} 條收藏嗎？刪除後無法恢復。',
              en: 'Delete {count} selected favorites? This cannot be undone.',
              ja: '選択した{count}件のお気に入りを削除しますか？元に戻せません。',
              ko: '선택한 {count}개의 즐겨찾기를 삭제하시겠습니까? 복구할 수 없습니다.',
              vars: {'count': '$count'},
            )
          : i18n.t(
              zhHans: '删除后无法恢复，确定删除吗？',
              zhHant: '刪除後無法恢復，確定刪除嗎？',
              en: 'This cannot be undone. Delete?',
              ja: '削除後は復元できません。削除しますか？',
              ko: '삭제 후 복구할 수 없습니다. 삭제하시겠습니까?',
            ),
      confirmText: i18n.t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );
  }

  Future<void> _deleteItem(FavoriteMessageItem item) async {
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      _selectedIds.remove(item.id);
    });
    try {
      await FavoriteMessageApi.instance.delete(item.id);
      if (mounted) ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已删除',
        zhHant: '已刪除',
        en: 'Deleted',
        ja: '削除しました',
        ko: '삭제됨',
      ));
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _items.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
      });
      ToastUtils.toast(FavoriteMessageApi.errorMessage(e));
    }
  }

  Future<void> _confirmDelete(FavoriteMessageItem item) async {
    if (!await _confirmDeleteDialog()) return;
    if (!mounted) return;
    await _deleteItem(item);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    if (!await _confirmDeleteDialog(count: count)) return;
    if (!mounted) return;
    final ids = Set<String>.from(_selectedIds);
    setState(() {
      _items.removeWhere((e) => ids.contains(e.id));
      _selectedIds.clear();
      _editing = false;
    });
    try {
      await FavoriteMessageApi.instance.deleteMany(ids.toList());
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已删除',
        zhHant: '已刪除',
        en: 'Deleted',
        ja: '削除しました',
        ko: '삭제됨',
      ));
    } on DioError catch (e) {
      if (!mounted) return;
      await _load();
      ToastUtils.toast(FavoriteMessageApi.errorMessage(e));
    }
  }

  void _toggleEditMode() {
    setState(() {
      _editing = !_editing;
      if (!_editing) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelect(FavoriteMessageItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _openDetail(FavoriteMessageItem item) {
    Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => FavoriteMessageDetailPage(
          item: item,
          onChanged: _upsert,
          onDeleted: () {
            if (!mounted) return;
            setState(() => _items.removeWhere((e) => e.id == item.id));
          },
        ),
      ),
    );
  }

  Future<void> _openCreate(FavoriteMessageType type) async {
    final created = await FavoriteEditPage.pushCreate(context, type: type);
    if (created != null && mounted) {
      await _upsert(created);
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已保存',
        zhHant: '已儲存',
        en: 'Saved',
        ja: '保存しました',
        ko: '저장됨',
      ));
    }
  }

  Future<void> _openEdit(FavoriteMessageItem item) async {
    final updated = await FavoriteEditPage.pushEdit(context, item);
    if (updated != null && mounted) {
      await _upsert(updated);
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已保存',
        zhHant: '已儲存',
        en: 'Saved',
        ja: '保存しました',
        ko: '저장됨',
      ));
    }
  }

  void _showAddSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(AppI18n.of(context).t(
        zhHans: '添加收藏',
        zhHant: '新增收藏',
        en: 'Add Favorite',
        ja: 'お気に入りに追加',
        ko: '즐겨찾기 추가',
      )),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openCreate(FavoriteMessageType.text);
            },
            child: Text(AppI18n.of(context).t(
        zhHans: '笔记',
        zhHant: '筆記',
        en: 'Note',
        ja: 'メモ',
        ko: '메모',
      )),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openCreate(FavoriteMessageType.image);
            },
            child: Text(AppI18n.of(context).t(
        zhHans: '图片',
        zhHant: '圖片',
        en: 'Image',
        ja: '画像',
        ko: '이미지',
      )),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openCreate(FavoriteMessageType.video);
            },
            child: Text(AppI18n.of(context).t(
        zhHans: '视频',
        zhHant: '影片',
        en: 'Video',
        ja: '動画',
        ko: '동영상',
      )),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppI18n.of(context).t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      )),
        ),
      ),
    );
  }

  void _showItemActions(FavoriteMessageItem item) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openEdit(item);
            },
            child: Text(AppI18n.of(context).t(
        zhHans: '编辑',
        zhHant: '編輯',
        en: 'Edit',
        ja: '編集',
        ko: '편집',
      )),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(item);
            },
            child: Text(AppI18n.of(context).t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      )),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppI18n.of(context).t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(dark: dark),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryBlue,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppI18n.of(context).t(
        zhHans: '收藏',
        zhHant: '收藏',
        en: 'Favorites',
        ja: 'お気に入り',
        ko: '즐겨찾기',
      ),
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _toggleEditMode,
              child: Text(
                _editing ? AppI18n.of(context).t(
        zhHans: '完成',
        zhHant: '完成',
        en: 'Done',
        ja: '完了',
        ko: '완료',
      ) : AppI18n.of(context).t(
        zhHans: '编辑',
        zhHant: '編輯',
        en: 'Edit',
        ja: '編集',
        ko: '편집',
      ),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 16,
                ),
              ),
            ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.primaryBlue,
              onPressed: _showAddSheet,
              tooltip: AppI18n.of(context).t(
        zhHans: '添加',
        zhHant: '新增',
        en: 'Add',
        ja: '追加',
        ko: '추가',
      ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.subText(dark: dark),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: Text(AppI18n.of(context).t(
        zhHans: '重试',
        zhHant: '重試',
        en: 'Retry',
        ja: '再試行',
        ko: '다시 시도',
      )),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: AppEmptyState(message: AppI18n.of(context).t(
        zhHans: '暂无收藏',
        zhHant: '暫無收藏',
        en: 'No favorites yet',
        ja: 'お気に入りはありません',
        ko: '즐겨찾기 없음',
      )),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _showAddSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(AppI18n.of(context).t(
        zhHans: '添加收藏',
        zhHant: '新增收藏',
        en: 'Add Favorite',
        ja: 'お気に入りに追加',
        ko: '즐겨찾기 추가',
      )),
                        ),
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: _buildGroupedList(dark),
                  ),
                ),
      floatingActionButton: _items.isEmpty || _editing
          ? null
          : FloatingActionButton(
              onPressed: _showAddSheet,
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: _editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _selectedIds.isEmpty ? null : _deleteSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE64340),
                      disabledBackgroundColor: AppColors.line(dark: dark),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _selectedIds.isEmpty
                          ? AppI18n.of(context).t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      )
                          : AppI18n.of(context).format(
        zhHans: '删除({count})',
        zhHant: '刪除({count})',
        en: 'Delete ({count})',
        ja: '削除({count})',
        ko: '삭제({count})',
        vars: {'count': '${_selectedIds.length}'},
      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  List<Widget> _buildGroupedList(bool dark) {
    final groups = _groupByDate(_items);
    final children = <Widget>[];

    for (final entry in groups.entries) {
      children.add(_SectionHeader(label: entry.key, dark: dark));
      for (var i = 0; i < entry.value.length; i++) {
        final item = entry.value[i];
        final isLast = i == entry.value.length - 1;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildListTile(
              item: item,
              dark: dark,
              showBottomRadius: isLast,
              showTopRadius: i == 0,
            ),
          ),
        );
        if (!isLast) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 0.6,
                thickness: 0.6,
                indent: item.type == FavoriteMessageType.text ? 16 : 72,
                color: AppColors.line(dark: dark),
              ),
            ),
          );
        }
      }
      children.add(const SizedBox(height: 12));
    }
    return children;
  }

  Map<String, List<FavoriteMessageItem>> _groupByDate(
    List<FavoriteMessageItem> items,
  ) {
    final map = <String, List<FavoriteMessageItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final local = item.favoritedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      String label;
      if (day == today) {
        label = AppI18n.of(context).t(
        zhHans: '今天',
        zhHant: '今天',
        en: 'Today',
        ja: '今日',
        ko: '오늘',
      );
      } else if (day == yesterday) {
        label = AppI18n.of(context).t(
        zhHans: '昨天',
        zhHant: '昨天',
        en: 'Yesterday',
        ja: '昨日',
        ko: '어제',
      );
      } else if (now.difference(day).inDays < 7) {
        final appLocale = AppI18n.of(context).locale;
        final weekdayLocale = switch (appLocale) {
          AppLocale.en => 'en_US',
          AppLocale.ja => 'ja_JP',
          AppLocale.ko => 'ko_KR',
          AppLocale.zhHant => 'zh_TW',
          AppLocale.zhHans => 'zh_CN',
        };
        label = DateFormat('EEEE', weekdayLocale).format(local);
      } else {
        label = AppI18n.of(context).format(
          zhHans: '{year}年{month}月{day}日',
          zhHant: '{year}年{month}月{day}日',
          en: '{month}/{day}/{year}',
          ja: '{year}年{month}月{day}日',
          ko: '{year}년 {month}월 {day}일',
          vars: {
            'year': '${local.year}',
            'month': '${local.month}',
            'day': '${local.day}',
          },
        );
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  Widget _buildListTile({
    required FavoriteMessageItem item,
    required bool dark,
    required bool showTopRadius,
    required bool showBottomRadius,
  }) {
    final tile = _FavoriteListTile(
      item: item,
      dark: dark,
      showBottomRadius: showBottomRadius,
      showTopRadius: showTopRadius,
      editing: _editing,
      selected: _selectedIds.contains(item.id),
      onTap: () {
        if (_editing) {
          _toggleSelect(item);
        } else {
          _openDetail(item);
        }
      },
      onLongPress:
          _editing ? null : () => _showItemActions(item),
    );

    if (_editing) {
      return tile;
    }

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE64340),
          borderRadius: BorderRadius.vertical(
            top: showTopRadius ? const Radius.circular(12) : Radius.zero,
            bottom:
                showBottomRadius ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteDialog(),
      onDismissed: (_) => _deleteItem(item),
      child: tile,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.dark,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.subText(dark: dark),
        ),
      ),
    );
  }
}

class _FavoriteListTile extends StatelessWidget {
  const _FavoriteListTile({
    required this.item,
    required this.dark,
    required this.onTap,
    this.onLongPress,
    this.showTopRadius = true,
    this.showBottomRadius = true,
    this.editing = false,
    this.selected = false,
  });

  final FavoriteMessageItem item;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showTopRadius;
  final bool showBottomRadius;
  final bool editing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: showTopRadius ? const Radius.circular(12) : Radius.zero,
      bottom: showBottomRadius ? const Radius.circular(12) : Radius.zero,
    );

    return Material(
      color: AppColors.card(dark: dark),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (editing) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primaryBlue
                      : AppColors.subText(dark: dark),
                  size: 22,
                ),
                const SizedBox(width: 12),
              ],
              if (item.type != FavoriteMessageType.text) ...[
                _Thumb(item: item, dark: dark),
                const SizedBox(width: 12),
              ],
              Expanded(child: _Content(item: item, dark: dark)),
              const SizedBox(width: 8),
              Text(
                _timeLabel(item.favoritedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.subText(dark: dark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('M/d').format(local);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.dark});

  final FavoriteMessageItem item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: size,
            height: size,
            child: FavoriteMediaPreview(
              pathOrUrl: item.displayThumbPathOrUrl,
              dark: dark,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (item.type == FavoriteMessageType.video)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        if (item.type == FavoriteMessageType.video &&
            item.durationSec != null &&
            item.durationSec! > 0)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _formatDuration(item.durationSec!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '0:${s.toString().padLeft(2, '0')}';
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.item, required this.dark});

  final FavoriteMessageItem item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final preview = item.listPreview;
    final source = _sourceLine(context);
    final time = _timeLine(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview,
          maxLines: item.type == FavoriteMessageType.text ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: item.type == FavoriteMessageType.text ? 16 : 15,
            height: 1.35,
            fontWeight: item.type == FavoriteMessageType.text
                ? FontWeight.w400
                : FontWeight.w500,
            color: AppColors.text(dark: dark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.subText(dark: dark),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.subText(dark: dark),
          ),
        ),
      ],
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
