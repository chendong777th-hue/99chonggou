import 'dart:convert';

import 'package:flutter/cupertino.dart';

typedef LinkPreviewText = Widget Function({TextStyle? style});

class LocalCustomDataModel {
  final String? description;
  final String? image;
  final String? url;
  final String? title;
  String? translatedText;
  String? voiceToText;
  String? voiceToTextStatus;
  String? voiceToTextDisplayState;

  LocalCustomDataModel({
    this.description,
    this.image,
    this.url,
    this.title,
    this.translatedText,
    this.voiceToText,
    this.voiceToTextStatus,
    this.voiceToTextDisplayState,
  });

  Map<String, String?> toMap() {
    final Map<String, String?> data = {};
    data['url'] = url;
    data['image'] = image;
    data['title'] = title;
    data['description'] = description;
    data['translatedText'] = translatedText;
    data['voiceToText'] = voiceToText;
    data['voiceToTextStatus'] = voiceToTextStatus;
    data['voiceToTextDisplayState'] = voiceToTextDisplayState;
    return data;
  }

  LocalCustomDataModel.fromMap(Map map)
      : description = map['description'],
        image = map['image'],
        url = map['url'],
        translatedText = map['translatedText'],
        voiceToText = map['voiceToText'],
        voiceToTextStatus = map['voiceToTextStatus'],
        voiceToTextDisplayState = map['voiceToTextDisplayState'],
        title = map['title'];

  bool get isVoiceToTextExpanded => voiceToTextDisplayState != 'collapsed';

  void setVoiceToTextExpanded(bool expanded) {
    voiceToTextDisplayState = expanded ? 'expanded' : 'collapsed';
  }

  @override
  String toString() {
    return json.encode(toMap());
  }

  bool isLinkPreviewEmpty() {
    if ((image == null || image!.isEmpty) &&
        (title == null || title!.isEmpty) &&
        (description == null || description!.isEmpty)) {
      return true;
    }
    return false;
  }
}

class LinkPreviewContent {
  const LinkPreviewContent({
    this.linkInfo,
    this.linkPreviewWidget,
  });

  final LocalCustomDataModel? linkInfo;
  final Widget? linkPreviewWidget;
}
