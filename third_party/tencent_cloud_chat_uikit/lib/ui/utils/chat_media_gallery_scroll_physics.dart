import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 图集翻页时相邻页之间的黑缝宽度（逻辑像素），对齐微信相册观感。
///
/// [ExtendedPageController.pageSpacing] 会把间距算进滚动 extent：
/// 停稳时仍全屏贴边，只有滑到一半才露出中间黑缝。
const double kChatMediaGalleryPageSpacing = 20.0;

/// 全屏媒体图集左右翻页物理：比默认 [PageScrollPhysics] 更跟手、落点更干脆。
///
/// Flutter 默认弹簧 `stiffness: 100`，松手后回弹偏软、收束慢，容易有「拖泥带水」感。
/// 这里提高刚度并略增阻尼比，贴近微信 / 系统相册的企业级跟手手感。
///
/// 通过 parent 链把 spring 透传给外层 [PageScrollPhysics]（含 extended_image 的
/// `NeverScrollableScrollPhysics` 包装），无需关闭 `pageSnapping`。
class ChatMediaGalleryScrollPhysics extends ScrollPhysics {
  const ChatMediaGalleryScrollPhysics({super.parent});

  /// 按平台选择边缘回弹 / 夹紧，再套上图集弹簧。
  static ScrollPhysics forPlatform(TargetPlatform platform) {
    final ScrollPhysics edge = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(),
      _ => const ClampingScrollPhysics(),
    };
    return ChatMediaGalleryScrollPhysics(parent: edge);
  }

  static ScrollPhysics of(BuildContext context) {
    return forPlatform(defaultTargetPlatform);
  }

  @override
  ChatMediaGalleryScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ChatMediaGalleryScrollPhysics(parent: buildParent(ancestor));
  }

  /// 默认约 100；提到 360 后 ballistic 收束更快，多图连滑落点更稳。
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 360.0,
        ratio: 1.1,
      );

  /// 轻点抬手速度常达 100–400 px/s。过低会把单击惯性当成翻页。
  @override
  double get minFlingVelocity => 320.0;

  /// 对齐 [kTouchSlop]，避免 3.5px 微抖就进入拖拽。
  @override
  double? get dragStartDistanceMotionThreshold => 18.0;
}
