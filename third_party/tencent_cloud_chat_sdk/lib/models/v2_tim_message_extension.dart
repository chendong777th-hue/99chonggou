import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageExtension
///
/// {@category Models}
///
class V2TimMessageExtension {
  String extensionKey = "";
  String extensionValue = "";

  V2TimMessageExtension({
    required this.extensionKey,
    required this.extensionValue,
  });

  V2TimMessageExtension.fromJson(Map json) {
    json = Utils.formatJson(json);
    extensionKey = json["message_extension_key"] ?? "";
    extensionValue = json["message_extension_value"] ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["message_extension_key"] = extensionKey;
    data["message_extension_value"] = extensionValue;
    return data;
  }
  String toLogString() {
    String res = "extensionKey:$extensionKey|extensionValue:$extensionValue";
    return res;
  }
}
