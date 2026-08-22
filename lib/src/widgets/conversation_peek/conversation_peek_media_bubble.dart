import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

/// 会话长按预览专用图片/视频缩略图。
///
/// 独立于聊天页媒体气泡：补自己消息的在线 URL、走 SDK download、用
/// CachedNetworkImage；加载中也始终显示图标文案，避免纯灰块。
class ConversationPeekMediaBubble extends StatefulWidget {
  const ConversationPeekMediaBubble({
    super.key,
    required this.message,
  });

  final V2TimMessage message;

  @override
  State<ConversationPeekMediaBubble> createState() =>
      _ConversationPeekMediaBubbleState();
}

class _ConversationPeekMediaBubbleState
    extends State<ConversationPeekMediaBubble> {
  static const double _maxWidth = 220;
  static const double _maxHeight = 260;
  static const Color _placeholderColor = Color(0xFFE8E8E8);

  final MessageService _messageService = serviceLocator<MessageService>();
  final TUIChatGlobalModel _globalModel = serviceLocator<TUIChatGlobalModel>();

  String? _localPath;
  String? _networkUrl;
  bool _isVideo = false;
  bool _loadFailed = false;
  bool _resolving = false;
  int _resolveToken = 0;

  @override
  void initState() {
    super.initState();
    _globalModel.addListener(_onGlobalModelChanged);
    _syncFromMessage(widget.message);
    unawaited(_ensureMediaSource());
    _log(
      'mount msg=${widget.message.msgID} type=${widget.message.elemType} '
      'self=${widget.message.isSelf} local=$_localPath url=$_networkUrl',
    );
  }

  @override
  void didUpdateWidget(covariant ConversationPeekMediaBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.msgID != widget.message.msgID ||
        oldWidget.message.elemType != widget.message.elemType) {
      _loadFailed = false;
      _syncFromMessage(widget.message);
      unawaited(_ensureMediaSource());
    }
  }

  @override
  void dispose() {
    _globalModel.removeListener(_onGlobalModelChanged);
    super.dispose();
  }

  void _log(String message) {
    debugPrint('[PeekMedia] $message');
  }

  void _onGlobalModelChanged() {
    if (!mounted) {
      return;
    }
    final msgID = widget.message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return;
    }
    final location = _globalModel.getFileMessageLocation(msgID).trim();
    if (location.isEmpty || !File(location).existsSync()) {
      return;
    }
    if (location == _localPath) {
      return;
    }
    _log('globalModel location ready path=$location');
    setState(() {
      _localPath = location;
      _loadFailed = false;
    });
  }

  void _syncFromMessage(V2TimMessage message) {
    _isVideo = message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO ||
        (message.videoElem != null && message.imageElem == null);
    _localPath = _resolveLocalPath(message);
    _networkUrl = _resolveNetworkUrl(message);
  }

  String? _resolveLocalPath(V2TimMessage message) {
    if (kIsWeb) {
      return null;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      final saved = _globalModel.getFileMessageLocation(msgID).trim();
      if (saved.isNotEmpty && File(saved).existsSync()) {
        return saved;
      }
    }

    if (_isVideo) {
      for (final path in <String?>[
        message.videoElem?.localSnapshotUrl,
        message.videoElem?.snapshotPath,
        message.videoElem?.localVideoUrl,
        message.videoElem?.videoPath,
      ]) {
        final value = path?.trim() ?? '';
        if (value.isNotEmpty && File(value).existsSync()) {
          return value;
        }
      }
      return null;
    }

    final imageList = message.imageElem?.imageList;
    if (imageList != null) {
      for (final order in const [2, 1, 0]) {
        for (final image in imageList) {
          if (image?.type != order) {
            continue;
          }
          final local = image?.localUrl?.trim() ?? '';
          if (local.isNotEmpty && File(local).existsSync()) {
            return local;
          }
        }
      }
      for (final image in imageList) {
        final local = image?.localUrl?.trim() ?? '';
        if (local.isNotEmpty && File(local).existsSync()) {
          return local;
        }
      }
    }
    final path = message.imageElem?.path?.trim() ?? '';
    if (path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  String? _resolveNetworkUrl(V2TimMessage message) {
    if (_isVideo) {
      for (final candidate in <String?>[
        message.videoElem?.snapshotUrl,
        message.videoElem?.videoUrl,
      ]) {
        final value = candidate?.trim() ?? '';
        if (value.startsWith('http')) {
          return value;
        }
      }
      return null;
    }
    final thumb = ChatImageMessagePrefetch.resolveBubbleThumbUrl(message);
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }
    final list = message.imageElem?.imageList;
    if (list == null) {
      return null;
    }
    for (final image in list) {
      final url = image?.url?.trim() ?? '';
      if (url.startsWith('http')) {
        return url;
      }
    }
    return null;
  }

  Future<void> _ensureMediaSource() async {
    if (_localPath != null) {
      return;
    }
    final msgID = widget.message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      _log('skip resolve: empty msgID');
      return;
    }
    if (_resolving) {
      return;
    }
    final token = ++_resolveToken;
    _resolving = true;
    try {
      // 1) 在线 URL（自己发的消息也会补）。
      if (_networkUrl == null || _networkUrl!.isEmpty) {
        final response = await _messageService.getMessageOnlineUrl(
          msgID: msgID,
          reportError: false,
        );
        if (!mounted || token != _resolveToken) {
          return;
        }
        _log(
          'getMessageOnlineUrl code=${response.code} desc=${response.desc} '
          'hasImage=${response.data?.imageElem != null} '
          'hasVideo=${response.data?.videoElem != null}',
        );
        final data = response.data;
        if (data != null) {
          if (_isVideo) {
            if (data.videoElem != null) {
              widget.message.videoElem = data.videoElem;
            }
          } else if (data.imageElem != null) {
            widget.message.imageElem = data.imageElem;
          }
          unawaited(
            MessageMediaMetadataStore.instance.upsertFromMessage(
              widget.message,
            ),
          );
        }
        final nextUrl = _resolveNetworkUrl(widget.message);
        if (nextUrl != null && nextUrl != _networkUrl) {
          setState(() {
            _networkUrl = nextUrl;
            _loadFailed = false;
          });
        }
      }

      // 2) 已有 HTTP URL（归档图）则直连展示，勿 downloadMessage（SDK 库无此消息会失败）。
      final hasHttpUrl = (_networkUrl ?? '').startsWith('http');
      if (!hasHttpUrl) {
        try {
          if (_isVideo) {
            await _messageService.downloadMessage(
              msgID: msgID,
              messageType: 5,
              imageType: 0,
              isSnapshot: true,
              reportError: false,
            );
          } else {
            await _messageService.downloadMessage(
              msgID: msgID,
              messageType: 3,
              imageType: 1,
              isSnapshot: false,
              reportError: false,
            );
          }
          _log('downloadMessage requested');
        } catch (e) {
          _log('downloadMessage error=$e');
        }
      } else {
        _log('skip downloadMessage: has http url');
      }

      if (!mounted || token != _resolveToken) {
        return;
      }
      final refreshedLocal = _resolveLocalPath(widget.message);
      if (refreshedLocal != null && refreshedLocal != _localPath) {
        setState(() {
          _localPath = refreshedLocal;
          _loadFailed = false;
        });
      }

      if (_localPath == null && (_networkUrl == null || _networkUrl!.isEmpty)) {
        _log('still no media source after resolve');
        setState(() {
          _loadFailed = true;
        });
      }
    } catch (e) {
      _log('ensureMediaSource error=$e');
      if (mounted && token == _resolveToken) {
        setState(() {
          _loadFailed = true;
        });
      }
    } finally {
      _resolving = false;
    }
  }

  Size _displaySize() {
    var width = 0;
    var height = 0;
    if (_isVideo) {
      width = widget.message.videoElem?.snapshotWidth ?? 0;
      height = widget.message.videoElem?.snapshotHeight ?? 0;
    } else {
      final meta = preferChatBubbleImageLayoutMeta(
        widget.message.imageElem?.imageList ?? const [],
      );
      width = meta?.width ?? 0;
      height = meta?.height ?? 0;
    }

    return resolveChatBubbleImageDisplaySize(
      maxWidth: _maxWidth,
      maxHeight: _maxHeight,
      sourceWidth: width > 0 ? width.toDouble() : 3,
      sourceHeight: height > 0 ? height.toDouble() : 4,
    );
  }

  Widget _statusLayer(Size size, {required bool loading}) {
    final label = _isVideo ? '[视频]' : '[图片]';
    return ColoredBox(
      color: _placeholderColor,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _isVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.image_outlined,
                  size: 28,
                  color: const Color(0xFF8E8E93),
                ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(Size size) {
    final local = _localPath;
    if (local != null) {
      return Image.file(
        File(local),
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          _log('Image.file failed path=$local');
          return _statusLayer(size, loading: false);
        },
      );
    }

    final url = _networkUrl;
    if (url != null && url.isNotEmpty && !_loadFailed) {
      final cacheKey = chatBubbleImageCacheKey(
        widget.message.msgID,
        url: url,
      );
      return CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => _statusLayer(size, loading: true),
        errorWidget: (_, __, ___) {
          _log('CachedNetworkImage failed url=$url');
          return _statusLayer(size, loading: false);
        },
      );
    }

    return _statusLayer(size, loading: _resolving && !_loadFailed);
  }

  @override
  Widget build(BuildContext context) {
    final size = _displaySize();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(size),
            if (_isVideo && _localPath != null)
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 40,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
