import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';

bool settingsIsDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

class SettingsScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onLeadingPressed;
  final bool disableLeading;

  /// 为 false 时不显示返回（桌面右栏根页等）。
  final bool showLeading;
  final bool dismissKeyboardOnOutsideTap;

  /// 嵌在 WidePopup 等宿主标题栏内时隐藏自身 AppBar，避免双头部。
  final bool embedded;

  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.onLeadingPressed,
    this.disableLeading = false,
    this.showLeading = true,
    this.dismissKeyboardOnOutsideTap = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);
    final dividerColor = AppColors.line(dark: dark);
    final overlayStyle = immersiveOverlayForColors(
      statusBarBackground: AppColors.card(dark: dark),
      navigationBarBackground: AppColors.background(dark: dark),
    );

    final canShowLeading =
        showLeading && !disableLeading && Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.background(dark: dark),
        extendBody: true,
        appBar: embedded
            ? null
            : AppBar(
                elevation: 0,
                centerTitle: true,
                backgroundColor: AppColors.card(dark: dark),
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: overlayStyle,
                automaticallyImplyLeading: canShowLeading,
                leading: canShowLeading
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: AppTokens.accent,
                        onPressed: onLeadingPressed ??
                            () => Navigator.of(context).pop(),
                      )
                    : null,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(0.6),
                  child: Container(
                    height: 0.6,
                    color: dividerColor,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _buildScrollBody(),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollBody() {
    final listView = ListView(
      keyboardDismissBehavior: dismissKeyboardOnOutsideTap
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
    if (!dismissKeyboardOnOutsideTap) {
      return listView;
    }
    return TapRegion(
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: listView,
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);

    return Container(
      margin: margin,
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
      child: Column(children: children),
    );
  }
}

class SettingsCell extends StatelessWidget {
  final String title;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final bool showArrow;
  final bool showDivider;
  final VoidCallback? onTap;
  final Widget? trailing;
  final TextStyle? titleStyle;

  const SettingsCell({
    super.key,
    required this.title,
    this.value,
    this.icon,
    this.iconColor,
    this.showArrow = true,
    this.showDivider = true,
    this.onTap,
    this.trailing,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);
    final minHeight = AppResponsive.listRowMinHeight(context);
    final padding = AppResponsive.listRowPadding(context);
    final iconSize = context.isDesktopFormFactor ? 20.0 : 22.0;
    final valueMaxWidth = (MediaQuery.sizeOf(context).width *
            (context.isDesktopFormFactor ? 0.36 : 0.48))
        .clamp(120.0, context.isDesktopFormFactor ? 360.0 : 220.0)
        .toDouble();

    var row = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.7,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? AppColors.subText(dark: dark),
              size: iconSize,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle ??
                  TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: valueMaxWidth),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 14,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showArrow) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subText(dark: dark),
              size: 22,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class SettingsInputCell extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;

  const SettingsInputCell({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    var dark = settingsIsDark(context);
    final minHeight = AppResponsive.listRowMinHeight(context);
    final labelWidth = AppResponsive.labelColumnWidth(context);
    final padding = AppResponsive.listRowPadding(context);

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.line(dark: dark),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              readOnly: readOnly,
              enabled: !readOnly,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              cursorColor: AppColors.primaryBlue,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
                hintStyle: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 16,
                ),
              ),
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPlatformSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsPlatformSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isCupertino) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryBlue,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
      activeTrackColor: AppColors.primaryBlue,
    );
  }
}

class SettingsPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const SettingsPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final height = AppResponsive.controlHeight(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

void openSettingsPlaceholder(BuildContext context) {
  Navigator.push(
    context,
    AppMaterialPageRoute(builder: (_) => const Placeholder()),
  );
}
