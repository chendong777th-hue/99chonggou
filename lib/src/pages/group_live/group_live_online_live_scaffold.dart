import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:tencent_cloud_chat_demo/src/ui/widgets/app_cupertino_datetime_sheet.dart';

/// Shared visual shell for group live schedule / OBS push pages.
/// Shared hero / icon asset for group live flows.
const String groupLiveHeroAsset = 'assets/live/group_live_hero.webp';

class GroupLiveOnlineLiveScaffold extends StatelessWidget {
  const GroupLiveOnlineLiveScaffold({
    super.key,
    required this.body,
    this.bottomButton,
    this.onBack,
  });

  final Widget body;
  final Widget? bottomButton;
  final VoidCallback? onBack;

  static const Color pageBg = Color(0xFFF3F4F6);
  static const Color primaryBlue = Color(0xFF2D8CFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTokens.accent),
        leading: BackButton(
          color: AppTokens.accent,
          onPressed: onBack,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TapRegion(
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: body,
              ),
            ),
          ),
          if (bottomButton != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottomButton!,
              ),
            ),
        ],
      ),
    );
  }
}

class GroupLiveOnlineLiveHeader extends StatelessWidget {
  const GroupLiveOnlineLiveHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Column(
      children: [
        Image.asset(
          groupLiveHeroAsset,
          height: 168,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.live_tv_rounded,
            size: 96,
            color: GroupLiveOnlineLiveScaffold.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          i18n.t(
            zhHans: '在线直播',
            zhHant: '在線直播',
            en: 'Live Streaming',
            ja: 'オンライン配信',
            ko: '온라인 라이브',
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTokens.ink800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          i18n.t(
            zhHans: '可在其他直播应用中输入以下推流地址',
            zhHant: '可在其他直播應用中輸入以下推流地址',
            en: 'Enter the streaming URL below in your live app.',
            ja: '他の配信アプリに以下の配信URLを入力してください。',
            ko: '다른 방송 앱에 아래 推流 주소를 입력하세요.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppTokens.ink500,
          ),
        ),
      ],
    );
  }
}

/// Header for the schedule / room configuration step.
class GroupLiveScheduleHeader extends StatelessWidget {
  const GroupLiveScheduleHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Column(
      children: [
        Image.asset(
          groupLiveHeroAsset,
          height: 168,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.live_tv_rounded,
            size: 96,
            color: GroupLiveOnlineLiveScaffold.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          i18n.t(
            zhHans: '直播间配置',
            zhHant: '直播間配置',
            en: 'Live room setup',
            ja: '配信ルーム設定',
            ko: '라이브룸 설정',
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTokens.ink800,
          ),
        ),
      ],
    );
  }
}

class GroupLiveFormSection extends StatelessWidget {
  const GroupLiveFormSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.ink800,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        GroupLiveFormCard(children: children),
      ],
    );
  }
}

class GroupLiveFormCard extends StatelessWidget {
  const GroupLiveFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class GroupLiveSettingsCard extends StatelessWidget {
  const GroupLiveSettingsCard({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class GroupLiveCopyField extends StatelessWidget {
  const GroupLiveCopyField({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTokens.ink500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: AppTokens.ink700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: value.trim().isEmpty ? null : onCopy,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: value.trim().isEmpty
                          ? AppTokens.ink300
                          : AppTokens.ink400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GroupLivePushQrField extends StatelessWidget {
  const GroupLivePushQrField({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final data = value.trim();
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            i18n.t(
              zhHans: '可用芯象扫描二维码填入推流地址',
              zhHant: '可用芯象掃描二維碼填入推流地址',
              en: 'Scan this QR code in Xinxian to fill the streaming URL.',
              ja: '芯象でこのQRを読み取ると配信URLを入力できます。',
              ko: '芯象에서 이 QR을 스캔하면 推流 주소를 입력할 수 있습니다.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTokens.ink500,
            ),
          ),
        ],
      ),
    );
  }
}

class GroupLivePointsUsageSection extends StatelessWidget {
  const GroupLivePointsUsageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n.t(
            zhHans: '积分使用',
            zhHant: '積分使用',
            en: 'Points usage',
            ja: 'ポイント使用',
            ko: '포인트 사용',
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTokens.ink800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          i18n.t(
            zhHans:
                '1. 开启直播后\n   a. 1GB 直播流量消耗 300 积分\n   b. 流量按向上取整的 GB 数计算，比如不满 1GB 按 1GB 收取积分',
            zhHant:
                '1. 開啟直播後\n   a. 1GB 直播流量消耗 300 積分\n   b. 流量按向上取整的 GB 數計算，比如不滿 1GB 按 1GB 收取積分',
            en: '1. After going live\n   a. 1GB traffic costs 300 points\n   b. Traffic is billed in whole GB (rounded up)',
            ja: '1. 配信開始後\n   a. 1GB あたり 300 ポイント\n   b. 流量は GB 単位で切り上げ課金',
            ko: '1. 방송 시작 후\n   a. 1GB 流量당 300 포인트\n   b. 流量은 GB 단위 올림 과금',
          ),
          style: const TextStyle(
            fontSize: 13,
            height: 1.55,
            color: AppTokens.ink500,
          ),
        ),
      ],
    );
  }
}

class GroupLivePrimaryButton extends StatelessWidget {
  const GroupLivePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: GroupLiveOnlineLiveScaffold.primaryBlue,
          disabledBackgroundColor:
              GroupLiveOnlineLiveScaffold.primaryBlue.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

Future<void> groupLiveCopyToClipboard(
  BuildContext context, {
  required String label,
  required String value,
}) async {
  if (value.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value.trim()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppI18n.of(context).t(
          zhHans: '已复制$label',
          zhHant: '已複製$label',
          en: 'Copied $label',
          ja: '$label をコピーしました',
          ko: '$label 복사됨',
        ),
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Earliest allowed scheduled start: now + 1 minute.
const Duration kGroupLiveScheduleMinLead = Duration(minutes: 1);

DateTime groupLiveScheduleMinimumDate([DateTime? now]) {
  return (now ?? DateTime.now()).add(kGroupLiveScheduleMinLead);
}

DateTime _clampGroupLiveScheduleTime(
  DateTime value, {
  required DateTime minimumDate,
  required DateTime maximumDate,
}) {
  if (value.isBefore(minimumDate)) return minimumDate;
  if (value.isAfter(maximumDate)) return maximumDate;
  return value;
}

DateTime _alignGroupLiveScheduleMinute(DateTime value, {int interval = 1}) {
  final safeInterval = interval <= 0 ? 1 : interval;
  final minute = (value.minute ~/ safeInterval) * safeInterval;
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    minute,
  );
}

/// Reuses the shared Cupertino sheet chrome (same as chat-history date picker).
Future<DateTime?> showGroupLiveScheduleTimePicker(
  BuildContext context, {
  required DateTime initialDateTime,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  final minDate = minimumDate ?? groupLiveScheduleMinimumDate();
  final maxDate = maximumDate ?? DateTime.now().add(const Duration(days: 7));
  final initial = _alignGroupLiveScheduleMinute(
    _clampGroupLiveScheduleTime(
      initialDateTime,
      minimumDate: minDate,
      maximumDate: maxDate,
    ),
  );
  return showAppCupertinoDateTimeSheet(
    context,
    title: AppI18n.of(context).t(
      zhHans: '预计开播时间',
      zhHant: '預計開播時間',
      en: 'Scheduled start',
      ja: '開始予定',
      ko: '예상 시작 시간',
    ),
    initialDateTime: initial,
    minimumDate: minDate,
    maximumDate: maxDate,
    mode: CupertinoDatePickerMode.dateAndTime,
    use24hFormat: true,
    minuteInterval: 1,
  );
}

void showGroupLiveObsGuideSheet(BuildContext context, {String? hint}) {
  final i18n = AppI18n.of(context);
  final steps = <_ObsGuideStep>[
    _ObsGuideStep(
      title: i18n.t(
        zhHans: '下载芯象',
        zhHant: '下載芯象',
        en: 'Download Xinxian',
        ja: '芯象をダウンロード',
        ko: '芯象 다운로드',
      ),
      detail: i18n.t(
        zhHans: '手机直播请用芯象。App Store / 应用商店搜索「芯象」或「芯象导播」，安装后允许相机和麦克风。',
        zhHant: '手機直播請用芯象。App Store / 應用商店搜尋「芯象」或「芯象導播」，安裝後允許相機和麥克風。',
        en: 'Use Xinxian for phone live. Search “Xinxian” in the app store and allow camera and mic.',
        ja: 'スマホ配信は芯象を使用。ストアで「芯象」を検索し、カメラとマイクを許可してください。',
        ko: '휴대폰 라이브는 芯象을 사용하세요. 스토어에서 「芯象」을 검색하고 카메라·마이크를 허용하세요.',
      ),
    ),
    _ObsGuideStep(
      title: i18n.t(
        zhHans: '填写完整推流地址',
        zhHant: '填寫完整推流地址',
        en: 'Paste the full streaming URL',
        ja: '完全な配信URLを入力',
        ko: '전체 推流 주소 입력',
      ),
      detail: i18n.t(
        zhHans:
            '芯象「推流设置 → 本地推流」里只有一个地址框。把本页完整推流地址粘贴进去（也可扫上方二维码）。不要空格、不要换行。此地址请勿分享给他人。',
        zhHant:
            '芯象「推流設定 → 本地推流」裡只有一個地址框。把本頁完整推流地址貼上（也可掃上方二維碼）。不要空格、不要換行。此地址請勿分享給他人。',
        en: 'In Xinxian, go to Stream settings → Local stream and paste this page’s full URL (or scan the QR). No spaces or line breaks. Do not share it.',
        ja: '芯象の「配信設定 → ローカル配信」に本ページの完全なURLを貼り付け（QRスキャンも可）。空白や改行は入れないでください。他人に共有しないでください。',
        ko: '芯象의 「推流 설정 → 로컬 推流」에 이 페이지의 전체 주소를 붙여넣으세요(QR 스캔도 가능). 공백·줄바꿈 없이, 다른 사람과 공유하지 마세요.',
      ),
    ),
    _ObsGuideStep(
      title: i18n.t(
        zhHans: '推荐参数',
        zhHant: '推薦參數',
        en: 'Recommended settings',
        ja: '推奨設定',
        ko: '권장 설정',
      ),
      detail: i18n.t(
        zhHans: '720P、竖屏、普通模式、30FPS、码率 2000～3000Kbps、关键帧 2 秒。第一次直播不要用 1080P。',
        zhHant: '720P、直屏、普通模式、30FPS、碼率 2000～3000Kbps、關鍵幀 2 秒。第一次直播不要用 1080P。',
        en: '720P, portrait, normal mode, 30FPS, 2000–3000Kbps, keyframe 2s. Skip 1080P for the first live.',
        ja: '720P・縦画面・通常モード・30FPS・2000～3000Kbps・キーフレーム2秒。初回は1080Pを使わないでください。',
        ko: '720P, 세로, 일반 모드, 30FPS, 2000～3000Kbps, 키프레임 2초. 첫 방송은 1080P를 쓰지 마세요.',
      ),
    ),
    _ObsGuideStep(
      title: i18n.t(
        zhHans: '开始与结束',
        zhHant: '開始與結束',
        en: 'Start and stop',
        ja: '開始と終了',
        ko: '시작과 종료',
      ),
      detail: i18n.t(
        zhHans: '打开摄像头和麦克风，点击「开始推流」。回 99Chat 能看到画面即成功。结束时先在芯象停止推流，再点本页「结束直播」。',
        zhHant: '打開攝像頭和麥克風，點擊「開始推流」。回 99Chat 能看到畫面即成功。結束時先在芯象停止推流，再點本頁「結束直播」。',
        en: 'Turn on camera and mic, then tap Start Streaming. If 99Chat shows video, you’re live. Stop in Xinxian first, then tap End live here.',
        ja: 'カメラとマイクをオンにして配信開始。99Chat に映像が出れば成功です。終了は先に芯象を停止し、このページで配信終了してください。',
        ko: '카메라와 마이크를 켠 뒤 「推流 시작」. 99Chat에 화면이 보이면 성공입니다. 종료 시 먼저 芯象을 중지한 다음 이 페이지에서 라이브를 종료하세요.',
      ),
    ),
  ];

  showAdaptiveModalSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    desktopMaxWidth: 420,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
      return Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: GroupLiveOnlineLiveScaffold.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTokens.ink300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    i18n.t(
                      zhHans: '芯象配置',
                      zhHant: '芯象配置',
                      en: 'Xinxian setup',
                      ja: '芯象の設定',
                      ko: '芯象 설정',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.ink800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i18n.t(
                      zhHans: '手机直播用芯象，按下面四步即可开播',
                      zhHant: '手機直播用芯象，按下面四步即可開播',
                      en: 'Use Xinxian on phone. Four steps to go live.',
                      ja: 'スマホ配信は芯象で、4ステップで開始できます。',
                      ko: '휴대폰 라이브는 芯象으로, 아래 4단계면 됩니다.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTokens.ink500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _ObsGuideStepTile(index: i + 1, step: steps[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GroupLivePrimaryButton(
                    label: i18n.t(
                      zhHans: '我知道了',
                      zhHant: '我知道了',
                      en: 'Got it',
                      ja: '了解',
                      ko: '확인',
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ObsGuideStep {
  const _ObsGuideStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

class _ObsGuideStepTile extends StatelessWidget {
  const _ObsGuideStepTile({required this.index, required this.step});

  final int index;
  final _ObsGuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: GroupLiveOnlineLiveScaffold.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.detail,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTokens.ink500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GroupLiveScheduleField extends StatelessWidget {
  const GroupLiveScheduleField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.trailing = GroupLiveFieldTrailing.chevron,
  });

  final String label;
  final String value;
  final String? placeholder;
  final VoidCallback? onTap;
  final GroupLiveFieldTrailing trailing;

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isNotEmpty ? value : (placeholder ?? '');
    final isPlaceholder = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTokens.ink500,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFFF1F2F4),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: isPlaceholder
                              ? AppTokens.ink400
                              : AppTokens.ink700,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      _TrailingIcon(trailing: trailing),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GroupLiveFieldTrailing { chevron, calendar, none }

class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({required this.trailing});

  final GroupLiveFieldTrailing trailing;

  @override
  Widget build(BuildContext context) {
    switch (trailing) {
      case GroupLiveFieldTrailing.calendar:
        return const Icon(
          Icons.calendar_today_outlined,
          color: AppTokens.ink400,
          size: 18,
        );
      case GroupLiveFieldTrailing.chevron:
        return const Icon(
          Icons.chevron_right,
          color: AppTokens.ink400,
          size: 22,
        );
      case GroupLiveFieldTrailing.none:
        return const SizedBox.shrink();
    }
  }
}

class GroupLiveRoomNameField extends StatelessWidget {
  const GroupLiveRoomNameField({
    super.key,
    required this.controller,
    required this.enabled,
    this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final hint = hintText ??
        i18n.t(
          zhHans: '请输入直播间名称',
          zhHant: '請輸入直播間名稱',
          en: 'Enter live room name',
          ja: '配信ルーム名を入力',
          ko: '라이브룸 이름 입력',
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t(
              zhHans: '直播间名称',
              zhHant: '直播間名稱',
              en: 'Live room name',
              ja: '配信ルーム名',
              ko: '라이브룸 이름',
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTokens.ink500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLength: 40,
            style: const TextStyle(fontSize: 15, color: AppTokens.ink700),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 15,
                color: AppTokens.ink400,
              ),
              filled: true,
              fillColor: const Color(0xFFF1F2F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
