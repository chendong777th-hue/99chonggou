import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

const String _appDialogBgAsset = 'assets/img/up_window.webp';
const double _appDialogBgAspectRatio = 1536 / 1024;

/// 是否使用带背景图的旧版弹窗样式。保留实现，默认关闭。
const bool _useLegacyImageDialog = false;

class AppDialog {
  AppDialog._();

  static bool _showing = false;

  static bool get isShowing => _showing;

  static BuildContext? get _context => AppNavigator.context;

  static Future<T?> show<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    bool closeCurrent = false,
  }) async {
    final context = _context;
    if (context == null) return null;

    if (_showing) {
      if (!closeCurrent) return null;
      dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    _showing = true;
    HapticFeedback.selectionClick();

    try {
      return await showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: barrierDismissible,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: kImmersiveModalBarrierColor,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _DialogRouteBody(child: builder(dialogContext));
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curve),
              child: child,
            ),
          );
        },
      );
    } finally {
      _showing = false;
    }
  }

  static Future<T?> _showCupertino<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    bool closeCurrent = false,
  }) async {
    final context = _context;
    if (context == null) return null;

    if (_showing) {
      if (!closeCurrent) return null;
      dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    _showing = true;
    HapticFeedback.selectionClick();

    try {
      return await showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        useRootNavigator: true,
        builder: builder,
      );
    } finally {
      _showing = false;
    }
  }

  static Future<bool> confirm({
    required String title,
    required String message,
    String cancelText = '取消',
    String confirmText = '确定',
    bool destructive = false,
    bool barrierDismissible = false,
  }) async {
    if (_useLegacyImageDialog) {
      final result = await show<bool>(
        barrierDismissible: barrierDismissible,
        closeCurrent: true,
        builder: (_) => _LegacyImageConfirmDialog(
          title: title,
          message: message,
          cancelText: cancelText,
          confirmText: confirmText,
          destructive: destructive,
        ),
      );
      return result == true;
    }

    final result = await _showCupertino<bool>(
      barrierDismissible: barrierDismissible,
      closeCurrent: true,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        destructive: destructive,
      ),
    );
    return result == true;
  }

  static Future<void> alert({
    required String title,
    required String message,
    String buttonText = '知道了',
    bool barrierDismissible = true,
  }) async {
    if (_useLegacyImageDialog) {
      await show<void>(
        barrierDismissible: barrierDismissible,
        closeCurrent: true,
        builder: (_) => _LegacyImageConfirmDialog(
          title: title,
          message: message,
          confirmText: buttonText,
          showCancel: false,
        ),
      );
      return;
    }

    await _showCupertino<void>(
      barrierDismissible: barrierDismissible,
      closeCurrent: true,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        showCancel: false,
      ),
    );
  }

  /// 通用单行输入弹窗（Cupertino，与 [confirm] / 分组命名同风格）。
  ///
  /// 取消或空白确认返回 `null`；确认返回 trim 后的文本。
  static Future<String?> prompt({
    required String title,
    String? message,
    String? placeholder,
    String initialValue = '',
    String cancelText = '取消',
    String confirmText = '确定',
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool barrierDismissible = true,
    bool allowEmpty = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final result = await _showCupertino<String>(
        barrierDismissible: barrierDismissible,
        closeCurrent: true,
        builder: (_) => AppPromptDialog(
          title: title,
          message: message,
          placeholder: placeholder,
          controller: controller,
          cancelText: cancelText,
          confirmText: confirmText,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          allowEmpty: allowEmpty,
        ),
      );
      final text = result?.trim() ?? '';
      if (text.isEmpty && !allowEmpty) {
        return null;
      }
      return result == null ? null : text;
    } finally {
      controller.dispose();
    }
  }

  static bool _useDesktopActionSheet(BuildContext context) {
    return kIsWeb ||
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  }

  static Future<T?> actionSheet<T>({
    required String title,
    String? message,
    required List<AppActionSheetItem<T>> actions,
    String cancelText = '取消',
    double? actionContentWidth,
  }) async {
    final context = _context;
    if (context == null) return null;
    HapticFeedback.selectionClick();

    if (_showing) {
      dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (_useDesktopActionSheet(context)) {
      return showDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierColor: kImmersiveModalBarrierColor,
        builder: (dialogContext) => _DesktopActionSheetDialog<T>(
          title: title,
          message: message,
          actions: actions,
          cancelText: cancelText,
          actionContentWidth: actionContentWidth,
        ),
      );
    }

    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: title.trim().isEmpty
              ? null
              : Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          message: message != null && message.isNotEmpty
              ? Text(
                  message,
                  style: const TextStyle(fontSize: 13),
                )
              : null,
          actions: [
            for (final item in actions)
              CupertinoActionSheetAction(
                isDestructiveAction: item.destructive,
                onPressed: item.enabled
                    ? () => Navigator.of(sheetContext).pop<T>(item.value)
                    : () {},
                child: item.icon == null
                    ? _ActionSheetLabel(
                        text: item.text,
                        subtitle: item.subtitle,
                        enabled: item.enabled,
                      )
                    : Center(
                        child: SizedBox(
                          width: actionContentWidth,
                          child: Row(
                            mainAxisAlignment: actionContentWidth == null
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            mainAxisSize: actionContentWidth == null
                                ? MainAxisSize.min
                                : MainAxisSize.max,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Center(
                                  child: Icon(
                                    item.icon,
                                    size: 22,
                                    color: item.enabled
                                        ? item.iconColor ??
                                            CupertinoColors.activeBlue
                                        : CupertinoColors.systemGrey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.text,
                                style: item.enabled
                                    ? null
                                    : const TextStyle(
                                        color: CupertinoColors.systemGrey,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelText),
          ),
        );
      },
    );
  }

  static Future<void> showLoading({String text = '加载中...'}) async {
    await show<void>(
      barrierDismissible: false,
      closeCurrent: true,
      builder: (_) => _LoadingDialog(text: text),
    );
  }

  static void hideLoading() {
    dismiss();
  }

  static OverlayEntry? _noticeEntry;
  static Timer? _noticeTimer;

  static bool showNotice({
    String? title,
    required String message,
    String? actionText,
    FutureOr<void> Function()? onTap,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final overlay = AppNavigator.overlay;
    if (overlay == null) return false;

    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    _noticeEntry = null;

    HapticFeedback.selectionClick();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NoticeOverlay(
        title: title,
        message: message,
        actionText: actionText,
        onTap: onTap == null
            ? null
            : () async {
                hideNotice();
                try {
                  await Future.sync(onTap).timeout(
                    const Duration(seconds: 3),
                    onTimeout: () {},
                  );
                } catch (_) {
                  // Notice taps must never block UI or keep the overlay alive.
                }
              },
        onDismiss: hideNotice,
      ),
    );

    _noticeEntry = entry;
    overlay.insert(entry);
    _noticeTimer = Timer(duration, hideNotice);
    return true;
  }

  static void hideNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _noticeEntry?.remove();
    _noticeEntry = null;
  }

  static void dismiss<T>([T? result]) {
    final state = AppNavigator.key.currentState;
    if (state == null) return;
    if (!state.canPop()) return;
    state.pop<T>(result);
  }
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.destructive = false,
    this.showCancel = true,
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool destructive;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    final titleText = title.trim();
    final messageText = message.trim();
    final navigator = Navigator.of(context, rootNavigator: true);

    return CupertinoAlertDialog(
      title: titleText.isEmpty ? null : Text(titleText),
      content: messageText.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.only(top: titleText.isEmpty ? 0 : 8),
              child: Text(
                messageText,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
      actions: showCancel
          ? [
              CupertinoDialogAction(
                onPressed: () => navigator.pop(false),
                child: Text(cancelText),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                isDefaultAction: !destructive,
                onPressed: () => navigator.pop(true),
                child: Text(confirmText),
              ),
            ]
          : [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => navigator.pop(),
                child: Text(confirmText),
              ),
            ],
    );
  }
}

class AppPromptDialog extends StatelessWidget {
  const AppPromptDialog({
    super.key,
    required this.title,
    required this.controller,
    this.message,
    this.placeholder,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.allowEmpty = false,
  });

  final String title;
  final String? message;
  final String? placeholder;
  final TextEditingController controller;
  final String cancelText;
  final String confirmText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    final titleText = title.trim();
    final messageText = message?.trim() ?? '';
    final placeholderText = placeholder?.trim() ?? '';
    final navigator = Navigator.of(context, rootNavigator: true);

    return CupertinoAlertDialog(
      title: titleText.isEmpty ? null : Text(titleText),
      content: Padding(
        padding: EdgeInsets.only(top: titleText.isEmpty ? 0 : 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (messageText.isNotEmpty) ...[
              Text(
                messageText,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              placeholder: placeholderText.isEmpty ? null : placeholderText,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => navigator.pop(),
          child: Text(cancelText),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty && !allowEmpty) {
              return;
            }
            navigator.pop(text);
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class _LegacyImageConfirmDialog extends StatelessWidget {
  const _LegacyImageConfirmDialog({
    required this.title,
    required this.message,
    this.cancelText = '取消',
    this.confirmText = '确定',
    this.destructive = false,
    this.showCancel = true,
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool destructive;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mainColor =
        destructive ? AppColors.primaryRed : AppColors.primaryBlue;
    final buttonWidth = context.isDesktopFormFactor ? 140.0 : 124.0;

    final actions = showCancel
        ? Row(
            children: [
              Expanded(
                child: _DialogButton(
                  text: cancelText,
                  filled: false,
                  color: mainColor,
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DialogButton(
                  text: confirmText,
                  filled: true,
                  color: mainColor,
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).pop(true),
                ),
              ),
            ],
          )
        : Center(
            child: SizedBox(
              width: buttonWidth,
              child: _DialogButton(
                text: confirmText,
                filled: true,
                color: mainColor,
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ),
          );

    return _ImageDialogCard(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          actions,
        ],
      ),
    );
  }
}

class _ImageDialogCard extends StatelessWidget {
  const _ImageDialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth * 0.88;
    final radius = cardWidth * 0.070;
    final cardHeight = cardWidth / _appDialogBgAspectRatio;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: cardWidth * 0.10,
              spreadRadius: cardWidth * 0.006,
              offset: Offset(0, cardWidth * 0.052),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: cardWidth * 0.024,
              offset: Offset(0, cardWidth * 0.009),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _appDialogBgAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  cardWidth * 0.08,
                  cardWidth * 0.17,
                  cardWidth * 0.08,
                  cardWidth * 0.08,
                ),
                child: child,
              ),
              Positioned(
                right: cardWidth * 0.026,
                top: cardWidth * 0.046,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  child: Padding(
                    padding: EdgeInsets.all(cardWidth * 0.026),
                    child: Icon(
                      Icons.close_rounded,
                      color: const Color(0xFF0D1B3D),
                      size: cardWidth * 0.062,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSheetLabel extends StatelessWidget {
  const _ActionSheetLabel({
    required this.text,
    required this.enabled,
    this.subtitle,
  });

  final String text;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final disabledStyle = TextStyle(
      color: CupertinoColors.systemGrey.resolveFrom(context),
    );
    final subtitleText = subtitle?.trim() ?? '';
    if (subtitleText.isEmpty) {
      return Text(
        text,
        style: enabled ? null : disabledStyle,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: enabled ? null : disabledStyle,
        ),
        const SizedBox(height: 2),
        Text(
          subtitleText,
          style: TextStyle(
            fontSize: 12,
            color: enabled
                ? CupertinoColors.secondaryLabel.resolveFrom(context)
                : CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

/// Web / 桌面：居中选项对话框，替代底部 CupertinoActionSheet。
class _DesktopActionSheetDialog<T> extends StatelessWidget {
  const _DesktopActionSheetDialog({
    required this.title,
    required this.actions,
    required this.cancelText,
    this.message,
    this.actionContentWidth,
  });

  final String title;
  final String? message;
  final List<AppActionSheetItem<T>> actions;
  final String cancelText;
  final double? actionContentWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleText = title.trim();
    final messageText = message?.trim() ?? '';
    final surface = AppColors.card(dark: dark);
    final textColor = AppColors.text(dark: dark);
    final subColor = AppColors.subText(dark: dark);
    final line = AppColors.line(dark: dark);
    final accent = AppColors.primaryBlue;
    final danger = AppColors.primaryRed;
    final textScale = AppResponsive.textScale(context);
    final maxHeight = (MediaQuery.sizeOf(context).height *
            (0.55 + math.max(0.0, textScale - 1.0) * 0.08))
        .clamp(320.0, MediaQuery.sizeOf(context).height * 0.82)
        .toDouble();

    return Dialog(
      backgroundColor: surface,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titleText.isNotEmpty || messageText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titleText.isNotEmpty)
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    if (messageText.isNotEmpty) ...[
                      SizedBox(height: titleText.isEmpty ? 0 : 6),
                      Text(
                        messageText,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: subColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0 ||
                          titleText.isNotEmpty ||
                          messageText.isNotEmpty)
                        Divider(height: 1, thickness: 0.6, color: line),
                      _DesktopActionSheetTile<T>(
                        item: actions[i],
                        actionContentWidth: actionContentWidth,
                        textColor: textColor,
                        subColor: subColor,
                        accent: accent,
                        danger: danger,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.6, color: line),
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: SizedBox(
                height: AppResponsive.dialogButtonHeight(context),
                child: Center(
                  child: Text(
                    cancelText,
                    style: TextStyle(
                      fontSize: AppResponsive.dialogButtonFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopActionSheetTile<T> extends StatelessWidget {
  const _DesktopActionSheetTile({
    required this.item,
    required this.textColor,
    required this.subColor,
    required this.accent,
    required this.danger,
    this.actionContentWidth,
  });

  final AppActionSheetItem<T> item;
  final Color textColor;
  final Color subColor;
  final Color accent;
  final Color danger;
  final double? actionContentWidth;

  @override
  Widget build(BuildContext context) {
    // callers 用 enabled:false 表示「当前已选项」；桌面侧显示勾选而非灰掉不可点。
    final isCurrent = !item.enabled;
    final labelColor =
        item.destructive ? danger : (isCurrent ? accent : textColor);
    final subtitle = item.subtitle?.trim() ?? '';

    return InkWell(
      onTap: () => Navigator.of(context).pop<T>(item.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 20,
                color: item.enabled ? (item.iconColor ?? accent) : subColor,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Align(
                alignment: actionContentWidth == null
                    ? Alignment.centerLeft
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: actionContentWidth ?? double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: subColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (isCurrent) Icon(Icons.check_rounded, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}

class AppActionSheetItem<T> {
  const AppActionSheetItem({
    required this.text,
    required this.value,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.icon,
    this.iconColor,
  });

  final String text;
  final String? subtitle;
  final T value;
  final bool destructive;
  final bool enabled;
  final IconData? icon;
  final Color? iconColor;
}

class _NoticeOverlay extends StatefulWidget {
  const _NoticeOverlay({
    required this.message,
    required this.onDismiss,
    this.title,
    this.actionText,
    this.onTap,
  });

  final String? title;
  final String message;
  final String? actionText;
  final FutureOr<void> Function()? onTap;
  final VoidCallback onDismiss;

  @override
  State<_NoticeOverlay> createState() => _NoticeOverlayState();
}

class _NoticeOverlayState extends State<_NoticeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _handlingTap = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curve;
    _scale = Tween<double>(begin: 0.96, end: 1).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_handlingTap) return;
    _handlingTap = true;
    try {
      if (widget.onTap != null) {
        final onTap = widget.onTap;
        if (onTap != null) {
          await Future<void>.sync(() => onTap()).timeout(
            const Duration(seconds: 3),
            onTimeout: () {},
          );
        }
      } else {
        await _dismiss();
      }
    } finally {
      _handlingTap = false;
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim() ?? '';
    final action = widget.actionText?.trim() ?? '';
    final isCompactToast = title.isEmpty && action.isEmpty;

    Widget content;
    if (isCompactToast) {
      content = _CompactToastBubble(
        message: widget.message,
        onTap: widget.onTap == null ? () => _dismiss() : () => _tap(),
      );
    } else {
      content = _RichNoticeBubble(
        title: title,
        message: widget.message,
        actionText: action,
        onTap: () => _tap(),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: Colors.transparent,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactToastBubble extends StatelessWidget {
  const _CompactToastBubble({
    required this.message,
    required this.onTap,
  });

  final String message;
  final VoidCallback onTap;

  static const Color _background = Color(0xFF4C4C4C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _background.withOpacity(0.94),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _RichNoticeBubble extends StatelessWidget {
  const _RichNoticeBubble({
    required this.title,
    required this.message,
    required this.actionText,
    required this.onTap,
  });

  final String title;
  final String message;
  final String actionText;
  final VoidCallback onTap;

  static const Color _background = Color(0xFF4C4C4C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _background.withOpacity(0.94),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  decoration: TextDecoration.none,
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(title.isEmpty ? 1 : 0.88),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
            if (actionText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                actionText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8EB5FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRouteBody extends StatelessWidget {
  const _DialogRouteBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final edgeInsets = AppResponsive.modalEdgeInsets(context) as EdgeInsets;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            edgeInsets.left,
            edgeInsets.top,
            edgeInsets.right,
            edgeInsets.bottom + viewInsets.bottom,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth = AppResponsive.modalCardMaxWidth(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card(dark: dark),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line(dark: dark), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.36 : 0.14),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: child,
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.text,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  final String text;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = filled ? Colors.white : AppColors.text(dark: dark);
    final bgColor = filled
        ? color
        : (dark ? const Color(0xFF262A31) : const Color(0xFFF2F4F7));
    final height = AppResponsive.dialogButtonHeight(context);
    final fontSize = AppResponsive.dialogButtonFontSize(context);

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
