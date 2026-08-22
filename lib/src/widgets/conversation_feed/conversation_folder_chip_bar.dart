import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';

/// 搜索栏下方的分组胶囊条（参考图：整条白底圆角条 + 内嵌选中灰底）。
/// 无分组时不应挂载本组件。
class ConversationFolderChipBar extends StatelessWidget {
  const ConversationFolderChipBar({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.unreadForFolder,
    required this.onSelectAll,
    required this.onSelectFolder,
    required this.onCreateFolder,
    this.onFolderLongPress,
  });

  final List<ConversationFolder> folders;
  final String? selectedFolderId;
  final int Function(ConversationFolder folder) unreadForFolder;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectFolder;
  final VoidCallback onCreateFolder;
  final ValueChanged<ConversationFolder>? onFolderLongPress;

  static const Color _barBg = Color(0xFFFFFFFF);
  static const Color _selectedBg = Color(0xFFECECEC);
  static const Color _labelColor = Color(0xFF1C1C1E);
  static const Color _badgeBg = Color(0xFFA8A8AE);
  static const Color _addFg = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _barBg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: defaultTargetPlatform == TargetPlatform.android
                      ? const <BoxShadow>[]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Segment(
                        label: AppI18n.of(context).t(
                          zhHans: '全部',
                          zhHant: '全部',
                          en: 'All',
                          ja: 'すべて',
                          ko: '전체',
                        ),
                        selected: selectedFolderId == null,
                        badge: 0,
                        onTap: onSelectAll,
                      ),
                      for (final folder in folders)
                        _Segment(
                          label: folder.name,
                          selected: selectedFolderId == folder.folderId,
                          badge: unreadForFolder(folder),
                          onTap: () => onSelectFolder(folder.folderId),
                          onLongPress: onFolderLongPress == null
                              ? null
                              : () => onFolderLongPress!(folder),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onCreateFolder,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _barBg,
                  shape: BoxShape.circle,
                  boxShadow: defaultTargetPlatform == TargetPlatform.android
                      ? const <BoxShadow>[]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: _addFg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final badgeText = badge > 99 ? '99+' : '$badge';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? ConversationFolderChipBar._selectedBg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: ConversationFolderChipBar._labelColor,
                    height: 1.1,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    height: 16,
                    padding: EdgeInsets.symmetric(
                      horizontal: badgeText.length > 1 ? 4 : 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ConversationFolderChipBar._badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
