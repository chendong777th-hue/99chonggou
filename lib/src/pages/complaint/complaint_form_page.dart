import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/complaint_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/complaint/complaint_reason_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_signature_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/services/system_media_picker.dart';

/// 投诉表单：原因 + 补充说明 + 相关截图。
///
/// 有截图走 multipart，无截图走 JSON（与后端约定一致）。
class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({
    super.key,
    required this.reportedUserId,
    required this.reason,
    this.reportedUserName,
    this.groupId,
    this.msgKey,
    this.msgSeq,
  });

  final String reportedUserId;
  final String? reportedUserName;
  final String? groupId;
  final ComplaintReason reason;
  final String? msgKey;
  final int? msgSeq;

  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  static const int _maxContentLength = 2000;
  static const int _maxScreenshots = ComplaintApi.maxScreenshots;

  final TextEditingController _contentController = TextEditingController();
  final List<_ComplaintAttachment> _attachments = <_ComplaintAttachment>[];
  bool _submitting = false;

  bool get _isGroup =>
      widget.groupId != null && widget.groupId!.trim().isNotEmpty;

  int get _contentLength => _contentController.text.length;

  bool get _canSubmit => !_submitting;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_refresh);
  }

  @override
  void dispose() {
    _contentController.removeListener(_refresh);
    _contentController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImages() async {
    final remain = _maxScreenshots - _attachments.length;
    if (remain <= 0) {
      ToastUtils.toast(AppI18n.current.format(
        zhHans: '最多上传 {count} 张截图',
        zhHant: '最多上傳 {count} 張截圖',
        en: 'You can upload up to {count} screenshots.',
        ja: 'アップロードできるスクリーンショットは最大 {count} 枚です。',
        ko: '스크린샷은 최대 {count}장까지 업로드할 수 있습니다.',
        vars: {'count': '$_maxScreenshots'},
      ));
      return;
    }

    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !mounted) {
      return;
    }

    final pickedAssets = await SystemMediaPicker.pickImages(maxAssets: remain);
    if (pickedAssets == null || pickedAssets.isEmpty) {
      return;
    }

    final next = <_ComplaintAttachment>[];
    for (final asset in pickedAssets.take(remain)) {
      final file = File(asset.path);
      final bytes = await file.readAsBytes();
      next.add(
        _ComplaintAttachment(
          filename: asset.name?.trim().isNotEmpty == true
              ? asset.name!.trim()
              : 'screenshot.jpg',
          bytes: bytes,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _attachments.addAll(next);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final content = _contentController.text.trim();
      final shots = _attachments
          .map(
            (e) => ComplaintScreenshot(
              filename: e.filename,
              bytes: e.bytes,
            ),
          )
          .toList();
      if (_isGroup) {
        await ComplaintApi.instance.submitGroup(
          groupId: widget.groupId!.trim(),
          reportedUserId: widget.reportedUserId,
          reason: widget.reason,
          content: content.isEmpty ? null : content,
          msgKey: widget.msgKey,
          msgSeq: widget.msgSeq,
          screenshots: shots,
        );
      } else {
        await ComplaintApi.instance.submitC2c(
          reportedUserId: widget.reportedUserId,
          reason: widget.reason,
          content: content.isEmpty ? null : content,
          msgKey: widget.msgKey,
          msgSeq: widget.msgSeq,
          screenshots: shots,
        );
      }
      if (!mounted) {
        return;
      }
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '投诉已提交',
        zhHant: '投訴已提交',
        en: 'Complaint submitted.',
        ja: '通報を送信しました。',
        ko: '신고가 제출되었습니다.',
      ));
      Navigator.of(context).pop(true);
    } on DioError catch (e) {
      if (!mounted) {
        return;
      }
      ToastUtils.toast(_complaintError(e));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '提交失败，请稍后重试',
        zhHant: '提交失敗，請稍後再試',
        en: 'Submission failed. Please try again later.',
        ja: '送信に失敗しました。しばらくしてからもう一度お試しください。',
        ko: '제출에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _complaintError(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      switch (code) {
        case 'CANNOT_REPORT_SELF':
          return AppI18n.current.t(
            zhHans: '不能投诉自己',
            zhHant: '不能投訴自己',
            en: 'You cannot report yourself.',
            ja: '自分自身を通報できません。',
            ko: '자신을 신고할 수 없습니다.',
          );
        case 'INVALID_COMPLAINT_REASON':
          return AppI18n.current.t(
            zhHans: '投诉原因无效',
            zhHant: '投訴原因無效',
            en: 'Invalid complaint reason.',
            ja: '通報理由が無効です。',
            ko: '신고 사유가 올바르지 않습니다.',
          );
        case 'INVALID_INPUT':
          return AppI18n.current.t(
            zhHans: '请检查必填信息后重试',
            zhHant: '請檢查必填資訊後重試',
            en: 'Please check the required fields and try again.',
            ja: '必須項目を確認してもう一度お試しください。',
            ko: '필수 항목을 확인한 뒤 다시 시도해 주세요.',
          );
        case 'CONTENT_TOO_LONG':
          return AppI18n.current.t(
            zhHans: '补充说明过长',
            zhHant: '補充說明過長',
            en: 'The description is too long.',
            ja: '補足説明が長すぎます。',
            ko: '추가 설명이 너무 깁니다.',
          );
        case 'TOO_MANY_SCREENSHOTS':
          return AppI18n.current.format(
            zhHans: '截图最多上传 {count} 张',
            zhHant: '截圖最多上傳 {count} 張',
            en: 'You can upload up to {count} screenshots.',
            ja: 'アップロードできるスクリーンショットは最大 {count} 枚です。',
            ko: '스크린샷은 최대 {count}장까지 업로드할 수 있습니다.',
            vars: {'count': '$_maxScreenshots'},
          );
        case 'INVALID_IMAGE':
          return AppI18n.current.t(
            zhHans: '截图文件无效',
            zhHant: '截圖檔案無效',
            en: 'The screenshot file is invalid.',
            ja: 'スクリーンショットファイルが無効です。',
            ko: '스크린샷 파일이 올바르지 않습니다.',
          );
        case 'UNSUPPORTED_TYPE':
          return AppI18n.current.t(
            zhHans: '仅支持 JPG、PNG、WEBP 图片',
            zhHant: '僅支援 JPG、PNG、WEBP 圖片',
            en: 'Only JPG, PNG, and WEBP images are supported.',
            ja: 'JPG、PNG、WEBP 形式の画像のみ対応しています。',
            ko: 'JPG, PNG, WEBP 이미지 형식만 지원됩니다.',
          );
        case 'FILE_TOO_LARGE':
          return AppI18n.current.t(
            zhHans: '单张截图不能超过 10MB',
            zhHant: '單張截圖不能超過 10MB',
            en: 'Each screenshot must be smaller than 10 MB.',
            ja: 'スクリーンショット1枚あたり10MB未満である必要があります。',
            ko: '스크린샷 한 장의 크기는 10MB를 초과할 수 없습니다.',
          );
        case 'OSS_NOT_CONFIGURED':
          return AppI18n.current.t(
            zhHans: '截图服务暂不可用，请稍后再试',
            zhHant: '截圖服務暫不可用，請稍後再試',
            en: 'Screenshot upload is temporarily unavailable. Please try again later.',
            ja: 'スクリーンショットのアップロードは現在利用できません。しばらくしてからもう一度お試しください。',
            ko: '스크린샷 업로드를 현재 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
          );
        case 'USER_NOT_FOUND':
          return AppI18n.current.t(
            zhHans: '被投诉用户不存在',
            zhHant: '被投訴用戶不存在',
            en: 'The reported user was not found.',
            ja: '通報対象のユーザーが見つかりません。',
            ko: '신고 대상 사용자를 찾을 수 없습니다.',
          );
        case 'GROUP_NOT_FOUND':
          return AppI18n.current.t(
            zhHans: '群不存在或已解散',
            zhHant: '群不存在或已解散',
            en: 'The group was not found or has been dismissed.',
            ja: 'グループが存在しないか解散されています。',
            ko: '그룹이 없거나 해산되었습니다.',
          );
        case 'NOT_GROUP_MEMBER':
          return AppI18n.current.t(
            zhHans: '你已不在该群，无法投诉',
            zhHant: '你已不在該群，無法投訴',
            en: 'You are not a member of this group.',
            ja: 'このグループのメンバーではないため通報できません。',
            ko: '해당 그룹 멤버가 아니어서 신고할 수 없습니다.',
          );
        case 'COMPLAINT_ALREADY_SUBMITTED':
          return AppI18n.current.t(
            zhHans: '24 小时内已投诉过该消息',
            zhHant: '24 小時內已投訴過該訊息',
            en: 'This message was already reported within 24 hours.',
            ja: 'このメッセージは24時間以内に既に通報されています。',
            ko: '해당 메시지는 24시간 내에 이미 신고되었습니다.',
          );
      }
      final message = data['message']?.toString() ?? '';
      if (message.isNotEmpty && message.toLowerCase() != 'ok') {
        return DioErrorMessage.sanitizeUserText(
          message,
          fallback: AppI18n.current.t(
            zhHans: '提交失败，请稍后重试',
            zhHant: '提交失敗，請稍後重試',
            en: 'Submission failed. Please try again later.',
            ja: '送信に失敗しました。しばらくしてからもう一度お試しください。',
            ko: '제출에 실패했습니다. 잠시 후 다시 시도해 주세요.',
          ),
        );
      }
    }
    return AppI18n.current.t(
      zhHans: '提交失败，请稍后重试',
      zhHant: '提交失敗，請稍後再試',
      en: 'Submission failed. Please try again later.',
      ja: '送信に失敗しました。しばらくしてからもう一度お試しください。',
      ko: '제출에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final i18n = AppI18n.of(context);
    final bg = AppColors.card(dark: isDark);
    final line = theme.weakDividerColor ?? AppColors.line(dark: isDark);
    final textColor = theme.darkTextColor ?? AppColors.text(dark: isDark);
    final hintColor = theme.weakTextColor ?? AppColors.subText(dark: isDark);
    // 与个性签名一致：浅色用 inputFill；深色抬高对比避免糊底。
    final inputFill = isDark
        ? const Color(0xFF3A3A3C)
        : (theme.inputFillColor ?? const Color(0xFFF3F3F4));
    final primary = theme.primaryColor ?? AppColors.primaryBlue;
    final reportedName = (widget.reportedUserName?.trim().isNotEmpty == true)
        ? widget.reportedUserName!.trim()
        : widget.reportedUserId;

    void dismissKeyboard() {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: line),
        ),
        title: Text(
          i18n.t(
            zhHans: '投诉',
            zhHant: '投訴',
            en: 'Complaint',
            ja: '通報',
            ko: '신고',
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: dismissKeyboard,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _sectionTitle(
                i18n.t(
                  zhHans: _isGroup ? '投诉对象' : '被投诉人',
                  zhHant: _isGroup ? '投訴對象' : '被投訴人',
                  en: _isGroup ? 'Target' : 'Reported User',
                  ja: _isGroup ? '通報対象' : '通報対象',
                  ko: _isGroup ? '신고 대상' : '신고 대상',
                ),
                textColor,
              ),
                const SizedBox(height: 12),
                Text(
                  reportedName,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                _sectionTitle(
                  i18n.t(
                    zhHans: '投诉原因',
                    zhHant: '投訴原因',
                    en: 'Reason',
                    ja: '通報理由',
                    ko: '신고 사유',
                  ),
                  textColor,
                ),
                const SizedBox(height: 12),
                Text(
                  complaintReasonLabel(i18n, widget.reason),
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                _sectionTitle(
                  i18n.t(
                    zhHans: '补充说明',
                    zhHant: '補充說明',
                    en: 'Additional Details',
                    ja: '補足説明',
                    ko: '추가 설명',
                  ),
                  textColor,
                ),
                const SizedBox(height: 12),
                ProfileSignatureInputField(
                  controller: _contentController,
                  hintText: i18n.t(
                    zhHans: '请描述违规行为（选填）',
                    zhHant: '請描述違規行為（選填）',
                    en: 'Describe the violation (optional)',
                    ja: '違反行為を記入してください（任意）',
                    ko: '위반 행위를 작성해 주세요(선택)',
                  ),
                  maxLength: _maxContentLength,
                  inputFill: inputFill,
                  hintColor: hintColor,
                  textColor: textColor,
                  counterText: '$_contentLength/$_maxContentLength',
                ),
                const SizedBox(height: 28),
                _sectionTitle(
                  i18n.t(
                    zhHans: '相关截图',
                    zhHant: '相關截圖',
                    en: 'Screenshots',
                    ja: '関連スクリーンショット',
                    ko: '관련 스크린샷',
                  ),
                  textColor,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._attachments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              item.bytes,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _attachments.removeAt(index);
                                });
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    if (_attachments.length < _maxScreenshots)
                      GestureDetector(
                        onTap: _pickImages,
                        child: CustomPaint(
                          painter: _DashedRRectPainter(
                            color: hintColor.withValues(alpha: 0.55),
                            radius: 8,
                          ),
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: Icon(
                              Icons.add_rounded,
                              size: 36,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFD1D1D6),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _submitting
                          ? i18n.t(
                              zhHans: '提交中...',
                              zhHant: '提交中...',
                              en: 'Submitting...',
                              ja: '送信中...',
                              ko: '제출 중...',
                            )
                          : i18n.t(
                              zhHans: '提交',
                              zhHant: '提交',
                              en: 'Submit',
                              ja: '送信',
                              ko: '제출',
                            ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComplaintAttachment {
  const _ComplaintAttachment({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}

/// 虚线圆角矩形，对齐设计稿「+」上传框。
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;
  static const double _strokeWidth = 1.2;
  static const double _dashWidth = 4;
  static const double _dashSpace = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
