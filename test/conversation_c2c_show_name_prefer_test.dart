import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_c2c_show_name_prefer.dart';

void main() {
  test('store remark wins over incoming nick', () {
    expect(
      ConversationC2cShowNamePrefer.preferC2cShowName(
        existingShowName: '旧备注',
        incomingShowName: '真名',
        storeName: '备注A',
      ),
      '备注A',
    );
  });

  test('existing wins when store empty and incoming differs', () {
    expect(
      ConversationC2cShowNamePrefer.preferC2cShowName(
        existingShowName: '备注B',
        incomingShowName: '真名',
        storeName: '',
      ),
      '备注B',
    );
  });

  test('incoming used when store and existing empty', () {
    expect(
      ConversationC2cShowNamePrefer.preferC2cShowName(
        existingShowName: '',
        incomingShowName: '真名',
        storeName: null,
      ),
      '真名',
    );
  });

  test('preferForConversationIds reads store for c2c', () {
    expect(
      ConversationC2cShowNamePrefer.preferForConversationIds(
        conversationID: 'c2c_u1',
        userID: 'u1',
        existingShowName: '行备注',
        incomingShowName: '真名',
        readStore: (id) => id == 'u1' ? 'Store备注' : null,
      ),
      'Store备注',
    );
  });
}
