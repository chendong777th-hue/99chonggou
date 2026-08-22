import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/customer_service_nav.dart';

/// Reusable auth-flow primitives — text fields, buttons, layout shells.
/// Auth pages always use a fixed light palette, independent of app theme.

/// Forces Material widgets on auth routes to use a fixed light palette.
class AuthLightScope extends StatelessWidget {
  final Widget child;

  const AuthLightScope({super.key, required this.child});

  static ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    fontFamily: AppTokens.fontFamily,
    scaffoldBackgroundColor: AppTokens.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTokens.brand500,
      brightness: Brightness.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      hintStyle: authFieldHintStyle(),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppTokens.brand500,
      selectionColor: Color(0x381E90FF),
      selectionHandleColor: AppTokens.brand500,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(data: _lightTheme, child: child);
  }
}

/// Scroll padding so focused fields stay above the keyboard in auth scroll views.
EdgeInsets authFieldScrollPadding(BuildContext context) {
  final bottom = MediaQuery.viewInsetsOf(context).bottom;
  return EdgeInsets.fromLTRB(20, 20, 20, bottom + 120);
}

/// Auth 输入框正文样式。Web 必须显式指定内置 NotoSansSC，否则禁 gstatic 回退后中文 hint/输入不可见。
TextStyle authFieldInputStyle({Color color = AppTokens.ink800}) {
  return TextStyle(
    fontFamily: AppTokens.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.2,
  );
}

TextStyle authFieldHintStyle() {
  return authFieldInputStyle().copyWith(
    color: AppTokens.ink300,
    fontWeight: FontWeight.w400,
  );
}

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final Widget? prefix;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool showClearButton;

  const AuthTextField({
    Key? key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.prefix,
    this.enabled = true,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.showClearButton = true,
  }) : super(key: key);

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_refreshClearButton);
    widget.controller.addListener(_refreshClearButton);
  }

  @override
  void didUpdateWidget(covariant AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshClearButton);
      widget.controller.addListener(_refreshClearButton);
      _refreshClearButton();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _focusNode).removeListener(_refreshClearButton);
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else if (!_ownsFocusNode) {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_refreshClearButton);
      _refreshClearButton();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_refreshClearButton);
    widget.controller.removeListener(_refreshClearButton);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _refreshClearButton() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _showClear =>
      widget.showClearButton && widget.enabled && _focusNode.hasFocus;

  void _clearText() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  Widget? _buildSuffixIcon() {
    final clear = _showClear
        ? GestureDetector(
            onTap: _clearText,
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.cancel,
              size: 18,
              color: AppTokens.ink300,
            ),
          )
        : null;
    if (clear == null) {
      return widget.suffix;
    }
    if (widget.suffix == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: clear,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          clear,
          const SizedBox(width: 4),
          widget.suffix!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = authFieldInputStyle();
    final suffix = _buildSuffixIcon();
    final scrollPadding = authFieldScrollPadding(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTokens.fieldFill,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.obscureText
            ? (widget.keyboardType ?? TextInputType.visiblePassword)
            : widget.keyboardType,
        obscureText: widget.obscureText,
        autocorrect: !widget.obscureText,
        enableSuggestions: !widget.obscureText,
        enabled: widget.enabled,
        inputFormatters: widget.inputFormatters,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onFieldSubmitted,
        scrollPadding: scrollPadding,
        style: inputStyle,
        cursorColor: AppTokens.brand500,
        decoration: InputDecoration(
          filled: false,
          fillColor: Colors.transparent,
          hintText: widget.hint,
          hintStyle: authFieldHintStyle(),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          prefixIcon: widget.prefix,
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: suffix,
          suffixIconConstraints: BoxConstraints(
            minWidth: suffix == null ? 0 : (widget.suffix == null ? 48 : 80),
            minHeight: 52,
          ),
        ),
      ),
    );
  }
}

class AuthCompoundField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? leading;
  final Widget? trailing;
  final double? leadingWidth;
  final double? trailingWidth;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool showClearButton;

  const AuthCompoundField({
    Key? key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.leading,
    this.trailing,
    this.leadingWidth,
    this.trailingWidth,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.showClearButton = true,
  }) : super(key: key);

  @override
  State<AuthCompoundField> createState() => _AuthCompoundFieldState();
}

class _AuthCompoundFieldState extends State<AuthCompoundField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_refreshClearButton);
    widget.controller.addListener(_refreshClearButton);
  }

  @override
  void didUpdateWidget(covariant AuthCompoundField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshClearButton);
      widget.controller.addListener(_refreshClearButton);
      _refreshClearButton();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _focusNode).removeListener(_refreshClearButton);
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else if (!_ownsFocusNode) {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_refreshClearButton);
      _refreshClearButton();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_refreshClearButton);
    widget.controller.removeListener(_refreshClearButton);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _refreshClearButton() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _showClear => widget.showClearButton && _focusNode.hasFocus;

  void _clearText() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = authFieldInputStyle();
    final scrollPadding = authFieldScrollPadding(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTokens.fieldFill,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            SizedBox(
              width: widget.leadingWidth ?? 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: widget.leading,
              ),
            ),
            Container(
              width: 1,
              height: 22,
              color: AppTokens.ink150,
            ),
          ],
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: widget.obscureText
                        ? (widget.keyboardType ??
                            TextInputType.visiblePassword)
                        : widget.keyboardType,
                    obscureText: widget.obscureText,
                    autocorrect: !widget.obscureText,
                    enableSuggestions: !widget.obscureText,
                    inputFormatters: widget.inputFormatters,
                    maxLength: widget.maxLength,
                    onChanged: widget.onChanged,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onFieldSubmitted,
                    scrollPadding: scrollPadding,
                    style: inputStyle,
                    cursorColor: AppTokens.brand500,
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: widget.hint,
                      hintStyle: authFieldHintStyle(),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                    ),
                  ),
                ),
                if (_showClear)
                  GestureDetector(
                    onTap: _clearText,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.cancel,
                        size: 18,
                        color: AppTokens.ink300,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            Container(
              width: 1,
              height: 22,
              color: AppTokens.ink150,
            ),
            SizedBox(
              width: widget.trailingWidth ?? 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: widget.trailing,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  final String text;
  final String? loadingText;
  final VoidCallback? onPressed;
  final bool loading;
  final bool pill;

  const AuthPrimaryButton({
    Key? key,
    required this.text,
    this.loadingText,
    this.onPressed,
    this.loading = false,
    this.pill = false,
  }) : super(key: key);

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    const radius = AppTokens.rLg;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!_enabled) {
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        widget.onPressed!();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 52,
        transform: Matrix4.diagonal3Values(
          _pressed && _enabled ? 0.98 : 1.0,
          _pressed && _enabled ? 0.98 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _enabled ? AppTokens.brand500 : AppTokens.ink100,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: _enabled ? AppTokens.shadowSm : const [],
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  if (widget.loadingText != null &&
                      widget.loadingText!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(widget.loadingText!, style: AppTokens.button),
                  ],
                ],
              )
            : Text(widget.text, style: AppTokens.button),
      ),
    );
  }
}

class AuthSendCodeButton extends StatelessWidget {
  final int cooldown;
  final bool busy;
  final VoidCallback? onPressed;
  final String label;

  const AuthSendCodeButton({
    Key? key,
    required this.cooldown,
    required this.busy,
    this.onPressed,
    this.label = '获取验证码',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final enabled = cooldown == 0 && !busy;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppTokens.ink50,
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          border: Border.all(
              color: enabled ? AppTokens.ink150 : AppTokens.ink100, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          cooldown > 0
              ? '${cooldown}s'
              : (label == '获取验证码'
                  ? i18n.t(
                      zhHans: '获取验证码',
                      zhHant: '獲取驗證碼',
                      en: 'Get Code',
                      ja: 'コードを取得',
                      ko: '인증코드 받기',
                    )
                  : label),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTokens.brand500 : AppTokens.ink300,
          ),
        ),
      ),
    );
  }
}

class AuthEntryScaffold extends StatelessWidget {
  final String greeting;
  final String accent;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry contentPadding;
  final List<String>? tabs;
  final int? activeTab;
  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onBack;
  final Widget? headerAction;

  const AuthEntryScaffold({
    Key? key,
    required this.greeting,
    required this.accent,
    required this.child,
    this.footer,
    this.contentPadding = const EdgeInsets.fromLTRB(28, 34, 28, 24),
    this.tabs,
    this.activeTab,
    this.onTabSelected,
    this.onBack,
    this.headerAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return _buildWideLayout(context, constraints);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    final keyboardVisible = media.viewInsets.bottom > 0;
    final heroTopGap = onBack != null
        ? (keyboardVisible ? 4.0 : 12.0)
        : (keyboardVisible ? 12.0 : 44.0);
    final afterBackGap = keyboardVisible ? 12.0 : 26.0;
    final headerBottom = keyboardVisible ? 14.0 : 24.0;
    final tabGap = keyboardVisible ? 16.0 : 28.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTokens.brandGradient,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(28, top + 18, 28, headerBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onBack != null) ...[
                      _BackButton(onTap: onBack!),
                      SizedBox(height: afterBackGap),
                    ],
                    SizedBox(height: heroTopGap),
                    Text(greeting, style: AppTokens.authHeroTitle),
                    Text(accent, style: AppTokens.authHeroTitle),
                    if (tabs != null && tabs!.isNotEmpty) ...[
                      SizedBox(height: tabGap),
                      AuthTopTabs(
                        activeTab: activeTab ?? 0,
                        tabs: tabs!,
                        onSelected: onTabSelected ?? (_) {},
                      ),
                    ],
                  ],
                ),
              ),
              if (headerAction != null)
                Positioned(
                  top: top + 12,
                  right: 18,
                  child: headerAction!,
                ),
            ],
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTokens.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
              ),
              child: Padding(
                padding: contentPadding,
                child: Column(
                  children: [
                    Expanded(child: child),
                    if (footer != null && !keyboardVisible) ...[
                      const SizedBox(height: 18),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, BoxConstraints constraints) {
    final height =
        constraints.maxHeight.isFinite ? constraints.maxHeight : 760.0;
    // Web 注册表单字段较多；过矮的面板会裁切底部协议/规则文案。
    final panelHeight = height < 640
        ? height
        : kIsWeb
            ? (height - 48).clamp(680.0, 920.0).toDouble()
            : (height - 72).clamp(620.0, 760.0).toDouble();
    return Container(
      color: const Color(0xFFF4F7FB),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1120,
          maxHeight: panelHeight,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTokens.shadowMd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  height: double.infinity,
                  padding: const EdgeInsets.fromLTRB(48, 44, 48, 42),
                  decoration: const BoxDecoration(
                    gradient: AppTokens.brandGradient,
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (onBack != null) ...[
                            _BackButton(onTap: onBack!),
                            const SizedBox(height: 44),
                          ] else
                            const SizedBox(height: 28),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 34),
                          Text(
                            greeting,
                            style: AppTokens.authHeroTitle.copyWith(
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            accent,
                            style: AppTokens.authHeroTitle.copyWith(
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            '多端同步 · 单聊群聊 · 安全通讯',
                            style: AppTokens.subtitle.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _HeroChip(text: '消息同步'),
                              _HeroChip(text: '群组聊天'),
                              _HeroChip(text: '音视频通话'),
                            ],
                          ),
                        ],
                      ),
                      if (headerAction != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: headerAction!,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 44, 56, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tabs != null && tabs!.isNotEmpty)
                        _WideAuthTabs(
                          activeTab: activeTab ?? 0,
                          tabs: tabs!,
                          onSelected: onTabSelected ?? (_) {},
                        ),
                      const SizedBox(height: 30),
                      Expanded(
                        child: Padding(
                          padding: contentPadding,
                          child: child,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 14),
                        Center(child: footer!),
                      ],
                    ],
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTokens.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WideAuthTabs extends StatelessWidget {
  const _WideAuthTabs({
    required this.tabs,
    required this.activeTab,
    required this.onSelected,
  });

  final List<String> tabs;
  final int activeTab;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (index) {
        final active = index == activeTab;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: Container(
            margin: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 30),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: active
                  ? const Border(
                      bottom: BorderSide(color: AppTokens.brand500, width: 4),
                    )
                  : null,
            ),
            child: Text(
              tabs[index],
              style: TextStyle(
                fontFamily: AppTokens.fontFamily,
                fontSize: 24,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppTokens.ink900 : AppTokens.ink400,
                letterSpacing: -0.3,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class AuthTopTabs extends StatelessWidget {
  final List<String> tabs;
  final int activeTab;
  final ValueChanged<int> onSelected;

  const AuthTopTabs({
    Key? key,
    required this.tabs,
    required this.activeTab,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (index) {
        final active = index == activeTab;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: Container(
            margin: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 36),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: active
                  ? const Border(
                      bottom: BorderSide(color: Colors.white, width: 4),
                    )
                  : null,
            ),
            child: Text(
              tabs[index],
              style:
                  active ? AppTokens.authTabActive : AppTokens.authTabInactive,
            ),
          ),
        );
      }),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBack;
  final List<Widget>? bottomActions;

  const AuthScaffold({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack = false,
    this.bottomActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final footerBottom = bottomInset > 0 ? bottomInset + 16 : bottomSafe + 16;
    return Scaffold(
      backgroundColor: AppTokens.surface,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: bottomInset > 0 ? bottomInset + 120 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(24, top + 16, 24, 32),
                      decoration: const BoxDecoration(color: AppTokens.surface),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showBack)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: GestureDetector(
                                onTap: () => Navigator.maybePop(context),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTokens.ink50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: AppTokens.brand500,
                                  ),
                                ),
                              ),
                            ),
                          Text(title, style: AppTokens.display),
                          const SizedBox(height: 6),
                          Text(subtitle, style: AppTokens.subtitle),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppTokens.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(28, 0, 28, footerBottom),
                child: footer!,
              ),
            if (bottomActions != null)
              Padding(
                padding: EdgeInsets.only(bottom: footer == null ? footerBottom : 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: bottomActions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  final String text;
  const AuthFieldLabel(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(
        text,
        style: AppTokens.label.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTokens.ink800,
        ),
      ),
    );
  }
}

class AuthLinkText extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback? onTap;
  const AuthLinkText(
      {Key? key, required this.prefix, required this.action, this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(prefix, style: AppTokens.caption),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(action, style: AppTokens.link),
        ),
      ],
    );
  }
}

class AuthInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const AuthInfoBanner({Key? key, required this.icon, required this.text})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTokens.brand50,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: AppTokens.brand100, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTokens.brand500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppTokens.body
                    .copyWith(fontSize: 13, color: AppTokens.ink600)),
          ),
        ],
      ),
    );
  }
}

/// Agreement checkbox row.
class AuthAgreementCheck extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTapTerms;
  final VoidCallback? onTapPrivacy;

  const AuthAgreementCheck({
    Key? key,
    required this.checked,
    required this.onChanged,
    this.onTapTerms,
    this.onTapPrivacy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => onChanged(!checked),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: checked ? AppTokens.brand500 : Colors.transparent,
              border: Border.all(
                color: checked ? AppTokens.brand500 : AppTokens.ink150,
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: checked
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: AppTokens.caption
                  .copyWith(color: AppTokens.ink400, height: 1.4),
              children: [
                TextSpan(
                  text: i18n.t(
                    zhHans: '我已阅读并同意 ',
                    zhHant: '我已閱讀並同意 ',
                    en: 'I have read and agree to ',
                    ja: '以下の内容を読み、同意します ',
                    ko: '다음 내용을 읽고 동의합니다 ',
                  ),
                ),
                TextSpan(
                  text: i18n.t(
                    zhHans: '《用户协议》',
                    zhHant: '《用戶協議》',
                    en: 'User Agreement',
                    ja: '利用規約',
                    ko: '이용약관',
                  ),
                  style: AppTokens.caption.copyWith(
                    color: AppTokens.brand500,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                ),
                TextSpan(
                  text: i18n.t(
                    zhHans: ' 与 ',
                    zhHant: ' 與 ',
                    en: ' and ',
                    ja: ' および ',
                    ko: ' 및 ',
                  ),
                ),
                TextSpan(
                  text: i18n.t(
                    zhHans: '《隐私政策》',
                    zhHant: '《隱私政策》',
                    en: 'Privacy Policy',
                    ja: 'プライバシーポリシー',
                    ko: '개인정보 처리방침',
                  ),
                  style: AppTokens.caption.copyWith(
                    color: AppTokens.brand500,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 登录/注册/找回密码页右上角在线客服入口（未登录访客模式）。
class AuthCustomerServiceButton extends StatelessWidget {
  const AuthCustomerServiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);

    return Semantics(
      button: true,
      label: i18n.t(
        zhHans: '在线客服',
        zhHant: '線上客服',
        en: 'Customer Service',
        ja: 'オンラインサポート',
        ko: '고객센터',
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => CustomerServiceNav.open(context, guest: true),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.headset_mic_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
