// ignore_for_file: file_names

import 'package:tencent_cloud_chat_sdk/enum/callbacks.dart';

class V2TimUIKitListener {
  OnUiKitEventEmit onUiKitEventEmit = (Map<String, dynamic> data) {};
  V2TimUIKitListener({
    OnUiKitEventEmit? onUiKitEventEmit,
  }) {
    if (onUiKitEventEmit != null) {
      this.onUiKitEventEmit = onUiKitEventEmit;
    }
  }
}
