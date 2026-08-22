// ignore_for_file: unused_import

import 'dart:io';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_image_load_placeholder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/drag_widget.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:video_player/video_player.dart';

typedef BuildContentFunction = Widget Function(BuildContext context);

class TUIKitWidePopup {
  static OverlayEntry? entry;
  static bool isShow = false;

  /// 路由 pop / 离页后移除可能残留的桌面弹层，避免挡住底层列表。
  static void forceDismiss() {
    isShow = false;
    entry?.remove();
    entry = null;
  }

  static showSecondaryConfirmDialog({
    required TUIKitWideModalOperationKey operationKey,
    required BuildContext context,
    required String text,
    required TUITheme theme,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return TUIKitWidePopup.showPopupWindow(
        operationKey: operationKey,
        context: context,
        isDarkBackground: false,
        onCancel: onCancel,
        onConfirm: onConfirm,
        width: 350,
        height: 120,
        child: (onClose) => Container(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Row(
                children: [
                  Icon(Icons.info, color: theme.primaryColor),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(child: Text(text))
                ],
              ),
            ));
  }

  static showPopupWindow({
    /// You could determine this field as `TUIKitWideModalOperationKey.custom` for your own business needs.
    required TUIKitWideModalOperationKey operationKey,
    required BuildContext context,
    required Widget Function(VoidCallback closeFunc) child,
    TUITheme? theme,
    double? width,
    double? height,
    Offset? offset,
    String? initText,
    BorderRadius? borderRadius,
    bool isDarkBackground = true,
    String? title,
    VoidCallback? onSubmit,
    Widget? submitWidget,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
  }) async {
    if (isShow) {
      return;
    }
    isShow = true;

    final TUISelfInfoViewModel selfInfoViewModel = serviceLocator<TUISelfInfoViewModel>();

    if (selfInfoViewModel.globalConfig?.showDesktopModalFunc != null) {
      final res = await selfInfoViewModel.globalConfig!.showDesktopModalFunc!(operationKey, context, child, theme, width, height, offset, initText, borderRadius, isDarkBackground, title, onSubmit, submitWidget, onConfirm, onCancel);

      if (res == true) {
        return;
      }
    }

    final isUseMaterialAlert = (offset == null);
    final effectiveBorderRadius =
        borderRadius ?? const BorderRadius.all(Radius.circular(20));

    // ignore: prefer_function_declarations_over_variables
    final BuildContentFunction buildContent = (BuildContext contentContext) => Container(
      key:UniqueKey(),
      width: width,
      height: height,
      // 子页面（如搜索添加）常带不透明白底 Material；不裁切时会盖住圆角，底部呈直角。
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        color: theme?.wideBackgroundColor ?? const Color(0xFFffffff),
        border: isDarkBackground
            ? Border.all(
                width: 1,
                color: theme?.weakDividerColor ?? const Color(0xFFE8EAED),
              )
            : null,
        boxShadow: (isDarkBackground || isUseMaterialAlert)
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0B1220).withValues(alpha: 0.10),
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: const Color(0xFF0B1220).withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Column(
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(
                color: theme?.wideBackgroundColor ?? Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: effectiveBorderRadius.topLeft,
                  topRight: effectiveBorderRadius.topRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: theme?.darkTextColor ?? const Color(0xFF111827),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        // 有底部 footer 时，标题栏仅关闭；否则保留 header ✓ 提交。
                        final useFooter =
                            onCancel != null || onConfirm != null;
                        if (!useFooter && onSubmit != null) {
                          onSubmit();
                        }
                        isShow = false;
                        if (offset == null) {
                          if (contentContext.mounted) {
                            Navigator.pop(contentContext);
                          }
                        } else {
                          entry?.remove();
                          entry = null;
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: (onCancel != null || onConfirm != null)
                            ? Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: theme?.weakTextColor ??
                                    const Color(0xFF9CA3AF),
                              )
                            : onSubmit != null
                                ? (submitWidget ??
                                    Icon(
                                      Icons.check_rounded,
                                      size: 22,
                                      color: theme?.primaryColor ??
                                          CommonColor.primaryColor,
                                    ))
                                : Icon(
                                    Icons.close_rounded,
                                    size: 22,
                                    color: theme?.weakTextColor ??
                                        const Color(0xFF9CA3AF),
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (title != null)
            Divider(
              height: 1,
              thickness: 1,
              color: (theme?.weakDividerColor ?? const Color(0xFFE8EAED))
                  .withValues(alpha: 0.85),
            ),
          if (height != null && width != null)
            Expanded(child: child(() {
              isShow = false;
              if (isUseMaterialAlert) {
                Navigator.pop(contentContext);
              } else {
                entry?.remove();
                entry = null;
              }
            })),
          if (height == null || width == null)
            child(() {
              isShow = false;
              if (isUseMaterialAlert) {
                Navigator.pop(contentContext);
              } else {
                entry?.remove();
                entry = null;
              }
            }),
          if (onCancel != null || onConfirm != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: (theme?.weakDividerColor ?? const Color(0xFFE8EAED))
                      .withValues(alpha: 0.85),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onCancel != null)
                        TextButton(
                          onPressed: () {
                            // 先回调再关闭，避免 GlobalKey 子树已被 dispose。
                            onCancel();
                            isShow = false;
                            if (isUseMaterialAlert) {
                              if (contentContext.mounted) {
                                Navigator.pop(contentContext);
                              }
                            } else {
                              entry?.remove();
                              entry = null;
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor:
                                theme?.weakTextColor ?? const Color(0xFF6B7280),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(TIM_t("取消")),
                        ),
                      if (onCancel != null && onConfirm != null)
                        const SizedBox(width: 8),
                      if (onConfirm != null)
                        FilledButton(
                          onPressed: () {
                            // 先回调再关闭，保证 currentState?.onSubmit 仍可读。
                            onConfirm();
                            isShow = false;
                            if (isUseMaterialAlert) {
                              if (contentContext.mounted) {
                                Navigator.pop(contentContext);
                              }
                            } else {
                              entry?.remove();
                              entry = null;
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme?.primaryColor ??
                                CommonColor.primaryColor,
                            foregroundColor: theme?.white ?? Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(confirmText ?? TIM_t("确定")),
                        ),
                    ],
                  ),
                ),
              ],
            )
        ],
      ),
    );

    if (isUseMaterialAlert) {
      return showDialog(
          barrierDismissible: true,
          context: context,
          builder: (dialogContext) {
            return WillPopScope(
                child: AlertDialog(
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  titlePadding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  contentPadding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  content: buildContent(dialogContext),
                ),
                onWillPop: () {
                  isShow = false;
                  return Future.value(true);
                });
          });
    }

    if (entry != null) {
      return;
    }

    entry = OverlayEntry(builder: (BuildContext overlayContext) {
      return Material(
        color: Colors.transparent,
        child: TUIKitDragArea(
            backgroundColor: isDarkBackground ? const Color(0x7F000000) : null,
            closeFun: () {
              isShow = false;
              if (entry != null) {
                entry?.remove();
                entry = null;
              }
            },
            initOffset: offset,
            child: buildContent(overlayContext)),
      );
    });
    Overlay.of(context).insert(entry!);
  }

  static void showMedia({
    String? mediaLocalPath,
    String? mediaURL,
    required BuildContext context,
    required VoidCallback onClickOrigin,
    double? aspectRatio,
  }) async {
    assert((mediaLocalPath != null) || (mediaURL != null), "At least one of mediaLocalPath or mediaURL must be provided.");

    String _removeQueryString(String urlString) {
      Uri uri = Uri.parse(urlString);
      Uri cleanUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      );
      return cleanUri.toString();
    }

    final String mediaPath = mediaLocalPath ?? mediaURL ?? "";
    final isLocalResource = mediaLocalPath != null;

    String fileExtension = p.extension(isLocalResource ? mediaPath : _removeQueryString(mediaPath));
    bool isVideo = ['.mp4', '.avi', '.mov', '.flv', '.wmv'].contains(fileExtension);

    VideoPlayerController? videoController;
    ChewieController? chewieController;
    Widget mediaWidget;
    double? aspectRatioFinal = aspectRatio;

    if (isVideo) {
      if (isLocalResource) {
        videoController = VideoPlayerController.file(File(mediaPath));
      } else {
        videoController = VideoPlayerController.networkUrl(Uri.parse(mediaPath));
      }

      await videoController.initialize();
      aspectRatioFinal = videoController.value.aspectRatio;

      chewieController = ChewieController(
        allowFullScreen: false,
        videoPlayerController: videoController,
        aspectRatio: aspectRatioFinal,
        autoPlay: true,
        looping: false,
        autoInitialize: true,
      );

      mediaWidget = Chewie(controller: chewieController);
    } else {
      mediaWidget = isLocalResource
          ? Image.file(File(mediaPath), fit: BoxFit.contain)
          : Image.network(
              mediaPath,
              fit: BoxFit.contain,
              // Web 跨域/自签 HTTPS：走 HTML <img>，避免 fetch 解码 statusCode:0。
              webHtmlElementStrategy: kIsWeb
                  ? WebHtmlElementStrategy.prefer
                  : WebHtmlElementStrategy.never,
              errorBuilder: (context, error, stackTrace) {
                return ChatImageLoadPlaceholder.preview(
                  width: math.min(
                    MediaQuery.sizeOf(context).width * 0.72,
                    320,
                  ),
                  height: math.min(
                    MediaQuery.sizeOf(context).height * 0.42,
                    240,
                  ),
                );
              },
            );
    }

    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) {
          return WillPopScope(
            child: AlertDialog(
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              titlePadding: const EdgeInsets.all(0),
              contentPadding: const EdgeInsets.all(0),
              content: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                          maxHeight: MediaQuery.of(context).size.height * 0.82,
                        ),
                        child: aspectRatioFinal != null ? AspectRatio(aspectRatio: aspectRatioFinal, child: mediaWidget) : mediaWidget,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: onClickOrigin,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 0),
                              child: Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: Colors.grey.shade200,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            // Custom Text Widget with designer baseline
                            Text(
                              TIM_t("在新窗口中打开"),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            onWillPop: () {
              if (isVideo) videoController?.dispose();
              return Future.value(true);
            },
          );
        });
  }
}
