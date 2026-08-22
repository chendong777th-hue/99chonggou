import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class ClipboardGuard {
  ClipboardGuard._();

  static Future<void> copy(
    String text, {
    bool showToast = false,
    String toastText = '已复制',
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: value));
    if (showToast) {
      ToastUtils.toastForce(toastText);
    }
  }

  static Future<String> readText({bool trim = true}) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    return trim ? text.trim() : text;
  }
}
