import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/group_leave_navigation.dart';

Route<void> _route({String? name}) {
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => const SizedBox.shrink(),
  );
}

void main() {
  test('leave return target recognizes myGroupList and home', () {
    final myGroups = _route(name: AppRoutes.myGroupList);
    final home = _route(name: '/homePage');
    final chat = _route(name: AppRoutes.chat);

    expect(GroupLeaveNavigation.isMyGroupListRoute(myGroups), isTrue);
    expect(GroupLeaveNavigation.isLeaveReturnTarget(myGroups), isTrue);
    expect(GroupLeaveNavigation.isLeaveReturnTarget(home), isTrue);
    expect(GroupLeaveNavigation.isLeaveReturnTarget(chat), isFalse);
  });
}
