import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';

/// 回归：群通知聚合不得对每个管理员群 N+1 打 join-applications。
void main() {
  test('GroupJoinApplicationService aggregation uses /me only', () {
    final source = File(
      'lib/src/services/group_join_application_service.dart',
    ).readAsStringSync();

    expect(source.contains('fetchAllMyJoinApplications'), isTrue);
    expect(source.contains('loadApplicationsForGroup'), isTrue);
    expect(
      source.contains('adminGroupIds.map'),
      isFalse,
      reason: 'must not loop admin groups for join-applications',
    );

    // _loadApplications（聚合）不得调用 per-group fetch；单群路径才允许。
    final loadAppsStart = source.indexOf(
      'Future<List<V2TimGroupApplication>> _loadApplications(',
    );
    expect(loadAppsStart, greaterThanOrEqualTo(0));
    final loadAppsEnd = source.indexOf('String _recordKey(', loadAppsStart);
    expect(loadAppsEnd, greaterThan(loadAppsStart));
    final loadAppsBody = source.substring(loadAppsStart, loadAppsEnd);
    expect(loadAppsBody.contains('fetchJoinApplications('), isFalse);
    expect(loadAppsBody.contains('fetchAllMyJoinApplications'), isTrue);
  });

  test('single-group page calls loadApplicationsForGroup', () {
    final page = File(
      'lib/src/pages/group_self_hosted_join_application_list_page.dart',
    ).readAsStringSync();
    expect(page.contains('loadApplicationsForGroup'), isTrue);
    expect(
      page.contains('refresh(\n        force: true'),
      isFalse,
      reason: 'single-group page must not refresh full /me as main path',
    );
  });

  test('conversation page refreshes applications without full group sync', () {
    final source = File('lib/src/conversation.dart').readAsStringSync();
    expect(
      source.contains(
        'GroupJoinApplicationService.instance.refresh(syncMembership: false)',
      ),
      isTrue,
    );
  });

  test('application-only refresh entrypoints skip full group sync', () {
    for (final path in const [
      'lib/main.dart',
      'lib/src/services/group_notice_bootstrap.dart',
      'lib/src/services/group_local/group_sync_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('syncMembership: false'),
        isTrue,
        reason: '$path must refresh applications without syncFull',
      );
    }
  });

  test('isJoinAppsRateLimited detects 429 and RATE_LIMITED body', () {
    DioError build({
      int? statusCode,
      Object? data,
    }) {
      final options = RequestOptions(path: '/group/x/join-applications');
      return DioError(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: data,
        ),
        type: DioErrorType.response,
      );
    }

    expect(
      GroupJoinApi.isJoinAppsRateLimited(
        build(statusCode: 429, data: {'code': 'RATE_LIMITED'}),
      ),
      isTrue,
    );
    expect(
      GroupJoinApi.isJoinAppsRateLimited(
        build(statusCode: 403, data: {'code': 'RATE_LIMITED'}),
      ),
      isTrue,
    );
    expect(
      GroupJoinApi.isJoinAppsRateLimited(
        build(statusCode: 403, data: {'code': 'NOT_GROUP_ADMIN'}),
      ),
      isFalse,
    );
  });

  test('MeGroupApi defaults to limit 100 with max 200', () {
    final source = File('lib/src/api/me_group_api.dart').readAsStringSync();

    expect(source.contains('int limit = 100'), isTrue);
    expect(source.contains('limit.clamp(1, 200)'), isTrue);
    expect(source.contains('const limit = 100'), isTrue);
    expect(source.contains('buildMeGroupsQuery'), isTrue);
    expect(source.contains('limit.clamp(1, 500)'), isFalse);
    expect(source.contains('const limit = 500'), isFalse);
  });

  test('only group create recovery may refresh /me/groups', () {
    final create = File(
      'lib/src/services/group_local/group_create_service.dart',
    ).readAsStringSync();
    expect(create.contains('refresh: true'), isTrue);

    final chat = File('lib/src/chat.dart').readAsStringSync();
    expect(
      chat.contains("reason: 'chat_open_verify',\n        refresh: true"),
      isFalse,
    );
  });
}
