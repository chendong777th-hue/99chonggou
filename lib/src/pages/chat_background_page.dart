import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_file_access.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 聊天背景设置页。
///
/// - 从设置进入：`conversationId = global_chat_background`，只改全局默认。
/// - 从单聊设置/资料进入：可在「当前聊天 / 全部聊天」间切换；
///   聊天页解析顺序为「会话专属 → 全局默认 → 系统默认」。
/// - Web / 桌面：左右布局（左选项、右预览）；`embedded` 时由外层提供返回栏。
class ChatBackgroundPage extends StatefulWidget {
  final String conversationId;
  final String conversationName;

  /// 嵌入桌面右栏 / 弹窗时隐藏自带 AppBar，由外层提供标题与返回。
  final bool embedded;

  /// 外层返回（仅 [embedded] 时使用）。
  final VoidCallback? onClose;

  const ChatBackgroundPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

enum _BackgroundScope {
  /// 仅当前会话。
  currentChat,

  /// 全部聊天的默认背景。
  allChats,
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  static const List<Color> _colorOptions = <Color>[
    Color(0xFFF1F1F1),
    Color(0xFFCFECCB),
    Color(0xFFBEDBFF),
    Color(0xFFF9C9D2),
    Color(0xFFFFF3B6),
    Color(0xFFD9B8E8),
  ];

  static const List<_RecommendedBackground> _recommendedOptions =
      <_RecommendedBackground>[
    _RecommendedBackground(
      title: _BackgroundLabel.beauty,
      assetPath: 'assets/chat_backgrounds/beauty.png',
    ),
    _RecommendedBackground(
      title: _BackgroundLabel.scenery,
      assetPath: 'assets/chat_backgrounds/scenery.png',
    ),
    _RecommendedBackground(
      title: _BackgroundLabel.car,
      assetPath: 'assets/chat_backgrounds/car.png',
    ),
  ];

  late _BackgroundScope _scope;
  String? _directValue;
  String? _globalValue;
  bool _loading = true;
  bool _saving = false;
  bool _colorsExpanded = true;
  bool _recommendedExpanded = true;

  bool get _isGlobalOnlyEntry =>
      widget.conversationId.trim() ==
      ChatBackgroundService.globalBackgroundConversationId;

  String get _activeTargetId => _scope == _BackgroundScope.allChats
      ? ChatBackgroundService.globalBackgroundConversationId
      : widget.conversationId.trim();

  /// 预览用：当前范围下实际会看到的背景。
  String? get _previewValue {
    if (_scope == _BackgroundScope.allChats) {
      return _globalValue;
    }
    if (_directValue != null && _directValue!.isNotEmpty) {
      return _directValue;
    }
    return _globalValue;
  }

  bool get _hasDirectOverride =>
      _scope == _BackgroundScope.currentChat &&
      _directValue != null &&
      _directValue!.isNotEmpty;

  bool get _hasEditableValue {
    if (_scope == _BackgroundScope.allChats) {
      return _globalValue != null && _globalValue!.isNotEmpty;
    }
    return _hasDirectOverride;
  }

  @override
  void initState() {
    super.initState();
    _scope = _isGlobalOnlyEntry
        ? _BackgroundScope.allChats
        : _BackgroundScope.currentChat;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ChatBackgroundService.instance;
    String? direct;
    String? global;
    if (_isGlobalOnlyEntry) {
      global = await service.getBackgroundPath(
        ChatBackgroundService.globalBackgroundConversationId,
      );
    } else {
      direct = await service.getBackgroundPath(widget.conversationId);
      global = await service.getBackgroundPath(
        ChatBackgroundService.globalBackgroundConversationId,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _directValue = direct;
      _globalValue = global;
      _loading = false;
    });
  }

  Future<void> _pickBackground() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await ChatBackgroundService.instance
          .saveBackgroundFromGallery(context, _activeTargetId);
      if (!mounted || path == null || path.isEmpty) {
        return;
      }
      setState(() => _afterSavedSync(path));
      _toastSaved();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _afterSavedSync(String? path) {
    if (_scope == _BackgroundScope.allChats) {
      _globalValue = path;
    } else {
      _directValue = path;
    }
  }

  Future<void> _clearBackground() async {
    if (_saving || !_hasEditableValue) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ChatBackgroundService.instance.clearBackground(_activeTargetId);
      if (!mounted) {
        return;
      }
      setState(() => _afterSavedSync(null));
      final i18n = AppI18n.of(context);
      ToastUtils.toast(
        _scope == _BackgroundScope.allChats
            ? i18n.t(
                zhHans: '已清除全局默认背景',
                zhHant: '已清除全域預設背景',
                en: 'Global default background cleared.',
                ja: '全体のデフォルト背景を削除しました。',
                ko: '전체 기본 배경을 지웠습니다.',
              )
            : i18n.t(
                zhHans: '已清除本聊天背景，将使用全局默认',
                zhHant: '已清除本聊天背景，將使用全域預設',
                en: 'This chat will now use the global default.',
                ja: 'このチャットの背景を削除し、全体デフォルトを使います。',
                ko: '이 채팅 배경을 지웠습니다. 전체 기본 배경을 사용합니다.',
              ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectColor(Color color) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ChatBackgroundService.instance.saveColorBackground(
        _activeTargetId,
        color,
      );
      if (!mounted) {
        return;
      }
      final value =
          '${ChatBackgroundService.colorPrefix}${color.value.toRadixString(16)}';
      setState(() => _afterSavedSync(value));
      _toastSaved();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectAsset(String assetPath) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ChatBackgroundService.instance.saveAssetBackground(
        _activeTargetId,
        assetPath,
      );
      if (!mounted) {
        return;
      }
      final value = '${ChatBackgroundService.assetPrefix}$assetPath';
      setState(() => _afterSavedSync(value));
      _toastSaved();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toastSaved() {
    final i18n = AppI18n.of(context);
    ToastUtils.toast(
      _scope == _BackgroundScope.allChats
          ? i18n.t(
              zhHans: '已设为全部聊天的默认背景',
              zhHant: '已設為全部聊天的預設背景',
              en: 'Set as the default for all chats.',
              ja: 'すべてのチャットのデフォルト背景に設定しました。',
              ko: '모든 채팅의 기본 배경으로 설정했습니다.',
            )
          : i18n.t(
              zhHans: '已仅对本聊天生效',
              zhHant: '已僅對本聊天生效',
              en: 'Applied to this chat only.',
              ja: 'このチャットのみに適用しました。',
              ko: '이 채팅에만 적용되었습니다.',
            ),
    );
  }

  Widget _buildScopeSwitcher(bool dark, AppI18n i18n) {
    if (_isGlobalOnlyEntry) {
      return const SizedBox.shrink();
    }
    final selected = _scope;
    Widget chip(_BackgroundScope scope, String label) {
      final on = selected == scope;
      return Expanded(
        child: GestureDetector(
          onTap: _saving
              ? null
              : () {
                  if (_scope == scope) {
                    return;
                  }
                  setState(() => _scope = scope);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on
                  ? AppColors.primaryBlue
                  : (dark ? const Color(0xFF2A2D33) : const Color(0xFFEDEFF2)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: on ? Colors.white : AppColors.text(dark: dark),
                fontSize: 14,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          chip(
            _BackgroundScope.currentChat,
            i18n.t(
              zhHans: '当前聊天',
              zhHant: '目前聊天',
              en: 'This Chat',
              ja: 'このチャット',
              ko: '이 채팅',
            ),
          ),
          const SizedBox(width: 10),
          chip(
            _BackgroundScope.allChats,
            i18n.t(
              zhHans: '全部聊天',
              zhHant: '全部聊天',
              en: 'All Chats',
              ja: 'すべてのチャット',
              ko: '모든 채팅',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeBanner(bool dark, AppI18n i18n) {
    final isAll = _scope == _BackgroundScope.allChats;
    final title = isAll
        ? i18n.t(
            zhHans: '全部聊天 · 默认背景',
            zhHant: '全部聊天 · 預設背景',
            en: 'All chats · Default background',
            ja: 'すべてのチャット · デフォルト背景',
            ko: '모든 채팅 · 기본 배경',
          )
        : i18n.format(
            zhHans: '仅当前聊天 · {name}',
            zhHant: '僅目前聊天 · {name}',
            en: 'This chat only · {name}',
            ja: 'このチャットのみ · {name}',
            ko: '이 채팅만 · {name}',
            vars: {
              'name': widget.conversationName.trim().isEmpty
                  ? i18n.t(
                      zhHans: '对方',
                      zhHant: '對方',
                      en: 'Contact',
                      ja: '相手',
                      ko: '상대',
                    )
                  : widget.conversationName.trim(),
            },
          );
    final subtitle = isAll
        ? i18n.t(
            zhHans: '未单独设置背景的聊天都会使用这里的样式；单聊仍可覆盖。',
            zhHant: '未單獨設定背景的聊天都會使用這裡的樣式；單聊仍可覆蓋。',
            en: 'Chats without a custom background use this. Individual chats can still override it.',
            ja: '個別設定がないチャットはこれを使います。単一チャットで上書きもできます。',
            ko: '개별 배경이 없는 채팅은 이 설정을 씁니다. 단톡에서 덮어쓸 수 있습니다.',
          )
        : (_hasDirectOverride
            ? i18n.t(
                zhHans: '已为本聊天单独设置，优先于全局默认。',
                zhHant: '已為本聊天單獨設定，優先於全域預設。',
                en: 'Custom background for this chat (overrides the global default).',
                ja: 'このチャット専用の背景です（全体デフォルトより優先）。',
                ko: '이 채팅 전용 배경입니다(전체 기본보다 우선).',
              )
            : i18n.t(
                zhHans: '尚未单独设置，当前预览的是全局默认（或系统默认）。',
                zhHant: '尚未單獨設定，目前預覽的是全域預設（或系統預設）。',
                en: 'No custom background yet. Preview shows the global (or system) default.',
                ja: '個別設定はありません。プレビューは全体（またはシステム）デフォルトです。',
                ko: '개별 설정이 없습니다. 미리보기는 전체(또는 시스템) 기본입니다.',
              ));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF23262D) : const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? const Color(0xFF2A2D33) : const Color(0xFFD8E2F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAll ? Icons.public_rounded : Icons.chat_bubble_outline_rounded,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPreview(
    bool dark, {
    double? height = 168,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  }) {
    final i18n = AppI18n.of(context);
    final value = _previewValue;
    Widget bg;
    if (value == null || value.isEmpty) {
      bg = Container(
        color: dark ? const Color(0xFF111111) : const Color(0xFFF3F5F8),
      );
    } else if (value.startsWith(ChatBackgroundService.colorPrefix)) {
      final hex = value.substring(ChatBackgroundService.colorPrefix.length);
      final parsed = int.tryParse(hex, radix: 16);
      bg = Container(color: Color(parsed ?? 0xFFF3F5F8.toInt()));
    } else if (value.startsWith(ChatBackgroundService.assetPrefix)) {
      final assetPath =
          value.substring(ChatBackgroundService.assetPrefix.length);
      bg = Image.asset(assetPath, fit: BoxFit.cover);
    } else if (kIsWeb) {
      bg = Container(color: dark ? const Color(0xFF111111) : Colors.white);
    } else if (value.startsWith(ChatBackgroundService.filePrefix)) {
      bg = buildChatBackgroundPreviewImage(
        value.substring(ChatBackgroundService.filePrefix.length),
      );
    } else {
      bg = buildChatBackgroundPreviewImage(value);
    }

    final badge = _scope == _BackgroundScope.allChats
        ? i18n.t(
            zhHans: '全局默认预览',
            zhHant: '全域預設預覽',
            en: 'Global default preview',
            ja: '全体デフォルトのプレビュー',
            ko: '전체 기본 미리보기',
          )
        : (_hasDirectOverride
            ? i18n.t(
                zhHans: '本聊天专属预览',
                zhHant: '本聊天專屬預覽',
                en: 'This chat preview',
                ja: 'このチャット専用プレビュー',
                ko: '이 채팅 전용 미리보기',
              )
            : i18n.t(
                zhHans: '继承全局默认',
                zhHant: '繼承全域預設',
                en: 'Using global default',
                ja: '全体デフォルトを継承',
                ko: '전체 기본 사용 중',
              ));

    return Container(
      width: double.infinity,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line(dark: dark), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          bg,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.14),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 44,
            child: _previewBubble(
              i18n.t(
                zhHans: '你好，今晚见面聊',
                zhHant: '你好，今晚見面聊',
                en: 'Hi, let’s talk tonight.',
                ja: 'こんにちは。今夜話そう。',
                ko: '안녕, 오늘 밤 이야기하자.',
              ),
              self: true,
              dark: dark,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _previewBubble(
              i18n.t(
                zhHans: '这里会显示当前聊天背景效果',
                zhHant: '這裡會顯示目前聊天背景效果',
                en: 'Preview of the chat background.',
                ja: 'チャット背景のプレビューです。',
                ko: '채팅 배경 미리보기입니다.',
              ),
              self: false,
              dark: dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBubble(String text, {required bool self, required bool dark}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: self
            ? const Color(0xFF2D8CFF)
            : (dark ? const Color(0xFF23262B) : Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: self ? Colors.white : AppColors.text(dark: dark),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _recommendedPlaceholder(_RecommendedBackground item) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required bool dark,
    required String title,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: AppColors.background(dark: dark),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.subText(dark: dark),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptionChildren({
    required bool dark,
    required AppI18n i18n,
    required String clearTitle,
    required bool includePreview,
  }) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [
      _buildScopeSwitcher(dark, i18n),
      _buildScopeBanner(dark, i18n),
      if (includePreview) ...[
        _buildBackgroundPreview(dark),
        const SizedBox(height: 12),
      ],
      SettingsGroup(
        margin: EdgeInsets.zero,
        children: [
          SettingsCell(
            title: kIsWeb
                ? i18n.t(
                    zhHans: '选择图片',
                    zhHant: '選擇圖片',
                    en: 'Choose Image',
                    ja: '画像を選択',
                    ko: '이미지 선택',
                  )
                : i18n.t(
                    zhHans: '从手机相册选择',
                    zhHant: '從手機相簿選擇',
                    en: 'Choose from Photos',
                    ja: '端末の写真から選択',
                    ko: '휴대폰 앨범에서 선택',
                  ),
            onTap: _saving ? null : _pickBackground,
          ),
          SettingsCell(
            title: clearTitle,
            showDivider: false,
            onTap: (_saving || !_hasEditableValue) ? null : _clearBackground,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildSectionHeader(
        dark: dark,
        title: i18n.t(
          zhHans: '选择一个颜色',
          zhHant: '選擇一個顏色',
          en: 'Choose a Color',
          ja: '色を選択',
          ko: '색상 선택',
        ),
        expanded: _colorsExpanded,
        onTap: () {
          setState(() {
            _colorsExpanded = !_colorsExpanded;
          });
        },
      ),
      if (_colorsExpanded)
        Container(
          width: double.infinity,
          color: AppColors.card(dark: dark),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _colorOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final color = _colorOptions[index];
              return GestureDetector(
                onTap: _saving ? null : () => _selectColor(color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.line(dark: dark),
                      width: 0.6,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 12),
      _buildSectionHeader(
        dark: dark,
        title: i18n.t(
          zhHans: '推荐背景',
          zhHant: '推薦背景',
          en: 'Recommended Backgrounds',
          ja: 'おすすめ背景',
          ko: '추천 배경',
        ),
        expanded: _recommendedExpanded,
        onTap: () {
          setState(() {
            _recommendedExpanded = !_recommendedExpanded;
          });
        },
      ),
      if (_recommendedExpanded)
        Container(
          width: double.infinity,
          color: AppColors.card(dark: dark),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recommendedOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final item = _recommendedOptions[index];
              return GestureDetector(
                onTap: _saving ? null : () => _selectAsset(item.assetPath),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.assetPath.isNotEmpty
                            ? Image.asset(
                                item.assetPath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    _recommendedPlaceholder(item),
                              )
                            : _recommendedPlaceholder(item),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title.label(context),
                      style: TextStyle(
                        color: AppColors.subText(dark: dark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    ];
  }

  Widget _buildDesktopDualPane({
    required bool dark,
    required AppI18n i18n,
    required String pageTitle,
    required String clearTitle,
  }) {
    final divider = AppColors.line(dark: dark);
    final options = _buildOptionChildren(
      dark: dark,
      i18n: i18n,
      clearTitle: clearTitle,
      includePreview: false,
    );
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: options,
          ),
        ),
        VerticalDivider(width: 1, thickness: 0.6, color: divider),
        Expanded(
          flex: 4,
          child: ColoredBox(
            color: AppColors.background(dark: dark),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i18n.t(
                      zhHans: '实时预览',
                      zhHant: '即時預覽',
                      en: 'Live Preview',
                      ja: 'ライブプレビュー',
                      ko: '실시간 미리보기',
                    ),
                    style: TextStyle(
                      color: AppColors.text(dark: dark),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildBackgroundPreview(
                      dark,
                      height: null,
                      margin: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(
        color: AppColors.background(dark: dark),
        child: body,
      );
    }

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
          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          pageTitle,
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);
    final pageTitle = _isGlobalOnlyEntry
        ? i18n.t(
            zhHans: '全局聊天背景',
            zhHant: '全域聊天背景',
            en: 'Global Chat Background',
            ja: '全体チャット背景',
            ko: '전체 채팅 배경',
          )
        : i18n.t(
            zhHans: '聊天背景',
            zhHant: '聊天背景',
            en: 'Chat Background',
            ja: 'チャット背景',
            ko: '채팅 배경',
          );

    final clearTitle = _scope == _BackgroundScope.allChats
        ? i18n.t(
            zhHans: '清除全局默认背景',
            zhHant: '清除全域預設背景',
            en: 'Clear Global Default',
            ja: '全体デフォルトを削除',
            ko: '전체 기본 배경 지우기',
          )
        : i18n.t(
            zhHans: '清除本聊天背景',
            zhHant: '清除本聊天背景',
            en: 'Clear This Chat Background',
            ja: 'このチャットの背景を削除',
            ko: '이 채팅 배경 지우기',
          );

    final useDualPane = DesktopModalLayout.isDesktop(context);
    if (useDualPane) {
      return _buildDesktopDualPane(
        dark: dark,
        i18n: i18n,
        pageTitle: pageTitle,
        clearTitle: clearTitle,
      );
    }

    if (widget.embedded) {
      return Material(
        color: AppColors.background(dark: dark),
        child: ListView(
          children: _buildOptionChildren(
            dark: dark,
            i18n: i18n,
            clearTitle: clearTitle,
            includePreview: true,
          ),
        ),
      );
    }

    return SettingsScaffold(
      title: pageTitle,
      onLeadingPressed: widget.onClose,
      children: _buildOptionChildren(
        dark: dark,
        i18n: i18n,
        clearTitle: clearTitle,
        includePreview: true,
      ),
    );
  }
}

class _RecommendedBackground {
  const _RecommendedBackground({
    required this.title,
    this.assetPath = '',
  });

  final _BackgroundLabel title;
  final String assetPath;

  List<Color> get colors {
    switch (title) {
      case _BackgroundLabel.beauty:
        return const [Color(0xFFF6D4D8), Color(0xFFE8B2C0)];
      case _BackgroundLabel.scenery:
        return const [Color(0xFFD6EEF4), Color(0xFFA8D4E8)];
      case _BackgroundLabel.car:
        return const [Color(0xFFE7EAF1), Color(0xFFBDC6D6)];
    }
  }
}

enum _BackgroundLabel {
  beauty,
  scenery,
  car;

  String label(BuildContext context) {
    final i18n = AppI18n.of(context);
    switch (this) {
      case _BackgroundLabel.beauty:
        return i18n.t(
          zhHans: '人物',
          zhHant: '人物',
          en: 'Portrait',
          ja: '人物',
          ko: '인물',
        );
      case _BackgroundLabel.scenery:
        return i18n.t(
          zhHans: '风景',
          zhHant: '風景',
          en: 'Scenery',
          ja: '風景',
          ko: '풍경',
        );
      case _BackgroundLabel.car:
        return i18n.t(
          zhHans: '汽车',
          zhHant: '汽車',
          en: 'Car',
          ja: '車',
          ko: '자동차',
        );
    }
  }
}
