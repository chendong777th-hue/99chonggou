// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk_example/pages/api_test_page.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/listener_manager.dart';

void main() {
  // 预初始化全局监听器管理器
  final listenerManager = ListenerManager();
  listenerManager.initialize();
  
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => LogManager()),
      Provider<ListenerManager>.value(value: listenerManager),
    ], child: const MaterialApp(home: APITestPage())),
  );
}

