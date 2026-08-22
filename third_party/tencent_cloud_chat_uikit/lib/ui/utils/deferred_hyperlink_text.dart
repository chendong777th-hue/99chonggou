import 'package:flutter/material.dart';
import 'package:extended_text/extended_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/hyperlink_enrich_scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';

/// First frame: plain [ExtendedText]; later: enriched hyperlink builder.
///
/// Enrichment is queued through [HyperlinkEnrichScheduler] so opening a chat
/// does not run RegExp for every visible bubble on the same frame.
class DeferredHyperlinkText extends StatefulWidget {
  const DeferredHyperlinkText({
    super.key,
    required this.identity,
    required this.displayText,
    required this.textStyle,
    required this.buildEnriched,
    this.isUseQQPackage = true,
    this.isUseTencentCloudChatPackage = true,
    this.isUseTencentCloudChatPackageOldKeys = false,
    this.customEmojiStickerList = const [],
    this.onReadyChanged,
  });

  /// Changes when message key or body text changes — resets deferral.
  final String identity;
  final String displayText;
  final TextStyle textStyle;
  final LinkPreviewText Function() buildEnriched;
  final bool isUseQQPackage;
  final bool isUseTencentCloudChatPackage;
  final bool isUseTencentCloudChatPackageOldKeys;
  final List<CustomEmojiFaceData> customEmojiStickerList;

  /// Test hook: called with ready flag after upgrade.
  final ValueChanged<bool>? onReadyChanged;

  @override
  State<DeferredHyperlinkText> createState() => DeferredHyperlinkTextState();
}

class DeferredHyperlinkTextState extends State<DeferredHyperlinkText> {
  bool _ready = false;
  String? _scheduledIdentity;
  int _scheduleEpoch = 0;

  @visibleForTesting
  bool get isHyperlinkReady => _ready;

  @override
  void initState() {
    super.initState();
    _scheduleEnrich(widget.identity);
  }

  @override
  void didUpdateWidget(covariant DeferredHyperlinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _ready = false;
      _scheduledIdentity = null;
      _scheduleEpoch++;
      _scheduleEnrich(widget.identity);
    }
  }

  @override
  void dispose() {
    _scheduleEpoch++;
    super.dispose();
  }

  void _scheduleEnrich(String identity) {
    if (_scheduledIdentity == identity) {
      return;
    }
    _scheduledIdentity = identity;
    final epoch = _scheduleEpoch;
    HyperlinkEnrichScheduler.instance.schedule(() {
      if (!mounted) return;
      if (epoch != _scheduleEpoch) return;
      if (_scheduledIdentity != identity) return;
      setState(() {
        _ready = true;
      });
      widget.onReadyChanged?.call(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Must not call [widget.buildEnriched] here — that is the hitch win.
      return ExtendedText(
        widget.displayText,
        softWrap: true,
        style: widget.textStyle,
        specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
          isUseQQPackage: widget.isUseQQPackage,
          isUseTencentCloudChatPackage: widget.isUseTencentCloudChatPackage,
          isUseTencentCloudChatPackageOldKeys:
              widget.isUseTencentCloudChatPackageOldKeys,
          customEmojiStickerList: widget.customEmojiStickerList,
          showAtBackground: true,
          checkChatIdMention: false,
        ),
      );
    }
    return widget.buildEnriched()(style: widget.textStyle);
  }
}
