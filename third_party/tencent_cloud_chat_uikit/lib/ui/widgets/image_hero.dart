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
      Key? key})
      : super(key: key);
  final Widget child;
  final SlideType slideType;
  final Object tag;
  final GlobalKey<ExtendedImageSlidePageState> slidePagekey;
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
        // 气泡 cover 与预览 contain 不是同一棵树。官方默认用 toHero 会把
        // contain 图塞进气泡框（先缩出黑边再放大）。推入飞气泡画面并 cover
        // 铺满插值框；返回飞预览页本体（已铺满，不能再套 FittedBox）。
        final Hero fromHero = fromHeroContext.widget as Hero;
        final Widget body = flightDirection == HeroFlightDirection.push
            ? SizedBox.expand(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
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
        if (!fixTransform) {
          return body;
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
                child: body,
              ),
            );
          },
        );
      },
      child: widget.child,
    );
  }
}
