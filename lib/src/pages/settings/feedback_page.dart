import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/api/feedback_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_signature_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/system_media_picker.dart';

class FeedbackPage extends StatefulWidget {
  /// 外层已有标题栏（如桌面弹窗）时隐藏自身 AppBar。
  final bool embedded;

  const FeedbackPage({super.key, this.embedded = false});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const int _maxContentLength = 2000;
  static const int _maxScreenshots = 5;

  final TextEditingController _contentController = TextEditingController();

  FeedbackType _selectedType = FeedbackType.suggestion;
  final List<_FeedbackAttachment> _attachments = <_FeedbackAttachment>[];
  bool _submitting = false;

  String _feedbackTypeLabel(FeedbackType type, AppI18n i18n) {
    switch (type) {
      case FeedbackType.suggestion:
        return i18n.t(
          zhHans: '建议',
          zhHant: '建議',
          en: 'Suggestion',
          ja: '提案',
          ko: '제안',
        );
      case FeedbackType.bug:
        return i18n.t(
          zhHans: '错误',
          zhHant: '錯誤',
          en: 'Bug',
          ja: '不具合',
          ko: '오류',
        );
      case FeedbackType.other:
        return i18n.t(
          zhHans: '其他',
          zhHant: '其他',
          en: 'Other',
          ja: 'その他',
          ko: '기타',
        );
    }
  }

  bool get _canSubmit =>
      !_submitting && _contentController.text.trim().isNotEmpty;

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
    if (mounted) setState(() {});
  }

  Future<void> _pickImages() async {
    final remain = _maxScreenshots - _attachments.length;
    if (remain <= 0) {
      _showMessage(AppI18n.current.format(
        zhHans: '最多上传 {count} 张截图',
        zhHant: '最多上傳 {count} 張截圖',
        en: 'You can upload up to {count} screenshots.',
        ja: 'アップロードできるスクリーンショットは最大 {count} 枚です。',
        ko: '스크린샷은 최대 {count}장까지 업로드할 수 있습니다.',
        vars: {'count': _maxScreenshots.toString()},
      ));
      return;
    }

    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !mounted) return;

    final pickedAssets = await SystemMediaPicker.pickImages(maxAssets: remain);
    if (pickedAssets == null || pickedAssets.isEmpty) return;

    final next = <_FeedbackAttachment>[];
    for (final asset in pickedAssets.take(remain)) {
      final file = File(asset.path);
      final bytes = await file.readAsBytes();
      next.add(
        _FeedbackAttachment(
          filename: asset.name?.trim().isNotEmpty == true
              ? asset.name!.trim()
              : 'screenshot.jpg',
          bytes: bytes,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _attachments.addAll(next);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _submitting = true);
    try {
      await FeedbackApi.instance.submit(
        type: _selectedType,
        content: _contentController.text.trim(),
        screenshots: _attachments
            .map(
              (e) => FeedbackScreenshot(
                filename: e.filename,
                bytes: e.bytes,
              ),
            )
            .toList(),
      );
      if (!mounted) return;
      _showMessage(AppI18n.current.t(
        zhHans: '反馈已提交',
        zhHant: '回饋已提交',
        en: 'Feedback submitted.',
        ja: 'フィードバックを送信しました。',
        ko: '의견이 제출되었습니다.',
      ));
      Navigator.of(context).maybePop();
    } on DioError catch (e) {
      if (!mounted) return;
      _showMessage(_feedbackError(e));
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppI18n.current.t(
        zhHans: '提交失败，请稍后重试',
        zhHant: '提交失敗，請稍後再試',
        en: 'Submission failed. Please try again later.',
        ja: '送信に失敗しました。しばらくしてからもう一度お試しください。',
        ko: '제출에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _feedbackError(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      switch (code) {
        case 'INVALID_INPUT':
          return AppI18n.current.t(
            zhHans: '请输入反馈内容',
            zhHant: '請輸入回饋內容',
            en: 'Please enter your feedback.',
            ja: 'フィードバック内容を入力してください。',
            ko: '의견 내용을 입력해 주세요.',
          );
        case 'INVALID_FEEDBACK_TYPE':
          return AppI18n.current.t(
            zhHans: '反馈类型无效',
            zhHant: '回饋類型無效',
            en: 'Invalid feedback type.',
            ja: 'フィードバック種別が無効です。',
            ko: '의견 유형이 올바르지 않습니다.',
          );
        case 'CONTENT_TOO_LONG':
          return AppI18n.current.t(
            zhHans: '反馈内容过长',
            zhHant: '回饋內容過長',
            en: 'Your feedback is too long.',
            ja: 'フィードバック内容が長すぎます。',
            ko: '의견 내용이 너무 깁니다.',
          );
        case 'TOO_MANY_SCREENSHOTS':
          return AppI18n.current.t(
            zhHans: '截图最多上传 5 张',
            zhHant: '截圖最多上傳 5 張',
            en: 'You can upload up to 5 screenshots.',
            ja: 'アップロードできるスクリーンショットは最大5枚です。',
            ko: '스크린샷은 최대 5장까지 업로드할 수 있습니다.',
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
      }
      final message = data['message']?.toString() ?? '';
      if (message.isNotEmpty) {
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

  void _showMessage(String text) {
    ToastUtils.toast(text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    // 与个性签名 / 投诉说明一致：浅色用 inputFill，深色抬高对比。
    final inputFill = dark
        ? const Color(0xFF3A3A3C)
        : (theme.inputFillColor ?? const Color(0xFFF3F3F4));
    final hintColor = theme.weakTextColor ?? helperColor;
    final textColor = theme.darkTextColor ?? AppColors.text(dark: dark);
    final i18n = AppI18n.of(context);
    final contentLength = _contentController.text.length;

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.card(dark: dark),
      appBar: widget.embedded
          ? null
          : AppBar(
              elevation: 0,
              centerTitle: true,
              backgroundColor: AppColors.card(dark: dark),
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: canPop,
              leading: canPop
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.primaryBlue,
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.6),
                child: Container(
                  height: 0.6,
                  color: AppColors.line(dark: dark),
                ),
              ),
              title: Text(
                i18n.t(
                  zhHans: '意见反馈',
                  zhHant: '意見回饋',
                  en: 'Feedback',
                  ja: 'フィードバック',
                  ko: '의견 보내기',
                ),
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.t(
                  zhHans: '反馈类型',
                  zhHant: '回饋類型',
                  en: 'Feedback Type',
                  ja: 'フィードバック種別',
                  ko: '의견 유형',
                ),
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: FeedbackType.values.map((type) {
                  final selected = type == _selectedType;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 92,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryBlue
                            : (dark
                                ? const Color(0xFF2A2D33)
                                : const Color(0xFFF2F4F7)),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Text(
                        _feedbackTypeLabel(type, i18n),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.text(dark: dark),
                          fontSize: 16,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 34),
              Text(
                i18n.t(
                  zhHans: '反馈内容',
                  zhHant: '回饋內容',
                  en: 'Feedback Details',
                  ja: 'フィードバック内容',
                  ko: '의견 내용',
                ),
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ProfileSignatureInputField(
                controller: _contentController,
                hintText: i18n.t(
                  zhHans: '请尽量详细描述你要反馈的问题，以便我们尽快为你解决',
                  zhHant: '請盡量詳細描述你要回饋的問題，以便我們盡快協助處理',
                  en: 'Please describe the issue in as much detail as possible so we can help you faster.',
                  ja: 'できるだけ詳しく問題をご記入ください。より早く対応するための参考になります。',
                  ko: '더 빠르게 도와드릴 수 있도록 문제를 가능한 한 자세히 작성해 주세요.',
                ),
                maxLength: _maxContentLength,
                inputFill: inputFill,
                hintColor: hintColor,
                textColor: textColor,
                counterText: '$contentLength/$_maxContentLength',
              ),
              const SizedBox(height: 26),
              Text(
                i18n.t(
                  zhHans: '相关截图',
                  zhHant: '相關截圖',
                  en: 'Screenshots',
                  ja: '関連スクリーンショット',
                  ko: '관련 스크린샷',
                ),
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            item.bytes,
                            width: 92,
                            height: 92,
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
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppColors.card(dark: dark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.line(dark: dark),
                            width: 1,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 38,
                          color: AppColors.text(dark: dark),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 42),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line(dark: dark),
                    disabledForegroundColor: helperColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackAttachment {
  const _FeedbackAttachment({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}
