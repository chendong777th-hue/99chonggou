import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/desktop_call_float_overlay.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/wallet_card_fail_global_listener.dart';

/// 仅响应字体缩放等设置，避免整棵 [MaterialApp] 因 [LocalSetting] 变化而重建。
class AppMaterialAppBuilder extends StatelessWidget {
  final Widget? child;

  const AppMaterialAppBuilder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final localSetting = context.watch<LocalSetting>();
    final mediaQuery = MediaQuery.of(context);
    final scaledChild = MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(localSetting.chatFontScale),
      ),
      child: child ?? const SizedBox.shrink(),
    );
    return WalletCardFailGlobalListener(
      child: DesktopCallFloatOverlay(
        child: EasyLoading.init()(context, scaledChild),
      ),
    );
  }
}
