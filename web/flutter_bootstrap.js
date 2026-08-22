{{flutter_js}}
{{flutter_build_config}}

// 主字体走 pubspec 内置 NotoSansSC；缺字切片仍按需从 gstatic 拉取。
// 留空会导致 dom.dart 报 “Failed to parse fallback font Noto Sans SC …”。
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'https://fonts.gstatic.com/s/',
  },
});
