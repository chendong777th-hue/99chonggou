enum V2TimImageTypesEnum {
  original,
  big,
  small,
}

class HistoryMessageDartConstant {
  static const getCount = 20;

  /// 进入聊天页时直接加载一个完整历史窗口。
  ///
  /// 会话列表长按预览仍保持 15 条；聊天页不能复用预览窗口，否则 SDK
  /// 首轮只返回少量消息时会被误认为完整首屏，短列表又无法触发滚动分页。
  /// 20 条是进页暖窗 / Peek 与完整首屏判定的统一口径（原 40，为减轻转场负载下调）。
  static const initialOpenFetchCount = getCount;

  // ignore: constant_identifier_names
  // 与 SDK V2TIM_IMAGE_TYPE 对齐：0=原图, 1=缩略图, 2=大图
  static const V2_TIM_IMAGE_TYPES = {
    'ORIGINAL': 0,
    'SMALL': 1,
    'BIG': 2,
  };

  static Map<V2TimImageTypesEnum, List<String>> imgPriorMap = {
    V2TimImageTypesEnum.original: oriImgPrior,
    V2TimImageTypesEnum.big: bigImgPrior,
    V2TimImageTypesEnum.small: smallImgPrior,
  };

  // 缩略图优先，大图次之，最后是原图
  static const smallImgPrior = ['SMALL', 'BIG', 'ORIGINAL'];
  // 大图优先，原图次之，最后是缩略图
  static const bigImgPrior = ['BIG', 'ORIGINAL', 'SMALL'];
  // 原图优先，大图次之，最后是缩略图
  static const oriImgPrior = ['ORIGINAL', 'BIG', 'SMALL'];

  // 视频、音频已读状态
  static const int read = 1;
}
