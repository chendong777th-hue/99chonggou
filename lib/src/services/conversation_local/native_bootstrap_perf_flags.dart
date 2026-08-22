import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 原生进首页后补全队列节奏（防读写风暴）。
class NativeBootstrapPerfFlags {
  NativeBootstrapPerfFlags._();

  /// 阶段与阶段之间让出主线程。
  static Duration get stageYield {
    if (!kIsWeb && Platform.isAndroid) {
      return const Duration(milliseconds: 96);
    }
    return const Duration(milliseconds: 48);
  }

  /// 进首页后再开始补全：给启动图→首页转场与首几次 pop 留帧。
  static Duration get postHomeStartDelay {
    if (!kIsWeb && Platform.isAndroid) {
      return const Duration(milliseconds: 3500);
    }
    return const Duration(milliseconds: 1200);
  }
}
