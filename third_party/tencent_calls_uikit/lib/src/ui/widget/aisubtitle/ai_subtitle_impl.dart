import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tencent_calls_uikit/src/data/user.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';
import 'package:tencent_rtc_sdk/bindings/trtc_cloud_struct.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';

import '../../../extensions/trtc_logger.dart';

class AISubtitle extends StatefulWidget {
  final String userId;

  const AISubtitle({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<AISubtitle> createState() => _AISubtitleState();
}

class _AISubtitleState extends State<AISubtitle> {
  final List<TranslationInfo> _translationInfos = [];
  Timer? _hideTimer;
  bool _isVisible = false;
  final int _showDuration = 8;
  final ScrollController _scrollController = ScrollController();
  
  static const List<String> _languageOrder = [
    "zh", "en", "es", "pt", "fr", "de", "ru", "ar", 
    "ja", "ko", "vi", "ms", "id", "it", "th"
  ];
  
  late var trtcCloudListener = TRTCCloudListener(
    onRecvCustomCmdMsg: (userId, cmdId, seq, message) {
      if (userId.isEmpty || message.isEmpty) {
        return;
      }
      
      try {
        Map messageMap = jsonDecode(message);
        if (messageMap['type'] == AI_MESSAGE_TYPE) {
          String sender = messageMap['sender'];
          Map payload = messageMap['payload'];
          String text = payload['text'];
          String? translationText = payload['translation_text'];
          String roundId = payload['roundid'] ?? '';
          String translationLanguage = payload['translation_language'] ?? '';

          if (roundId.isNotEmpty) {
            _updateTranslationInfo(roundId, sender, text, translationLanguage, translationText);
          }
        }
      } catch(e) {
        TRTCLogger.error("Parse custom message failed: ${e.toString()}");
      }
    },
  );

  void _updateTranslationInfo(String roundId, String sender, String text, String translationLanguage, String? translationText) {
    final index = _translationInfos.indexWhere((info) => info.roundId == roundId);
    
    if (index != -1) {
      final existingInfo = _translationInfos[index];
      existingInfo.sender = sender.contains(AI_TRANSLATION_ROBOT) ? existingInfo.sender : sender;
      existingInfo.text = text.isEmpty ? existingInfo.text : text;
      if (translationLanguage.isNotEmpty && translationText != null && translationText.isNotEmpty) {
        existingInfo.translation[translationLanguage] = translationText;
      }
    } else {
      final translationInfo = TranslationInfo(
        roundId: roundId,
        sender: sender.contains(AI_TRANSLATION_ROBOT) ? '' : sender,
        text: text,
        translation: {},
      );
      if (translationLanguage.isNotEmpty && translationText != null && translationText.isNotEmpty) {
        translationInfo.translation[translationLanguage] = translationText;
      }
      _translationInfos.add(translationInfo);
    }
    
    _updateView();
  }

  void _updateView() {
    setState(() {
      _isVisible = true;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: _showDuration), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  String _sortLanguageType(TranslationInfo message) {
    final translationText = StringBuffer();
    
    for (final language in _languageOrder) {
      if (message.translation.containsKey(language)) {
        translationText.write("[$language]: ${message.translation[language]}\n");
      }
    }
    
    return translationText.toString();
  }

  @override
  void initState() {
    super.initState();
    _startMessageListener();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.dispose();
    _stopMessageListener();
    super.dispose();
  }

  void _startMessageListener() {
    TRTCCloud.sharedInstance().then((trtcCloud) {
      trtcCloud.registerListener(trtcCloudListener);
    });
  }

  void _stopMessageListener() {
    TRTCCloud.sharedInstance().then((trtcCloud) {
      trtcCloud.unRegisterListener(trtcCloudListener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Material(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _translationInfos.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _translationInfos.length,
                    itemBuilder: (context, index) {
                      final info = _translationInfos[index];
                      return FutureBuilder<String?>(
                        future: _getUserDisplayName(info.sender),
                        builder: (context, snapshot) {
                          final displayName = snapshot.data ?? info.sender;
                          final translationText = _sortLanguageType(info);
                          
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _translationInfos.length - 1 ? 0 : 8,
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$displayName:',
                                    style: const TextStyle(
                                      color: Color(0xFFD9CC66),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n${info.text}\n$translationText',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<String?> _getUserDisplayName(String userId) async {
    try {
      final user = _findUserById(userId);
      return user != null ? _getDisplayName(user) : userId;
    } catch (e) {
      TRTCLogger.error('AISubtitle: get user name failed: userId=$userId, error=$e');
      return userId;
    }
  }

  User? _findUserById(String userId) {
    if (userId.isEmpty) return null;

    if (userId == CallState.instance.selfUser.id) {
      return CallState.instance.selfUser;
    }

    for (final user in CallState.instance.remoteUserList) {
      if (user.id == userId) {
        return user;
      }
    }

    return null;
  }

  String _getDisplayName(User info) {
    if (info.remark.isNotEmpty) {
      return info.remark;
    } else if (info.nickname.isNotEmpty) {
      return info.nickname;
    } else {
      return info.id;
    }
  }
}

class TranslationInfo {
  String roundId;
  String sender;
  String text;
  Map<String, String> translation;

  TranslationInfo({
    required this.roundId,
    required this.sender,
    required this.text,
    required this.translation,
  });
}

const int AI_MESSAGE_TYPE = 10000;
const String AI_TRANSLATION_ROBOT = "TAI_Robot";
