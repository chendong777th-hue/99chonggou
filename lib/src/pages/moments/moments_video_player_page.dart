import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';

class MomentsVideoPlayerPage extends StatefulWidget {
  const MomentsVideoPlayerPage({
    super.key,
    required this.source,
    this.title,
  });

  final String source;
  final String? title;

  static Future<void> push(
    BuildContext context, {
    required String source,
    String? title,
  }) {
    return Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsVideoPlayerPage(
          source: source,
          title: title,
        ),
      ),
    );
  }

  @override
  State<MomentsVideoPlayerPage> createState() => _MomentsVideoPlayerPageState();
}

class _MomentsVideoPlayerPageState extends State<MomentsVideoPlayerPage> {
  BetterPlayerController? _controller;
  String? _sourceKey;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String? _resolveSource(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return MediaUrlResolver.resolve(trimmed) ?? trimmed;
    }
    return trimmed;
  }

  Map<String, String>? _headersFor(String source) {
    if (!source.startsWith('http')) {
      return null;
    }
    return MediaUrlResolver.authHeadersFor(source);
  }

  void _initController() {
    final raw = widget.source;
    final resolved = _resolveSource(raw);
    if (resolved == null || resolved.isEmpty) {
      return;
    }
    if (_sourceKey == resolved && _controller != null) {
      return;
    }
    _sourceKey = resolved;

    _controller?.dispose();
    final isLocalFile = !resolved.startsWith('http');
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        aspectRatio: 16 / 9,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlayPause: true,
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        isLocalFile
            ? BetterPlayerDataSourceType.file
            : BetterPlayerDataSourceType.network,
        resolved,
        headers: _headersFor(resolved),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initController();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title?.trim().isNotEmpty == true ? widget.title! : '视频',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
      ),
      body: Center(
        child: controller == null
            ? Text(
                '无法播放视频',
                style: TextStyle(color: AppColors.subText(dark: dark)),
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(controller: controller),
              ),
      ),
    );
  }
}
