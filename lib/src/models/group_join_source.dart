/// 用户主动申请加群的来源（与 99chat-server `joinSource` 对齐）。
enum GroupJoinSource {
  groupAlias('group_alias'),
  qrCode('qr_code'),
  search('search');

  const GroupJoinSource(this.storageValue);

  final String storageValue;

  static GroupJoinSource? fromStorage(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final item in GroupJoinSource.values) {
      if (item.storageValue == normalized) {
        return item;
      }
    }
    return null;
  }
}
