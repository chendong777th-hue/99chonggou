/// 群资料变更本地灰字摘要（自建群无 IM GroupTips 时使用）。
String groupProfileLocalTipPreview(String action, String opName) {
  final name = opName.trim();
  switch (action.trim().toLowerCase()) {
    case 'group_name_changed':
      return '$name修改了群名称';
    case 'group_avatar_changed':
      return '$name修改了群头像';
    case 'group_notice_changed':
      return '$name修改了群公告';
    default:
      return '';
  }
}
