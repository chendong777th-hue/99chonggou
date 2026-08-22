// ignore_for_file: avoid_function_literals_in_foreach_calls
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/utils/const.dart';

/// @nodoc
class Utils {
  static int _uniqueSequence = 0;
  ///@nodoc
  ///
  static List<int> getAbility() {
    String t = StackTrace.current.toString();
    List<int> ab = List.empty(growable: true);
    TencentIMSDKCONST.scenes.keys.forEach((element) {
      if (t.contains(element)) {
        if (TencentIMSDKCONST.scenes.keys.contains(element)) {
          ab.add(TencentIMSDKCONST.scenes[element]!);
        }
      }
    });
    return ab;
  }

  ///@nodoc
  ///
  static String generateUniqueString() {
    ++_uniqueSequence;
    return 'unique_label-$_uniqueSequence';
  }

  static Map<String, dynamic> formatJson(Map? jsonSrc) {
    if (jsonSrc != null) {
      return Map<String, dynamic>.from(jsonSrc);
    }
    return Map<String, dynamic>.from({});
  }
}
