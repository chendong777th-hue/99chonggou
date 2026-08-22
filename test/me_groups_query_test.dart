import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';

void main() {
  group('MeGroupApi.buildMeGroupsQuery', () {
    test('daily call sends limit only when offset is 0', () {
      expect(
        MeGroupApi.buildMeGroupsQuery(limit: 100, offset: 0),
        {'limit': 100},
      );
    });

    test('pagination includes offset when > 0', () {
      expect(
        MeGroupApi.buildMeGroupsQuery(limit: 100, offset: 100),
        {'limit': 100, 'offset': 100},
      );
    });

    test('refresh only when true as string true', () {
      expect(
        MeGroupApi.buildMeGroupsQuery(limit: 100, offset: 0, refresh: true),
        {'limit': 100, 'refresh': 'true'},
      );
      expect(
        MeGroupApi.buildMeGroupsQuery(limit: 100, offset: 0, refresh: false)
            .containsKey('refresh'),
        isFalse,
      );
    });

    test('clamps limit to 1..200', () {
      expect(MeGroupApi.buildMeGroupsQuery(limit: 500)['limit'], 200);
      expect(MeGroupApi.buildMeGroupsQuery(limit: 0)['limit'], 1);
    });

    test('omits all when no args (server defaults)', () {
      expect(MeGroupApi.buildMeGroupsQuery(), isEmpty);
    });
  });
}
