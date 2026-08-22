import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_file_access.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_width.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class FontSizePage extends StatefulWidget {
  const FontSizePage({super.key});

  static const List<double> presets = <double>[0.9, 1.0, 1.12, 1.24];

  static String labelForScale(double scale) {
    final index = _nearestPresetIndex(scale);
    final i18n = AppI18n.current;
    switch (index) {
      case 0:
        return i18n.t(
          zhHans: '小',
          zhHant: '小',
          en: 'Small',
          ja: '小',
          ko: '작게',
        );
      case 1:
        return i18n.t(
          zhHans: '标准',
          zhHant: '標準',
          en: 'Default',
          ja: '標準',
          ko: '기본',
        );
      case 2:
        return i18n.t(
          zhHans: '较大',
          zhHant: '較大',
          en: 'Large',
          ja: 'やや大きい',
          ko: '크게',
        );
      default:
        return i18n.t(
          zhHans: '超大',
          zhHant: '超大',
          en: 'Extra Large',
          ja: '最大',
          ko: '매우 크게',
        );
    }
  }

  static int _nearestPresetIndex(double scale) {
    var bestIndex = 0;
    var bestDistance = (presets.first - scale).abs();
    for (var i = 1; i < presets.length; i++) {
      final distance = (presets[i] - scale).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  State<FontSizePage> createState() => _FontSizePageState();
}

class _FontSizePageState extends State<FontSizePage> {
  String? _backgroundPath;

  static const List<_PreviewMessage> _messages = <_PreviewMessage>[
    _PreviewMessage(
      textKey: _PreviewText.hotpotAsk,
      isMine: false,
      time: '10:24',
    ),
    _PreviewMessage(
      textKey: _PreviewText.hotpotReply,
      isMine: true,
      time: '10:25',
    ),
    _PreviewMessage(
      textKey: _PreviewText.hotpotConfirm,
      isMine: false,
      time: '10:26',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    final path = await ChatBackgroundService.instance.getBackgroundPath(
      ChatBackgroundService.globalBackgroundConversationId,
    );
    if (!mounted) return;
    setState(() => _backgroundPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final localSetting = Provider.of<LocalSetting>(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final scale = localSetting.chatFontScale;
    final selectedIndex = FontSizePage._nearestPresetIndex(scale).toDouble();
    final i18n = AppI18n.of(context);
    final previewName = i18n.t(
      zhHans: '小美',
      zhHant: '小美',
      en: 'Amy',
      ja: 'エイミー',
      ko: '에이미',
    );

    return Scaffold(
      backgroundColor: theme.chatBgColor,
      body: Column(
        children: [
          _unscaled(
            context,
            _ChatPreviewNavBar(
              theme: theme,
              previewName: previewName,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildChatBackground(theme),
                _unscaled(
                  context,
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      padding: EdgeInsets.zero,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final messageIndex = _messages.length - 1 - index;
                        final message = _messages[messageIndex];
                        return _ChatPreviewMessageRow(
                          theme: theme,
                          text: _previewText(i18n, message.textKey),
                          isMine: message.isMine,
                          time: message.time,
                          peerName: previewName,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          _unscaled(
            context,
            _FontSizeSliderPanel(
              theme: theme,
              scale: scale,
              selectedIndex: selectedIndex,
              onScaleChanged: (value) {
                localSetting.chatFontScale =
                    FontSizePage.presets[value.round()];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBackground(TUITheme theme) {
    final value = _backgroundPath;
    if (value == null || value.isEmpty) {
      return ColoredBox(color: theme.chatBgColor ?? Colors.white);
    }
    if (value.startsWith(ChatBackgroundService.colorPrefix)) {
      final hex = value.substring(ChatBackgroundService.colorPrefix.length);
      final parsed = int.tryParse(hex, radix: 16);
      return ColoredBox(
        color: Color(parsed ?? 0xFFF3F5F8),
      );
    }
    if (value.startsWith(ChatBackgroundService.assetPrefix)) {
      final assetPath =
          value.substring(ChatBackgroundService.assetPrefix.length);
      return Image.asset(assetPath, fit: BoxFit.cover);
    }
    if (kIsWeb) {
      return ColoredBox(color: theme.chatBgColor ?? Colors.white);
    }
    if (value.startsWith(ChatBackgroundService.filePrefix)) {
      return buildChatBackgroundPreviewImage(
        value.substring(ChatBackgroundService.filePrefix.length),
      );
    }
    return buildChatBackgroundPreviewImage(value);
  }

  static Widget _unscaled(BuildContext context, Widget child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.0),
      ),
      child: child,
    );
  }

  static String _previewText(AppI18n i18n, _PreviewText key) {
    switch (key) {
      case _PreviewText.hotpotAsk:
        return i18n.t(
          zhHans: '今天下班一起去吃火锅吗？',
          zhHant: '今天下班一起去吃火鍋嗎？',
          en: 'Want to grab hot pot after work today?',
          ja: '今日、仕事の後に火鍋を食べに行かない？',
          ko: '오늘 퇴근하고 훠궈 먹으러 갈래?',
        );
      case _PreviewText.hotpotReply:
        return i18n.t(
          zhHans: '好呀，我先订位置，到了给你发消息。',
          zhHant: '好呀，我先訂位，到了再發訊息給你。',
          en: 'Sure. I’ll book a table first and message you when I arrive.',
          ja: 'いいね。先に席を取っておくね。着いたら連絡するよ。',
          ko: '좋아. 내가 먼저 자리 잡아둘게. 도착하면 메시지할게.',
        );
      case _PreviewText.hotpotConfirm:
        return i18n.t(
          zhHans: '没问题，那我六点半出发。',
          zhHant: '沒問題，那我六點半出發。',
          en: 'Sounds good. I’ll head out at 6:30.',
          ja: '了解。じゃあ6時半に出発するね。',
          ko: '좋아. 그럼 6시 30분에 출발할게.',
        );
    }
  }
}

class _ChatPreviewNavBar extends StatelessWidget {
  final TUITheme theme;
  final String previewName;
  final VoidCallback onBack;

  const _ChatPreviewNavBar({
    required this.theme,
    required this.previewName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final headerBg = theme.chatHeaderBgColor ??
        theme.appbarBgColor ??
        theme.chatBgColor ??
        Colors.white;
    final titleColor = theme.chatHeaderTitleTextColor ??
        theme.appbarTextColor ??
        Colors.black;
    final backColor =
        theme.chatHeaderBackTextColor ?? theme.primaryColor ?? const Color(0xFF1E90FF);
    final weakTextColor = theme.weakTextColor ?? const Color(0xFF8E8E93);
    final actionColor = theme.primaryColor ?? const Color(0xFF1E90FF);

    return Material(
      color: headerBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(
                color: theme.weakDividerColor ?? const Color(0xFFE5E5EA),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_ios, color: backColor, size: 20),
              ),
              AppAvatarHeader(
                previewName: previewName,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i18n.t(
                        zhHans: '在线',
                        zhHant: '在線',
                        en: 'Online',
                        ja: 'オンライン',
                        ko: '온라인',
                      ),
                      style: TextStyle(
                        color: weakTextColor,
                        fontSize: 12,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Image.asset(
                  'assets/img/call.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  color: actionColor,
                  colorBlendMode: BlendMode.srcIn,
                  gaplessPlayback: true,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.videocam_outlined, color: actionColor, size: 24),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_horiz_rounded, color: actionColor, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeSliderPanel extends StatelessWidget {
  final TUITheme theme;
  final double scale;
  final double selectedIndex;
  final ValueChanged<double> onScaleChanged;

  const _FontSizeSliderPanel({
    required this.theme,
    required this.scale,
    required this.selectedIndex,
    required this.onScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    final panelBg = theme.conversationItemBgColor ??
        theme.chatHeaderBgColor ??
        theme.appbarBgColor ??
        Colors.white;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5EA);
    final helperColor = theme.weakTextColor ?? const Color(0xFF8E8E93);
    final titleColor = theme.darkTextColor ?? Colors.black;
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          top: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                i18n.t(
                  zhHans: '当前',
                  zhHant: '目前',
                  en: 'Current',
                  ja: '現在',
                  ko: '현재',
                ),
                style: TextStyle(color: helperColor, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                FontSizePage.labelForScale(scale),
                style: TextStyle(
                  color: titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: dividerColor,
              thumbColor: primaryColor,
              overlayColor: primaryColor.withValues(alpha: 0.14),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: selectedIndex,
              divisions: FontSizePage.presets.length - 1,
              min: 0,
              max: (FontSizePage.presets.length - 1).toDouble(),
              onChanged: onScaleChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: List.generate(FontSizePage.presets.length, (index) {
                final selected = index == selectedIndex.round();
                return Expanded(
                  child: Align(
                    alignment: index == 0
                        ? Alignment.centerLeft
                        : index == FontSizePage.presets.length - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                    child: Text(
                      FontSizePage.labelForScale(FontSizePage.presets[index]),
                      style: TextStyle(
                        color: selected ? titleColor : helperColor,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PreviewText { hotpotAsk, hotpotReply, hotpotConfirm }

class AppAvatarHeader extends StatelessWidget {
  final String previewName;

  const AppAvatarHeader({super.key, required this.previewName});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Avatar(
        faceUrl: '',
        showName: previewName,
        type: 1,
        borderRadius: BorderRadius.circular(999),
        onlineStatus: V2TimUserStatus(
          userID: 'font_size_preview',
          statusType: 1,
        ),
      ),
    );
  }
}

class _ChatPreviewMessageRow extends StatelessWidget {
  final TUITheme theme;
  final String text;
  final bool isMine;
  final String time;
  final String peerName;

  const _ChatPreviewMessageRow({
    required this.theme,
    required this.text,
    required this.isMine,
    required this.time,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = _ChatPreviewTextBubble(
      theme: theme,
      text: text,
      isMine: isMine,
      time: time,
    );

    return Container(
      padding: EdgeInsets.only(left: isMine ? 0 : 16, right: isMine ? 16 : 0),
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMine)
                  AppUserAvatar(
                    faceUrl: '',
                    showName: peerName,
                    size: 40,
                  ),
                Container(
                  margin: isMine ? null : const EdgeInsets.only(left: 13),
                  child: bubble,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPreviewTextBubble extends StatelessWidget {
  final TUITheme theme;
  final String text;
  final bool isMine;
  final String time;

  const _ChatPreviewTextBubble({
    required this.theme,
    required this.text,
    required this.isMine,
    required this.time,
  });

  bool _shouldPlaceMetaOnNewLine(
    BuildContext context,
    TextStyle textStyle,
    TextStyle metaStyle,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final maxBubbleWidth = chatMessageMaxWidth(context);
    const horizontalPadding = 20.0;
    const inlineMetaGap = 6.0;
    final contentMaxWidth = maxBubbleWidth - horizontalPadding;

    final metaPainter = TextPainter(
      text: TextSpan(text: time, style: metaStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout();
    final inlineMetaWidth = metaPainter.width;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: null,
    )..layout(maxWidth: contentMaxWidth);

    if (textPainter.computeLineMetrics().length > 1) {
      return true;
    }

    // 留一点余量，避免测量误差在放大字体时把行尾时间挤出气泡。
    final safetyMargin = 4.0 * textScaler.scale(1.0);
    return textPainter.size.width + inlineMetaGap + inlineMetaWidth >
        contentMaxWidth - safetyMargin;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isMine
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ?? Colors.white);
    final bubbleColor = backgroundColor;
    const bodyFontSize = 16.0;
    const compactTextHeight = 1.20;
    final textStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontSize: bodyFontSize,
      lineHeight: compactTextHeight,
    );
    final metaStyle = TextStyle(
      fontSize: 11,
      height: 1,
      color: MessageBubbleTextColor.metaText(
        theme: theme,
        backgroundColor: bubbleColor,
      ),
    );
    final borderRadius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          );
    final shouldPlaceMetaOnNewLine = _shouldPlaceMetaOnNewLine(
      context,
      textStyle,
      metaStyle,
    );
    final textWidget = Text(text, softWrap: true, style: textStyle);
    final metaWidget = Text(time, style: metaStyle);

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        constraints: BoxConstraints(
          maxWidth: chatMessageMaxWidth(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            shouldPlaceMetaOnNewLine
                ? textWidget
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(child: textWidget),
                      const SizedBox(width: 6),
                      metaWidget,
                    ],
                  ),
            if (shouldPlaceMetaOnNewLine)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: metaWidget,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMessage {
  final _PreviewText textKey;
  final bool isMine;
  final String time;

  const _PreviewMessage({
    required this.textKey,
    required this.isMine,
    required this.time,
  });
}
