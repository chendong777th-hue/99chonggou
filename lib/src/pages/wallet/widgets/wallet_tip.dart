import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class WalletTip {
  WalletTip._();

  static void show(BuildContext context, String text) {
    ToastUtils.toast(text);
  }
}
