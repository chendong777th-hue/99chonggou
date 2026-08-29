import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';

/// make hero better when slide out
class HeroWidget extends StatefulWidget {
  const HeroWidget(
      {required this.child,
      required this.tag,
      required this.slidePagekey,
      this.slideType = SlideType.onlyImage,
      this.animateCornerRadius = false,
      this.cornerRadius = 10,
      Key? key})
      : super(key: key);
  final Widget child;
  final SlideType slideType;
  final Object tag;
  final GlobalKey<ExtendedImageSlidePageState> slidePagekey;

  /// 飞行时圆角是否随进度从 [cornerRadius] 渐变到 0（打开）/ 0 到 [cornerRadius]（关闭）。
  /// 微信手感：气泡圆角进入全屏时逐渐消失。
  final bool animateCornerRadius;

  /// 源（气泡）圆角，单位 px。仅 [animateCornerRadius] 为 true 时生效。
  final double cornerRadius;
  @override
  _HeroWidgetState createState() => _HeroWidgetState();
}

class _HeroWidgetState extends TIMUIKitState<HeroWidget> {
  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return Hero(
      tag: widget.tag,
      placeholderBuilder: (context, size, child) {
        return SizedBox(width: size.width, height: size.height);
      },
      // 位移只跟路由 animation，不再套一层 easeInOut，避免出手慢半拍。
      createRectTween: (Rect? begin, Rect? end) {
        return mediaPreviewHeroRectTween(
          begin: begin,
          end: end,
          layout: MediaPreviewHeroLayout.maybeOf(context),
        );
      },
      flightShuttleBuilder: (BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext) {
        // 气泡缩略图（contain）与预览页（contain/fitWidth）的 fit 不同。
        // 官方默认用 toHero 会把 contain 图塞进气泡框（先缩出黑边再放大）。
        // push 用 contain 等比铺满插值框：保持缩略图与预览页的内容裁剪
        // 一致，避免飞行结束瞬间从"cover 裁剪"跳到"contain 完整"产生闪一下。
        final Hero fromHero = fromHeroContext.widget as Hero;
        final Widget body = flightDirection == HeroFlightDirection.push
            ? SizedBox.expand(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    clipBehavior: Clip.hardEdge,
                    child: fromHero.child,
                  ),
                ),
              )
            : fromHero.child;

        final slideState = widget.slidePagekey.currentState;
        final bool fixTransform = flightDirection == HeroFlightDirection.pop &&
            widget.slideType == SlideType.onlyImage &&
            slideState != null &&
            (slideState.offset != Offset.zero || slideState.scale != 1.0);

        // 微信手感：圆角随飞行进度从气泡圆角逐渐消失到 0。
        // 打开时 10px → 0；关闭时 0 → 10px。用 AnimatedBuilder 驱动，
        // 前段快后段慢（easeOut），无 bounce/overshoot。
        final bool needsCornerTween = widget.animateCornerRadius &&
            (widget.cornerRadius > 0);
        if (!fixTransform && !needsCornerTween) {
          return body;
        }

        Widget flight = body;
        if (needsCornerTween) {
          flight = AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final t = Curves.easeOut.transform(animation.value);
              final radius = widget.cornerRadius * (1.0 - t);
              return ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: child,
              );
            },
            child: body,
          );
        }

        if (!fixTransform) {
          return flight;
        }

        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext buildContext, Widget? child) {
            return Transform.translate(
              offset: Tween<Offset>(
                begin: Offset.zero,
                end: slideState.offset,
              ).evaluate(animation),
              child: Transform.scale(
                scale: Tween<double>(
                  begin: 1.0,
                  end: slideState.scale,
                ).evaluate(animation),
                child: child,
              ),
            );
          },
          child: flight,
        );
      },
      child: widget.child,
    );
  }
}
