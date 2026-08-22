class WalletRecordTimelineItem {
  final String title;
  final String time;
  final String desc;

  const WalletRecordTimelineItem({
    required this.title,
    required this.time,
    this.desc = '',
  });
}
