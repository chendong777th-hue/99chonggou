import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_live/group_live_cast_button.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';

class GroupLiveVideoPlayer extends StatefulWidget {
  const GroupLiveVideoPlayer({super.key, required this.playInfo, this.compact = false, this.fit = BoxFit.contain});
  final GroupLivePlayInfo playInfo;
  final bool compact;
  final BoxFit fit;
  @override State<GroupLiveVideoPlayer> createState() => _GroupLiveVideoPlayerState();
}

class _GroupLiveVideoPlayerState extends State<GroupLiveVideoPlayer> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<String>? _errorSubscription;
  bool _muted = false;
  bool _isFullscreen = false;
  String? _error;
  String get _url {
    final raw = widget.playInfo.fallbackFlvUrl.trim().isNotEmpty ? widget.playInfo.fallbackFlvUrl : widget.playInfo.playUrl;
    return MediaUrlResolver.resolve(raw) ?? raw;
  }
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); _player = Player(); _videoController = VideoController(_player);
    _errorSubscription = _player.stream.error.listen((message) { if (mounted) setState(() => _error = message); }); unawaited(_open());
  }
  Future<void> _open() async {
    final url = _url;
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) { if (mounted) setState(() => _error = 'No playable HTTP-FLV URL'); return; }
    try { await _player.open(Media(url), play: true); } catch (_) { if (mounted) setState(() => _error = 'Playback failed'); }
  }
  @override void didUpdateWidget(covariant GroupLiveVideoPlayer oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.playInfo.fallbackFlvUrl != widget.playInfo.fallbackFlvUrl || oldWidget.playInfo.playUrl != widget.playInfo.playUrl) unawaited(_player.open(Media(_url), play: true)); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_player.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_player.play());
    }
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _errorSubscription?.cancel(); _player.dispose(); super.dispose(); }
  Future<void> _toggleMute() async { _muted = !_muted; await _player.setVolume(_muted ? 0 : 100); if (mounted) setState(() {}); }
  void _toggleFullscreen() { if (_isFullscreen) { Navigator.of(context).pop(); return; } setState(() => _isFullscreen = true); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(backgroundColor: Colors.black, body: SafeArea(child: Stack(fit: StackFit.expand, children: [Video(controller: _videoController, fit: widget.fit), Positioned(top: 8, left: 8, child: IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white), onPressed: () => Navigator.of(context).pop()))]))))).whenComplete(() { if (mounted) setState(() => _isFullscreen = false); }); }
  @override Widget build(BuildContext context) { if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))); return Stack(fit: StackFit.expand, children: [Video(controller: _videoController, fit: widget.fit, controls: NoVideoControls), Positioned(top: 8, left: 8, child: _CompactToolbar(muted: _muted, isFullScreen: _isFullscreen, onToggleMute: () => unawaited(_toggleMute()), onToggleFullscreen: _toggleFullscreen)), if (!widget.compact) const Positioned(top: 8, right: 8, child: GroupLiveCastButton(iconColor: Colors.white, iconSize: 22))]); }
}

class _CompactToolbar extends StatelessWidget {
  const _CompactToolbar({required this.muted, required this.isFullScreen, required this.onToggleMute, required this.onToggleFullscreen});
  final bool muted; final bool isFullScreen; final VoidCallback onToggleMute; final VoidCallback onToggleFullscreen;
  @override Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: muted ? 'Unmute' : 'Mute', icon: Icon(muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18), onPressed: onToggleMute), const GroupLiveCastButton(iconSize: 18), IconButton(tooltip: isFullScreen ? 'Exit fullscreen' : 'Fullscreen', icon: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 18), onPressed: onToggleFullscreen)]));
}
