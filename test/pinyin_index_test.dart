import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/search_local/pinyin_index.dart';

void main() {
  test('pinyinOf and initialsOf for Chinese name', () {
    final initials = PinyinIndex.initialsOf('张三');
    final pinyin = PinyinIndex.pinyinOf('张三');
    expect(initials, isNotEmpty);
    expect(pinyin, isNotEmpty);
  });

  test('friendHaystack includes id and name tokens', () {
    const nick = '张三';
    const remark = '李四';
    final haystack = PinyinIndex.friendHaystack(
      userId: 'u1',
      nickname: nick,
      remark: remark,
    );
    expect(haystack.contains('u1'), isTrue);
    expect(haystack.contains(nick.toLowerCase()), isTrue);
    final nickToken = PinyinIndex.searchTokensFor(nick);
    if (nickToken.isNotEmpty) {
      expect(haystack.contains(nickToken.split(' ').first), isTrue);
    }
  });

  test('groupHaystack includes group id', () {
    final haystack = PinyinIndex.groupHaystack(
      groupId: 'g1',
      groupName: '王者荣耀',
      displayAlias: '',
    );
    expect(haystack.contains('g1'), isTrue);
    expect(haystack.contains('王者荣耀'.toLowerCase()), isTrue);
  });
}
