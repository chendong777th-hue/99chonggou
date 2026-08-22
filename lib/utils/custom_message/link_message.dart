import 'dart:convert';

import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';

class LinkMessage {
  String? link;
  String? text;
  String? businessID;

  LinkMessage.fromJSON(Map json) {
    link = json["link"];
    text = json["text"];
    businessID = json["businessID"];
  }
}

LinkMessage? getLinkMessage(V2TimCustomElem? customElem) {
  try {
    if (customElem?.data == null || customElem!.data!.isEmpty) {
      return null;
    }
    final customMessage = jsonDecode(customElem.data!);
    if (customMessage is! Map) {
      return null;
    }
    if (customMessage["businessID"] == kContactCardBusinessID) {
      return null;
    }
    final message = LinkMessage.fromJSON(customMessage);
    final hasLink = (message.link ?? '').trim().isNotEmpty;
    final hasText = (message.text ?? '').trim().isNotEmpty;
    if (!hasLink && !hasText) {
      return null;
    }
    return message;
  } catch (err) {
    return null;
  }
}