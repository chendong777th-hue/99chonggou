// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/get_group_message_read_member_list_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_message_read_member_list.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_message_read_member_list.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_extension_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_extension_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_online_url.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_online_url.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_reaction_user_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_reaction_user_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_receive_message_opt_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_message_manager.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_message_manager_dummy.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

class V2TIMMessageManager {
  /// 添加高级消息的事件监听器
  ///
  Future<void> addAdvancedMsgListener({
    required V2TimAdvancedMsgListener listener,
  }) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.addAdvancedMsgListener(
        listener: listener,
      );
    }

    TIMMessageManager.instance.addAdvancedMsgListener(listener);
    return Future.value();
  }

  /// 移除高级消息监听器
  ///
  Future<void> removeAdvancedMsgListener({V2TimAdvancedMsgListener? listener}) {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.removeAdvancedMsgListener(
        listener: listener,
      );
    }

    TIMMessageManager.instance.removeAdvancedMsgListener(listener: listener);
    return Future.value();
  }

  /// 创建文本消息
  ///
  /// [text] 要传递的文本
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createTextMessage(
      {required String text}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createTextMessage(text: text);
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createTextMessage(text: text);
    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
  }

  /// 创建文本消息，并且可以附带 @ 提醒功能。提醒消息仅适用于在群组中发送的消息
  ///
  /// [text] 文本
  ///
  /// [atUserList]	需要 @ 的用户列表，如果需要 @ALL，请传入 V2TimGroupAtInfo.AT_ALL_TAG 常量字符串。举个例子，假设该条文本消息希望@提醒 denny 和 lucy 两个用户，同时又希望@所有人，atUserList 传 "denny","lucy",V2TimGroupAtInfo.AT_ALL_TAG 数组
  ///
  /// 注意：
  /// - 默认情况下，最多支持 @ 30个用户，超过限制后，消息会发送失败。
  /// - atUserList 的总数不能超过默认最大数，包括 @ALL。
  /// - 直播群（AVChatRoom）不支持发送 @ 消息。
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createTextAtMessage({
    required String text,
    required List<String> atUserList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createTextAtMessage(
        text: text,
        atUserList: atUserList,
      );
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createTextAtMessage(
      text: text,
      atUserList: atUserList,
    );

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
  }

  /// 创建自定义消息
  ///
  /// [data] 自定义消息内容
  ///
  /// [description] 自定义消息描述信息，做离线 Push 时文本展示。
  ///
  /// [extension] 离线Push时扩展字段信息。
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createCustomMessage({
    required String data,
    String desc = "",
    String extension = "",
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .createCustomMessage(data: data, extension: extension, desc: desc);
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createCustomMessage(
        data: data,
        extension: extension,
        desc: desc
    );

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
  }


  /// 创建图片消息（图片文件最大支持 28 MB）
  ///
  /// [imagePath] 图片路径（只有发送方可以获取到）
  ///
  /// [inputElement] 用于选择图片的 DOM 节点(web端必填)
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createImageMessage({
    required String imagePath,
    dynamic inputElement,
    String? imageName,
  }) async {
    if (await pathExits(imagePath)) {
      if (kIsWeb) {
        return TencentCloudChatSdkPlatform.instance.createImageMessage(
          imagePath: imagePath,
          inputElement: inputElement,
          imageName: imageName,
        );
      }

      V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createImageMessage(
        imagePath: imagePath,
        imageName: imageName,
      );

      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
    }

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromJson({
      "code": -5,
      "desc": "imagePath is not found",
      "data": V2TimMsgCreateInfoResult.fromJson(
        {},
      ),
    });
  }

  /// 创建音频消息
  ///
  /// [soundPath] 音频文件地址
  ///
  /// [duration] 时长
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createSoundMessage({
    required String soundPath,
    required int duration,
  }) async {
    if (await pathExits(soundPath)) {
      if (kIsWeb) {
        return TencentCloudChatSdkPlatform.instance.createSoundMessage(
          soundPath: soundPath,
          duration: duration,
        );
      }

      V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createSoundMessage(
        soundPath: soundPath,
        duration: duration,
      );

      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
    }
    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromJson({
      "code": -5,
      "desc": "soundPath is not found",
      "data": V2TimMsgCreateInfoResult.fromJson(
        {},
      ),
    });
  }

  /// 创建视频消息
  ///
  /// [videoFilePath] 路径
  ///
  /// [type] 视频类型，如 mp4 mov 等
  ///
  /// [duration]	视频时长，单位 s
  ///
  /// [snapshotPath]	视频封面图片路径
  ///
  /// [inputElement] 用于选择视频文件的 DOM 节点 （只有[web端](https://web.sdk.qcloud.com/im/doc/zh-cn/SDK.html#createVideoMessage)用到且必填）
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createVideoMessage({
    required String videoFilePath,
    required String type,
    required int duration,
    required String snapshotPath,
    dynamic inputElement,
  }) async {
    if (await pathExits(videoFilePath) && await pathExits(snapshotPath)) {
      if (kIsWeb) {
        return TencentCloudChatSdkPlatform.instance.createVideoMessage(
          videoFilePath: videoFilePath,
          type: type,
          duration: duration,
          snapshotPath: snapshotPath,
          inputElement: inputElement,
        );
      }

      V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createVideoMessage(
        videoFilePath: videoFilePath,
        type: type,
        duration: duration,
        snapshotPath: snapshotPath,
      );

      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
    }

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromJson({
      "code": -5,
      "desc": "videoFilePath or snapshotPath is not found",
      "data": V2TimMsgCreateInfoResult.fromJson(
        {},
      ),
    });
  }

  /// 创建文件消息
  ///
  /// [filePath] 文件路径
  ///
  /// [fileName] 文件名称
  ///
  /// [inputElement] 用于选择文件的 DOM 节点（[web](https://web.sdk.qcloud.com/im/doc/zh-cn/SDK.html#createFileMessage)端使用，且必填）
  ///
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createFileMessage({
    required String filePath,
    required String fileName,
    dynamic inputElement,
  }) async {
    if (await pathExits(filePath)) {
      if (kIsWeb) {
        return TencentCloudChatSdkPlatform.instance.createFileMessage(
          filePath: filePath,
          fileName: fileName,
          inputElement: inputElement,
        );
      }

      V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createFileMessage(
        filePath: filePath,
        fileName: fileName,
      );

      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
    }

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromJson({
      "code": -5,
      "desc": "filePath is not found",
      "data": V2TimMsgCreateInfoResult.fromJson(
        {},
      ),
    });
  }

  /// 创建位置信息
  ///
  /// [longitude] 经度，发送消息时设置
  ///
  /// [latitude] 纬度，发送消息时设置
  ///
  /// [desc] 地理位置描述信息
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createLocationMessage({
    required String desc,
    required double longitude,
    required double latitude,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createLocationMessage(
        desc: desc,
        longitude: longitude,
        latitude: latitude,
      );
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createLocationMessage(
      desc: desc,
      longitude: longitude,
      latitude: latitude,
    );

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
  }

  /// 创建表情消息
  ///
  /// [index]	表情索引
  ///
  /// [data]	自定义数据
  ///
  /// 备注：
  /// ```
  /// SDK 并不提供表情包，如果开发者有表情包，可使用 index 存储表情在表情包中的索引，或者使用 data 存储表情映射的字符串 key，这些都由用户自定义，SDK 内部只做透传。
  /// ```
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createFaceMessage({
    required int index,
    required String data,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createFaceMessage(
        index: index,
        data: data,
      );
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createFaceMessage(
      index: index,
      data: data,
    );

    return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
  }

  /// 创建合并消息
  ///
  /// 我们在收到一条合并消息的时候，通常会在聊天界面这样显示：
  /// ```
  /// |vinson 和 lynx 的聊天记录 | – title （标题）
  ///
  /// |vinson：新版本 SDK 计划什么时候上线呢？ | – abstract1 （摘要信息1）
  ///
  /// |lynx：计划下周一，具体时间要看下这两天的系统测试情况.. | – abstract2 （摘要信息2）
  ///
  /// |vinson：好的. | – abstract3 （摘要信息3）
  /// ```
  /// 聊天界面通常只会展示合并消息的标题和摘要信息，完整的转发消息列表，需要用户主动点击转发消息 UI 后再获取。
  ///
  /// 多条被转发的消息可以被创建成一条合并消息 V2TIMMessage，然后调用 sendMessage 接口发送，实现步骤如下：
  /// 1. 调用 createMergerMessage 创建一条合并消息 V2TIMMessage。
  /// 2. 调用 sendMessage 发送转发消息 V2TIMMessage。
  ///
  /// 收到合并消息解析步骤：
  /// 1. 通过 V2TIMMessage 获取 mergerElem。
  /// 2. 通过 mergerElem 获取 title 和 abstractList UI 展示。
  /// 3. 当用户点击摘要信息 UI 的时候，调用 downloadMessageList 接口获取转发消息列表。
  ///
  /// [messageList]	消息列表（最大支持 300 条，消息对象必须是 V2TIM_MSG_STATUS_SEND_SUCC 状态，消息类型不能为 V2TIMGroupTipsElem）。
  ///
  /// [msgIDList]  消息 ID 列表，**待废弃**，请使用 messageList 参数。
  ///
  /// [title]	合并消息的来源，比如 "vinson 和 lynx 的聊天记录"、"xxx 群聊的聊天记录"。
  ///
  /// [abstractList]	合并消息的摘要列表(最大支持 5 条摘要，每条摘要的最大长度不超过 100 个字符),不同的消息类型可以设置不同的摘要信息，比如: 文本消息可以设置为：sender：text，图片消息可以设置为：sender：[图片]，文件消息可以设置为：sender：[文件]。
  ///
  /// [compatibleText]	合并消息兼容文本，低版本 SDK 如果不支持合并消息，默认会收到一条文本消息，文本消息的内容为 compatibleText， 该参数不能为 null。
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createMergerMessage({
    List<V2TimMessage>? messageList,
    List<String>? msgIDList,
    required String title,
    required List<String> abstractList,
    required String compatibleText,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createMergerMessage(
          msgIDList: msgIDList,
          title: title,
          abstractList: abstractList,
          compatibleText: compatibleText);
    }

    return TIMMessageManager.instance.createMergerMessage(
        msgList: messageList,
        msgIDList: msgIDList,
        title: title,
        abstractList: abstractList,
        compatibleText: compatibleText
    );
  }

  /// 创建转发消息
  ///
  /// 如果需要转发一条消息，不能直接调用 sendMessage 接口发送原消息，需要先 createForwardMessage 创建一条转发消息再发送。
  ///
  /// [message] 待转发的消息对象，消息状态必须为 [MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC]，消息类型不能为 [V2TIMGroupTipsElem]。如果传入该参数，则 msgID 参数无效。
  ///
  /// [msgID] **待废弃**，请使用 [message] 参数。
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createForwardMessage(
      {V2TimMessage? message, String? msgID, String? webMessageInstance}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createForwardMessage(
          msgID: msgID, webMessageInstance: webMessageInstance);
    }

    return TIMMessageManager.instance.createForwardMessage(message: message, msgID: msgID);
  }

  /// 如果您需要在群内给指定群成员列表发消息，可以创建一条定向群消息，定向群消息只有指定群成员才能收到。
  ///
  /// 请注意：
  /// - 原始消息对象不支持群 @ 消息。
  /// - 社群（Community）和直播群（AVChatRoom）不支持发送定向群消息。
  /// - 定向群消息默认不计入群会话的未读计数。
  /// - web目前不支持此消息
  Future<V2TimValueCallback<V2TimMsgCreateInfoResult>> createTargetedGroupMessage({
    V2TimMessage? message,
    String? id,
    required List<String> receiverList
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
        .createTargetedGroupMessage(id: id, receiverList: receiverList);
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createTargetedGroupMessage(
        message: message,
        id: id ?? "",
        receiverList: receiverList);

    if (result.messageInfo != null) {
      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromObject(result);
    } else {
      return V2TimValueCallback<V2TimMsgCreateInfoResult>.fromBool(false, "param is invalid");
    }
  }

  /// 创建带 @ 标记的群消息
  ///
  /// [message]  原始消息对象
  ///
  /// [createdMsgID]  创建消息的 id，**待废弃**。请直接传入通过 createXXXMessage 返回的消息对象给 [message] 参数。
  ///
  /// [atUserList]  需要 @ 的用户列表，如果需要 @ALL，请传入 V2TimGroupAtInfo.AT_ALL_TAG 常量字符串。
  ///
  /// 注意：
  /// - 默认情况下，最多支持 @ 30个用户，超过限制后，消息会发送失败。
  /// - atUserList 的总数不能超过默认最大数，包括 @ALL。
  /// - 直播群（AVChatRoom）不支持发送 @ 消息。
  Future<V2TimValueCallback<V2TimMessage>> createAtSignedGroupMessage({
    V2TimMessage? message,
    String? createdMsgID,
    required List<String> atUserList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createAtSignedGroupMessage(
        createdMsgID: createdMsgID,
        atUserList: atUserList,
      );
    }

    V2TimMsgCreateInfoResult? result = TIMMessageManager.instance.createAtSignedGroupMessage(
      message: message,
      createdMsgID: createdMsgID ?? "",
      atUserList: atUserList,
    );

    if (result.messageInfo != null) {
      return V2TimValueCallback<V2TimMessage>.fromObject(result.messageInfo!);
    } else {
      return V2TimValueCallback<V2TimMessage>.fromBool(false, "param is invalid");
    }
  }

  /// 创建引用消息
  ///
  /// 如果您需要发送一条引用了其他消息的消息，可以调用该接口创建引用消息。
  ///
  /// [message]  原始消息对象，需要通过对应的 createXXXMessage 接口进行创建。
  ///
  /// [quotedMessage]  被引用的消息对象
  ///
  /// 返回引用消息对象
  Future<V2TimValueCallback<V2TimMessage>> createQuoteMessage({
    required V2TimMessage message,
    required V2TimMessage quotedMessage,
  }) async {
    if (kIsWeb) {
      return V2TimValueCallback<V2TimMessage>.fromBool(false, "createQuoteMessage is not supported on web");
    }

    V2TimMsgCreateInfoResult result = TIMMessageManager.instance.createQuoteMessage(
      message: message,
      quotedMessage: quotedMessage,
    );

    if (result.messageInfo != null) {
      return V2TimValueCallback<V2TimMessage>.fromObject(result.messageInfo!);
    } else {
      return V2TimValueCallback<V2TimMessage>.fromBool(false, "param is invalid");
    }
  }

  /// 添加多Element消息。**待废弃**
  ///
  /// 注意 4.0.3 以及之后版本支持，web 版本不支持
  ///
  /// ```
  ///
  /// ```
  Future<V2TimValueCallback<V2TimMessage>> appendMessage({
    required String createMessageBaseId,
    required String createMessageAppendId,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.appendMessage(
        createMessageAppendId: createMessageAppendId,
        createMessageBaseId: createMessageBaseId,
      );
    }

    V2TimMessage message = TIMMessageManager.instance.appendMessage(
      createMessageAppendId: createMessageAppendId,
      createMessageBaseId: createMessageBaseId,
    );

    return V2TimValueCallback<V2TimMessage>.fromObject(message);
  }

  /// 发送消息
  ///
  /// [message]  消息对象，请传入通过 createXXXMessage 返回结果中的消息对象。并且可以设置 [message] 中的 isExcludedFromUnreadCount/isExcludedFromLastMessage/isSupportMessageExtension/isExcludedFromContentModeration/needReadReceipt/cloudCustomData/localCustomData/isDisableCloudMessagePreHook/isDisableCloudMessagePostHook 等参数。如果接口中也传了这些参数，则以接口参数为准。
  ///
  /// [onSyncMsgID]  调用接口后会立即生成 msgID 并同步触发该回调（早于 Future 完成），可用于提前展示消息到界面。该 msgID 作为消息唯一标识。
  ///
  /// [id]  **待废弃** 创建消息 id。请直接传入通过 createXXXMessage 返回的消息对象给 [message] 参数。
  ///
  /// [receiver]  消息接收者的 userID, 如果是发送 C2C 单聊消息，只需要指定 receiver 即可。
  ///
  /// [groupID]	目标群组 ID，如果是发送群聊消息，只需要指定 groupID 即可。
  ///
  /// [priority]	 消息优先级，仅针对群聊消息有效。请把重要消息设置为高优先级（比如红包、礼物消息），高频且不重要的消息设置为低优先级（比如点赞消息）。
  ///
  /// [onlineUserOnly]	 是否只有在线用户才能收到，如果设置为 true ，接收方历史消息拉取不到，常被用于实现“对方正在输入”或群组里的非重要提示等弱提示功能，该字段不支持 AVChatRoom。
  ///
  /// [offlinePushInfo]	离线推送时携带的标题和内容。
  Future<V2TimValueCallback<V2TimMessage>> sendMessage({
    @Deprecated("创建消息的 id 参数，待废弃")
    String? id, // 创建消息的 id，待废弃。请直接传入通过 createXXXMessage 返回的消息对象给 [message] 参数。
    V2TimMessage? message,
    void Function(String msgID)? onSyncMsgID,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    OfflinePushInfo? offlinePushInfo,
    bool? isExcludedFromUnreadCount,
    bool? isExcludedFromLastMessage,
    bool? isSupportMessageExtension,
    bool? isExcludedFromContentModeration,
    bool? needReadReceipt,
    String? cloudCustomData, // 云自定义消息字段，只能在消息发送前添加
    String? localCustomData,
    bool? isDisableCloudMessagePreHook,
    bool? isDisableCloudMessagePostHook,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.sendMessage(
        id: id,
        receiver: receiver,
        groupID: groupID,
        priority: priority!.index,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        isExcludedFromLastMessage: isExcludedFromLastMessage,
        isSupportMessageExtension: isSupportMessageExtension,
        isExcludedFromContentModeration: isExcludedFromContentModeration,
        offlinePushInfo: offlinePushInfo?.toJson(),
        localCustomData: localCustomData,
        needReadReceipt: needReadReceipt,
        cloudCustomData: cloudCustomData,
        // isDisableCloudMessagePreHook: isDisableCloudMessagePreHook,
        // isDisableCloudMessagePostHook: isDisableCloudMessagePostHook,
      );
    }

    return TIMMessageManager.instance.sendMessage(
      id: id,
      message: message,
      onSyncMsgID: onSyncMsgID,
      receiver: receiver,
      groupID: groupID,
      priority: priority!.index,
      onlineUserOnly: onlineUserOnly,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount,
      isExcludedFromLastMessage: isExcludedFromLastMessage,
      isSupportMessageExtension: isSupportMessageExtension,
      isExcludedFromContentModeration: isExcludedFromContentModeration,
      offlinePushInfo: offlinePushInfo,
      localCustomData: localCustomData,
      needReadReceipt: needReadReceipt,
      cloudCustomData: cloudCustomData,
      isDisableCloudMessagePreHook: isDisableCloudMessagePreHook,
      isDisableCloudMessagePostHook: isDisableCloudMessagePostHook,
    );
  }

  /// 获取合并消息的子消息列表（下载被合并的消息列表）
  ///
  /// [message]  合并消息
  ///
  /// [msgID]  合并消息的 msgID，待废弃，请使用 [message] 参数
  Future<V2TimValueCallback<List<V2TimMessage>>> downloadMergerMessage(
      {V2TimMessage? message, String? msgID, String? webMessageInstance}) async {
        if (kIsWeb) {
          return await TencentCloudChatSdkPlatform.instance.downloadMergerMessage(msgID: msgID);
        }

        return TIMMessageManager.instance.downloadMergerMessage(message: message, msgID: msgID);
  }

  /// 设置用户消息接收选项
  ///
  /// 注意
  /// 请注意:
  /// userIDList 一次最大允许设置 30 个用户。
  /// 该接口调用频率限制为 1s 1次，超过频率限制会报错。
  /// 参数
  /// ```
  /// opt	三种类型的消息接收选项： 0,V2TIMMessage.V2TIM_RECEIVE_MESSAGE：在线正常接收消息，离线时会有厂商的离线推送通知 1, V2TIMMessage.V2TIM_NOT_RECEIVE_MESSAGE：不会接收到消息 2,V2TIMMessage.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE：在线正常接收消息，离线不会有推送通知
  /// userIDList
  ///```
  /// 注意： web不支持该接口
  ///
  Future<V2TimCallback> setC2CReceiveMessageOpt({
    required List<String> userIDList,
    required ReceiveMsgOptEnum opt,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setC2CReceiveMessageOpt(userIDList: userIDList, opt: opt.index);
    }

    return TIMMessageManager.instance.setC2CReceiveMessageOpt(userIDList: userIDList, opt: opt);
  }

  ///查询针对某个用户的 C2C 消息接收选项
  ///
  ///注意： web不支持该接口
  ///
  Future<V2TimValueCallback<List<V2TimReceiveMessageOptInfo>>> getC2CReceiveMessageOpt({
    required List<String> userIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getC2CReceiveMessageOpt(userIDList: userIDList);
    }

    return TIMMessageManager.instance.getC2CReceiveMessageOpt(userIDList: userIDList);
  }

  /// 修改群消息接收选项
  ///
  /// [opt]	消息接收选项：
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE]  在线正常接收消息，离线时会有厂商的离线推送通知
  /// - [ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE]  不会接收到群消息
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE]  在线正常接收消息，离线不会有推送通知
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE_EXCEPT_AT]  在线正常接收消息，离线只推送@消息
  /// - [ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE_EXCEPT_AT]  在线和离线都只接收@消息
  ///
  Future<V2TimCallback> setGroupReceiveMessageOpt({
    required String groupID,
    required ReceiveMsgOptEnum opt,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupReceiveMessageOpt(groupID: groupID, opt: opt.index);
    }

    return TIMMessageManager.instance.setGroupReceiveMessageOpt(groupID: groupID, opt: opt);
  }

  /// 设置全局消息接收选项
  ///
  /// [opt] 全局消息接收选项，支持两种取值：
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE]  在线正常接收消息，离线时会有厂商的离线推送通知，默认为该选项
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE]  在线正常接收消息，离线不会有推送通知，可用于实现消息免打扰功能
  ///
  /// [startHour]  免打扰开始时间：小时，取值范围[0 - 23]
  ///
  /// [startMinute]  免打扰开始时间：分钟，取值范围[0 - 59]
  ///
  /// [startSecond]  免打扰开始时间：秒，取值范围[0 - 59]
  ///
  /// [duration]  免打扰持续时长：单位：秒，取值范围 [0 - 24*60*60].
  Future<V2TimCallback> setAllReceiveMessageOpt({
    required int opt,
    required int startHour,
    required int startMinute,
    required int startSecond,
    required int duration,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setAllReceiveMessageOpt(
          opt: opt,
          startHour: startHour,
          startMinute: startMinute,
          startSecond: startSecond,
          duration: duration);
    }

    return TIMMessageManager.instance.setAllReceiveMessageOpt(
        opt: opt,
        startHour: startHour,
        startMinute: startMinute,
        startSecond: startSecond,
        duration: duration);
  }

  /// 设置全局消息接收选项
  ///
  /// [opt] 全局消息接收选项，支持两种取值：
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE]  在线正常接收消息，离线时会有厂商的离线推送通知，默认为该选项
  /// - [ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE]  在线正常接收消息，离线不会有推送通知，可用于实现消息免打扰功能
  ///
  /// [startTimeStamp]  免打扰开始时间，UTC 时间戳，单位：秒
  ///
  /// [duration]  免打扰持续时长，单位：秒
  Future<V2TimCallback> setAllReceiveMessageOptWithTimestamp({
    required int opt,
    required int startTimeStamp,
    required int duration,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .setAllReceiveMessageOptWithTimestamp(
          opt: opt, startTimeStamp: startTimeStamp, duration: duration);
    }

    return TIMMessageManager.instance
        .setAllReceiveMessageOptWithTimestamp(
        opt: opt, startTimeStamp: startTimeStamp, duration: duration);
  }

  /// 获取全局消息接收选项
  Future<V2TimValueCallback<V2TimReceiveMessageOptInfo>> getAllReceiveMessageOpt() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getAllReceiveMessageOpt();
    }

    return TIMMessageManager.instance.getAllReceiveMessageOpt();
  }

  /// 获取单聊历史消息
  ///
  /// 参数
  ///
  /// [count]	 拉取消息的个数，不宜太多，会影响消息拉取的速度，这里建议一次拉取 20 个
  ///
  /// [lastMsg]	 获取消息的起始消息，如果传 null，起始消息为会话的最新消息
  ///
  /// [lastMsgID]  **待废弃**，请使用 lastMsg
  ///
  /// 注意
  ///
  /// ```
  /// 如果 SDK 检测到没有网络，默认会直接返回本地数据
  /// ```
  ///
  Future<V2TimValueCallback<List<V2TimMessage>>> getC2CHistoryMessageList({
    required String userID,
    required int count,
    V2TimMessage? lastMsg,
    String? lastMsgID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getC2CHistoryMessageList(
          userID: userID, count: count, lastMsgID: lastMsgID);
    }

    if (lastMsg != null) {
      return TIMMessageManager.instance.getC2CHistoryMessageList(userID: userID, count: count, lastMsg: lastMsg);
    } else {
      return TIMMessageManager.instance.getC2CHistoryMessageList(userID: userID, count: count, lastMsgID: lastMsgID);
    }
  }

  /// 获取群组历史消息
  ///
  /// 参数
  ///
  /// [count]	拉取消息的个数，不宜太多，会影响消息拉取的速度，这里建议一次拉取 20 个
  ///
  /// [lastMsg]	获取消息的起始消息，如果传 null，起始消息为会话的最新消息
  ///
  /// [lastMsgID]  **待废弃**，请使用 lastMsg
  ///
  /// 注意
  ///
  /// ```
  /// 如果 SDK 检测到没有网络，默认会直接返回本地数据
  /// 只有会议群（Meeting）才能拉取到进群前的历史消息，直播群（AVChatRoom）消息不存漫游和本地数据库，调用这个接口无效
  /// ```
  ///
  Future<V2TimValueCallback<List<V2TimMessage>>> getGroupHistoryMessageList({
    required String groupID,
    required int count,
    V2TimMessage? lastMsg,
    String? lastMsgID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupHistoryMessageList(
          groupID: groupID, count: count, lastMsgID: lastMsgID);
    }

    if (lastMsg != null) {
      return TIMMessageManager.instance.getGroupHistoryMessageList(
          groupID: groupID, count: count, lastMsg: lastMsg);
    } else {
      return TIMMessageManager.instance.getGroupHistoryMessageList(
          groupID: groupID, count: count, lastMsgID: lastMsgID);
    }
  }

  /// 获取历史消息高级接口
  ///
  /// [getType] 拉取消息类型，可以设置拉取本地、云端更老或者更新的消息（具体类型在[HistoryMessageGetType]类中）
  ///
  /// [lastMsgSeq] 用来表示拉取时的起点，第一次拉取时可以不填或者填 0；
  ///
  /// [lastMsg] 用来表示拉取时的起点，第一次拉取时可以不填；
  ///
  /// [lastMsgID]  **待废弃**，请使用 [lastMsg]
  ///
  /// 请注意：
  /// 当设置从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回。如果无网络，则直接返回本地消息列表。
  /// 只有会议群（Meeting）才能拉取到进群前的历史消息，直播群（AVChatRoom）消息不存漫游和本地数据库，调用这个接口无效
  ///
  /// 关于 [getType]、拉取消息的起始消息、拉取消息的时间范围 的使用说明：
  /// - [getType] 可以用来表示拉取的方向：往消息时间更老的方向 或者 往消息时间更新的方向；
  /// - [lastMsg]/[lastMsgSeq] 用来表示拉取时的起点，第一次拉取时可以不填或者填 0；
  /// - [timeBegin]/[timePeriod] 用来表示拉取消息的时间范围，时间范围的起止时间点与拉取方向 [getType] 有关；
  /// - 当起始消息和时间范围都存在时，结果集可理解成：「单独按起始消息拉取的结果」与「单独按时间范围拉取的结果」 取交集；
  /// - 当起始消息和时间范围都不存在时，结果集可理解成：从当前会话最新的一条消息开始，按照 [getType] 所指定的方向和拉取方式拉取。
  ///
  /// 关于 lastMsg 拉取消息的起始消息：
  /// - 拉取 C2C 消息，只能使用 [lastMsg] 作为消息的拉取起点；如果没有指定 [lastMsg]，默认使用会话的最新消息作为拉取起点
  /// - 拉取 Group 消息时，除了可以使用 [lastMsg] 作为消息的拉取起点外，也可以使用 [lastMsgSeq] 来指定消息的拉取起点，二者的区别在于：
  ///   - 使用 [lastMsg] 作为消息的拉取起点时，返回的消息列表里不包含 [lastMsg]；
  ///   - 使用 [lastMsgSeq] 作为消息拉取起点时，返回的消息列表里包含 [lastMsgSeq] 所表示的消息；
  ///
  /// 在拉取 Group 消息时：
  /// - 如果同时指定了 [lastMsg] 和 [lastMsgSeq]，SDK 优先使用 [lastMsg] 作为消息的拉取起点
  /// - 如果 [lastMsg] 和 [lastMsgSeq] 都未指定，消息的拉取起点分为如下两种情况：
  ///   - 如果设置了拉取的时间范围，SDK 会根据 [timeBegin] 所描述的时间点作为拉取起点
  ///   - 如果未设置拉取的时间范围，SDK 默认使用会话的最新消息作为拉取起点
  ///
  /// 关于拉取消息的时间范围：
  /// - [timeBegin]  表示时间范围的起点；默认为 0，表示从现在开始拉取；UTC 时间戳，单位：秒
  /// - [timePeriod] 表示时间范围的长度；默认为 0，表示不限制时间范围；单位：秒
  /// - 时间范围的方向由参数 getType 决定
  /// - 如果 [getType] 取 V2TIM_GET_CLOUD_OLDER_MSG/V2TIM_GET_LOCAL_OLDER_MSG，表示从 [timeBegin] 开始，过去的一段时间，时间长度由 [timePeriod] 决定
  /// - 如果 [getType] 取 V2TIM_GET_CLOUD_NEWER_MSG/V2TIM_GET_LOCAL_NEWER_MSG，表示从 [timeBegin] 开始，未来的一段时间，时间长度由 [timePeriod] 决定
  /// - 取值范围区间为闭区间，包含起止时间，二者关系如下：
  ///   - 如果 [getType] 指定了朝消息时间更老的方向拉取，则时间范围表示为 【timeBegin-timePeriod, timeBegin】
  ///   - 如果 [getType] 指定了朝消息时间更新的方向拉取，则时间范围表示为 【timeBegin, timeBegin+timePeriod】
  ///
  /// 拉取群组历史消息时，支持按照消息序列号 [messageSeqList] 拉取：
  /// - 仅拉取群组历史消息时有效
  /// - 消息序列号 seq 可以通过 V2TIMMessage 对象的 seq 字段获取；
  /// - 当 [getType] 设置为从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回；如果无网络，则直接返回本地消息列表；
  /// - 当 [getType] 设置为从本地拉取时，直接返回本地的消息列表；
  /// - 当 [getType] 设置为拉取更旧的消息时，消息列表按照时间逆序，也即消息按照时间戳从大往小的顺序排序；
  /// - 当 [getType] 设置为拉取更新的消息时，消息列表按照时间顺序，也即消息按照时间戳从小往大的顺序排序。
  ///
  /// web 端使用该接口，消息都是从远端拉取，不支持lastMsgSeq
  ///
  ///
  Future<V2TimValueCallback<List<V2TimMessage>>> getHistoryMessageList({
    HistoryMsgGetTypeEnum? getType =
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    V2TimMessage? lastMsg,
    String? lastMsgID,
    List<int>? messageTypeList,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getHistoryMessageList(
        getType: getType!.index,
        userID: userID,
        count: count,
        lastMsgID: lastMsgID,
        groupID: groupID,
        lastMsgSeq: lastMsgSeq,
        messageTypeList: messageTypeList ?? [],
        messageSeqList: messageSeqList,
        timeBegin: timeBegin,
        timePeriod: timePeriod,
      );
    }

    return TIMMessageManager.instance.getHistoryMessageList(
        getType: getType,
        userID: userID,
        count: count,
        lastMsg: lastMsg,
        lastMsgID: lastMsgID,
        groupID: groupID,
        lastMsgSeq: lastMsgSeq != -1 ? lastMsgSeq : null,
        messageTypeList: messageTypeList,
        messageSeqList: messageSeqList,
        timeBegin: timeBegin,
        timePeriod: timePeriod,
      );
  }

  /// 获取历史消息高级接口
  ///
  /// [getType] 拉取消息类型，可以设置拉取本地、云端更老或者更新的消息（具体类型在[HistoryMessageGetType]类中）
  ///
  /// [lastMsgSeq] 用来表示拉取时的起点，第一次拉取时可以不填或者填 0；
  ///
  /// [lastMsg] 用来表示拉取时的起点，第一次拉取时可以不填；
  ///
  /// [lastMsgID]  **待废弃**，请使用 [lastMsg]
  ///
  /// 请注意：
  /// 当设置从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回。如果无网络，则直接返回本地消息列表。
  /// 只有会议群（Meeting）才能拉取到进群前的历史消息，直播群（AVChatRoom）消息不存漫游和本地数据库，调用这个接口无效
  ///
  /// 关于 [getType]、拉取消息的起始消息、拉取消息的时间范围 的使用说明：
  /// - [getType] 可以用来表示拉取的方向：往消息时间更老的方向 或者 往消息时间更新的方向；
  /// - [lastMsg]/[lastMsgSeq] 用来表示拉取时的起点，第一次拉取时可以不填或者填 0；
  /// - [timeBegin]/[timePeriod] 用来表示拉取消息的时间范围，时间范围的起止时间点与拉取方向 [getType] 有关；
  /// - 当起始消息和时间范围都存在时，结果集可理解成：「单独按起始消息拉取的结果」与「单独按时间范围拉取的结果」 取交集；
  /// - 当起始消息和时间范围都不存在时，结果集可理解成：从当前会话最新的一条消息开始，按照 [getType] 所指定的方向和拉取方式拉取。
  ///
  /// 关于 lastMsg 拉取消息的起始消息：
  /// - 拉取 C2C 消息，只能使用 [lastMsg] 作为消息的拉取起点；如果没有指定 [lastMsg]，默认使用会话的最新消息作为拉取起点
  /// - 拉取 Group 消息时，除了可以使用 [lastMsg] 作为消息的拉取起点外，也可以使用 [lastMsgSeq] 来指定消息的拉取起点，二者的区别在于：
  ///   - 使用 [lastMsg] 作为消息的拉取起点时，返回的消息列表里不包含 [lastMsg]；
  ///   - 使用 [lastMsgSeq] 作为消息拉取起点时，返回的消息列表里包含 [lastMsgSeq] 所表示的消息；
  ///
  /// 在拉取 Group 消息时：
  /// - 如果同时指定了 [lastMsg] 和 [lastMsgSeq]，SDK 优先使用 [lastMsg] 作为消息的拉取起点
  /// - 如果 [lastMsg] 和 [lastMsgSeq] 都未指定，消息的拉取起点分为如下两种情况：
  ///   - 如果设置了拉取的时间范围，SDK 会根据 [timeBegin] 所描述的时间点作为拉取起点
  ///   - 如果未设置拉取的时间范围，SDK 默认使用会话的最新消息作为拉取起点
  ///
  /// 关于拉取消息的时间范围：
  /// - [timeBegin]  表示时间范围的起点；默认为 0，表示从现在开始拉取；UTC 时间戳，单位：秒
  /// - [timePeriod] 表示时间范围的长度；默认为 0，表示不限制时间范围；单位：秒
  /// - 时间范围的方向由参数 getType 决定
  /// - 如果 [getType] 取 V2TIM_GET_CLOUD_OLDER_MSG/V2TIM_GET_LOCAL_OLDER_MSG，表示从 [timeBegin] 开始，过去的一段时间，时间长度由 [timePeriod] 决定
  /// - 如果 [getType] 取 V2TIM_GET_CLOUD_NEWER_MSG/V2TIM_GET_LOCAL_NEWER_MSG，表示从 [timeBegin] 开始，未来的一段时间，时间长度由 [timePeriod] 决定
  /// - 取值范围区间为闭区间，包含起止时间，二者关系如下：
  ///   - 如果 [getType] 指定了朝消息时间更老的方向拉取，则时间范围表示为 【timeBegin-timePeriod, timeBegin】
  ///   - 如果 [getType] 指定了朝消息时间更新的方向拉取，则时间范围表示为 【timeBegin, timeBegin+timePeriod】
  ///
  /// 拉取群组历史消息时，支持按照消息序列号 [messageSeqList] 拉取：
  /// - 仅拉取群组历史消息时有效
  /// - 消息序列号 seq 可以通过 V2TIMMessage 对象的 seq 字段获取；
  /// - 当 [getType] 设置为从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回；如果无网络，则直接返回本地消息列表；
  /// - 当 [getType] 设置为从本地拉取时，直接返回本地的消息列表；
  /// - 当 [getType] 设置为拉取更旧的消息时，消息列表按照时间逆序，也即消息按照时间戳从大往小的顺序排序；
  /// - 当 [getType] 设置为拉取更新的消息时，消息列表按照时间顺序，也即消息按照时间戳从小往大的顺序排序。
  ///
  /// web 端使用该接口，消息都是从远端拉取，不支持lastMsgSeq
  ///
  ///
  Future<V2TimValueCallback<V2TimMessageListResult>> getHistoryMessageListV2({
    HistoryMsgGetTypeEnum? getType =
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    V2TimMessage? lastMsg,
    String? lastMsgID,
    List<int>? messageTypeList,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getHistoryMessageListV2(
        getType: getType!.index,
        userID: userID,
        count: count,
        lastMsgID: lastMsgID,
        groupID: groupID,
        lastMsgSeq: lastMsgSeq,
        messageTypeList: messageTypeList ?? [],
        messageSeqList: messageSeqList,
        timeBegin: timeBegin,
        timePeriod: timePeriod,
      );
    }

    return TIMMessageManager.instance.getHistoryMessageListV2(
      getType: getType,
      userID: userID,
      count: count,
      lastMsg: lastMsg,
      lastMsgID: lastMsgID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq != -1 ? lastMsgSeq : null,
      messageTypeList: messageTypeList,
      messageSeqList: messageSeqList,
      timeBegin: timeBegin,
      timePeriod: timePeriod,
    );
  }

  /// 撤回消息
  ///
  /// [message] 撤回的消息
  ///
  /// [msgID]  **待废弃** 请使用 [message] 参数
  ///
  /// 注意
  ///
  /// ```
  /// 撤回消息的时间限制默认 2 minutes，超过 2 minutes 的消息不能撤回，您也可以在 控制台（功能配置 -> 登录与消息 -> 消息撤回设置）自定义撤回时间限制。
  /// 仅支持单聊和群组中发送的普通消息，无法撤销 onlineUserOnly 为 true 即仅在线用户才能收到的消息，也无法撤销直播群（AVChatRoom）中的消息。
  /// 如果发送方撤回消息，已经收到消息的一方会收到 V2TIMAdvancedMsgListener -> onRecvMessageRevoked 回调。
  ///
  ///
  /// web 端调用 webMessageInstatnce 为必传
  /// ```
  ///
  Future<V2TimCallback> revokeMessage({V2TimMessage? message, String? msgID, Object? webMessageInstatnce}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .revokeMessage(msgID: msgID, webMessageInstatnce: webMessageInstatnce);
    }

    return TIMMessageManager.instance.revokeMessage(message: message, msgID: msgID);
  }

  /// 消息变更
  ///
  /// - 如果消息修改成功，自己和对端用户（C2C）或群组成员（Group）都会收到 onRecvMessageModified 回调。
  /// - 如果在修改消息过程中，消息已经被其他人修改，completion 会返回 ERR_SDK_MSG_MODIFY_CONFLICT 错误。
  /// - 消息无论修改成功或则失败，都会返回最新的消息对象。
  ///
  /// web不支持该接口
  Future<V2TimValueCallback<V2TimMessageChangeInfo>> modifyMessage({
    required V2TimMessage message,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.modifyMessage(message: message);
    }

    return await TIMMessageManager.instance.modifyMessage(message: message);
  }

  /// 设置消息自定义数据（本地保存，不会发送到对端，程序卸载重装后失效）
  ///
  /// [localCustomData] 自定义数据
  ///
  /// [message]  消息对象
  ///
  /// [msgID]  **待废弃**，请使用 lastMsg
  ///
  /// 注意：web不支持该接口
  Future<V2TimCallback> setLocalCustomData({
    V2TimMessage? message,
    String? msgID,
    required String localCustomData,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setLocalCustomData(msgID: msgID, localCustomData: localCustomData);
    }

    return TIMMessageManager.instance.setLocalCustomData(
        message: message, msgID: msgID, localCustomData: localCustomData);
  }

  /// 设置消息自定义数据，可以用来标记语音、视频消息是否已经播放（本地保存，不会发送到对端，程序卸载重装后失效）
  ///
  /// [message]  消息对象
  ///
  /// [msgID]  **待废弃**，请使用 lastMsg
  ///
  /// web 不支持
  Future<V2TimCallback> setLocalCustomInt({
    V2TimMessage? message,
    String? msgID,
    required int localCustomInt,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setLocalCustomInt(msgID: msgID, localCustomInt: localCustomInt);
    }

    return TIMMessageManager.instance.setLocalCustomInt(
        message: message, msgID: msgID, localCustomInt: localCustomInt);
  }

  /// 设置云端自定义数据（云端保存，会发送到对端，程序卸载重装后还能拉取到）
  ///
  /// [message]  消息对象
  ///
  /// [msgID]  **待废弃**，请使用 lastMsg
  ///
  /// web 不支持
  Future<V2TimCallback> setCloudCustomData({
    V2TimMessage? message,
    String? msgID,
    required String data,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setCloudCustomData(data: data, msgID: msgID);
    }

    return TIMMessageManager.instance.setCloudCustomData(message: message, msgID: msgID, data: data);
  }

  /// 删除本地消息
  ///
  /// [message]  删除的消息
  ///
  /// [msgID]  **待废弃** 请使用 [message] 参数
  ///
  /// 注意
  /// - 消息只能本地删除，消息删除后，SDK 会在本地把这条消息标记为已删除状态，getHistoryMessage 不能再拉取到，但是如果程序卸载重装，本地会失去对这条消息的删除标记，getHistoryMessage 还能再拉取到该条消息。
  ///
  /// web不支持该接口
  ///
  Future<V2TimCallback> deleteMessageFromLocalStorage({
    V2TimMessage? message,
    String? msgID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteMessageFromLocalStorage(msgID: msgID);
    }

    return TIMMessageManager.instance.deleteMessageFromLocalStorage(message: message, msgID: msgID);
  }

  /// 删除本地及漫游消息
  ///
  /// [messageList]  删除的消息列表
  ///
  /// [msgIDs]  **待废弃** 请使用 [messageList] 参数
  ///
  /// [webMessageInstanceList]  这个参数 web 独有其中元素是 web 端的 message 实例,具体请看[web文档](https://web.sdk.qcloud.com/im/doc/zh-cn/SDK.html#deleteMessage)
  ///
  ///
  /// 该接口会删除本地历史的同时也会把漫游消息即保存在服务器上的消息也删除，卸载重装后无法再拉取到。需要注意的是：
  /// - 一次最多只能删除 30 条消息
  /// - 要删除的消息必须属于同一会话
  /// - 一秒钟最多只能调用一次该接口
  /// - 如果该账号在其他设备上拉取过这些消息，那么调用该接口删除后，这些消息仍然会保存在那些设备上，即删除消息不支持多端同步。
  ///
  Future<V2TimCallback> deleteMessages({
    List<V2TimMessage>? messageList,
    List<String>? msgIDs,
    List<dynamic>? webMessageInstanceList}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteMessages(
          msgIDs: msgIDs, webMessageInstanceList: webMessageInstanceList);
    }

    return TIMMessageManager.instance.deleteMessages(msgList:messageList, msgIDs: msgIDs);
  }

  /// 清空单聊本地及云端的消息（不删除会话）
  ///
  ///
  /// 请注意：
  ///```
  ///  会话内的消息在本地删除的同时，在服务器也会同步删除。
  ///
  ///  web不支持该接口
  ///```
  Future<V2TimCallback> clearC2CHistoryMessage({
    required String userID,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance
          .clearC2CHistoryMessage(userID: userID);
    }

    return await TIMMessageManager.instance
        .clearC2CHistoryMessage(userID: userID);
  }

  /// 清空群聊本地及云端的消息（不删除会话）
  ///
  /// 请注意：
  /// ```
  /// 会话内的消息在本地删除的同时，在服务器也会同步删除。
  ///
  /// web不支持该接口
  ///```
  Future<V2TimCallback> clearGroupHistoryMessage({
    required String groupID,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.clearGroupHistoryMessage(groupID: groupID);
    }

    return await TIMMessageManager.instance.clearGroupHistoryMessage(groupID: groupID);
  }

  /// 向群组消息列表中添加一条消息。
  ///
  /// 该接口主要用于满足向群组聊天会话中插入一些提示性消息的需求，比如“您已经退出该群”，这类消息有展示 在聊天消息区的需求，但并没有发送给其他人的必要。 所以该接口相当于一个被禁用了网络发送能力的 sendMessage() 接口。
  ///
  /// [groupID] 群组 ID
  ///
  /// [sender] 发送者
  ///
  /// [message] 消息
  ///
  /// [createdMsgID] **待废弃** 请使用 [message] 参数
  ///
  /// 通过该接口 save 的消息只存本地，程序卸载后会丢失。
  ///
  /// 注意： web不支持该接口
  ///
  Future<V2TimValueCallback<V2TimMessage>> insertGroupMessageToLocalStorageV2({
    required String groupID,
    required String senderID,
    V2TimMessage? message,
    String? createdMsgID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.insertGroupMessageToLocalStorageV2(
        groupID: groupID,
        senderID: senderID,
        createdMsgID: createdMsgID,
      );
    }

    return TIMMessageManager.instance.insertGroupMessageToLocalStorageV2(
      groupID: groupID,
      senderID: senderID,
      message: message,
      createdMsgID: createdMsgID,
    );
  }

  /// 向C2C消息列表中添加一条消息。
  ///
  /// 该接口主要用于满足向C2C聊天会话中插入一些提示性消息的需求，比如“您已成功发送消息”，这类消息有展示 在聊天消息区的需求，但并没有发送给其他人的必要。 所以该接口相当于一个被禁用了网络发送能力的 sendMessage() 接口。
  ///
  /// [userID] 接收者 ID
  ///
  /// [sender] 发送者 ID
  ///
  /// [message] 消息
  ///
  /// [createdMsgID] **待废弃** 请使用 [message] 参数
  ///
  ///通过该接口 save 的消息只存本地，程序卸载后会丢失。
  ///
  /// web不支持该接口
  Future<V2TimValueCallback<V2TimMessage>> insertC2CMessageToLocalStorageV2({
    required String userID,
    required String senderID,
    V2TimMessage? message,
    String? createdMsgID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.insertC2CMessageToLocalStorageV2(
        userID: userID,
        senderID: senderID,
        createdMsgID: createdMsgID,
      );
    }

    return TIMMessageManager.instance.insertC2CMessageToLocalStorageV2(
      userID: userID,
      senderID: senderID,
      message: message,
      createdMsgID: createdMsgID,
    );
  }

  /// 根据 messageID 查询指定会话中的本地消息
  /// 参数：messageIDList 消息ID列表
  ///```
  /// 注意： web不支持该接口
  ///```
  Future<V2TimValueCallback<List<V2TimMessage>>> findMessages({
    required List<String> messageIDList,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.findMessages(messageIDList: messageIDList);
    }

    return await TIMMessageManager.instance.findMessages(messageIDList: messageIDList);
  }

  /// 搜索本地消息
  ///
  /// [searchParam] 消息搜索参数，详见 [V2TimMessageSearchParam] 的定义
  ///```
  /// 注意： web不支持该接口
  /// ```
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchLocalMessages({
    required V2TimMessageSearchParam searchParam,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.searchLocalMessages(searchParam: searchParam);
    }

    return await TIMMessageManager.instance.searchLocalMessages(searchParam: searchParam);
  }

  /// 搜索云端消息
  ///
  /// [searchParam] 消息搜索参数，详见 [V2TimMessageSearchParam] 的定义
  ///
  Future<V2TimValueCallback<V2TimMessageSearchResult>> searchCloudMessages({
    required V2TimMessageSearchParam searchParam,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchCloudMessages(searchParam: searchParam);
    }

    return TIMMessageManager.instance.searchCloudMessages(searchParam: searchParam);
  }

  /// 发送消息已读回执
  ///
  /// 该功能为旗舰版功能。
  ///
  /// [messageList] 消息必须在同一个 Group 会话中。
  ///
  /// [messageIDList] **待废弃** 请使用 [messageIDList] 参数
  ///
  /// 该接口调用成功后，会话未读数不会变化，消息发送者会收到 onRecvMessageReadReceipts 回调，回调里面会携带消息的最新已读信息。
  ///
  /// 注意：web不支持该接口
  ///
  Future<V2TimCallback> sendMessageReadReceipts({
    List<V2TimMessage>? messageList,
    List<String>? messageIDList,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.sendMessageReadReceipts(
        messageIDList: messageIDList,
      );
    }

    return TIMMessageManager.instance.sendMessageReadReceipts(messageList: messageList, messageIDList: messageIDList);
  }

  /// 获取消息已读回执
  ///
  /// [messageList] 消息必须在同一个 Group 会话中。
  ///
  /// [messageIDList] **待废弃** 请使用 [messageList] 参数
  ///
  /// 向群消息发送已读回执，需要您先到控制台打开对应的开关
  /// messageList 里的消息必须在同一个会话中。
  /// 该接口调用成功后，会话未读数不会变化，消息发送者会收到 onRecvMessageReadReceipts 回调，回调里面会携带消息的最新已读信息。
  Future<V2TimValueCallback<List<V2TimMessageReceipt>>> getMessageReadReceipts({
    List<V2TimMessage>? messageList,
    List<String>? messageIDList,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.getMessageReadReceipts(
        messageIDList: messageIDList,
      );
    }

    return TIMMessageManager.instance.getMessageReadReceipts(messageList: messageList, messageIDList: messageIDList);
  }

  /// 获取群消息已读群成员列表
  ///
  ///
  ///
  Future<V2TimValueCallback<V2TimGroupMessageReadMemberList>> getGroupMessageReadMemberList({
    V2TimMessage? message,
    String? messageID,
    required GetGroupMessageReadMemberListFilter filter,
    int nextSeq = 0,
    int count = 100,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance
          .getGroupMessageReadMemberList(
        messageID: messageID,
        filter: filter,
        nextSeq: nextSeq,
        count: count,
      );
    }

    return await TIMMessageManager.instance.getGroupMessageReadMemberList(
      message: message,
      messageID: messageID,
      filter: filter,
      nextSeq: nextSeq,
      count: count,
    );
  }

  /// 设置消息扩展（Flutter SDK 4.2.0及以上版本支持，需要您购买旗舰版套餐）
  ///
  /// 参数
  /// [message]	消息对象，消息需满足三个条件：1、消息发送前需设置 supportMessageExtension 为 true，2、消息必须是发送成功的状态，3、消息不能是社群（Community）和直播群（AVChatRoom）消息。
  ///
  /// [extensions]	扩展信息，如果扩展 key 已经存在，则修改扩展的 value 信息，如果扩展 key 不存在，则新增扩展。
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  /// 注意
  /// 扩展 key 最大支持 100 字节，扩展 value 最大支持 1KB，单次最大支持设置 20 个扩展，单条消息最多可设置 300 个扩展。
  /// 当多个用户同时设置同一个扩展 key 时，只有第一个用户可以执行成功，其它用户会收到 23001 错误码和更新后的拓展信息，在收到错误码和最新扩展信息后，请按需重新发起设置操作。
  /// 我们强烈建议不同的用户设置不同的扩展 key，这样大部分场景都不会冲突，比如投票、接龙、问卷调查，都可以把自己的 userID 作为扩展 key。
  ///
  Future<V2TimValueCallback<List<V2TimMessageExtensionResult>>> setMessageExtensions({
    V2TimMessage? message,
    String? msgID,
    required List<V2TimMessageExtension> extensions,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.setMessageExtensions(
        msgID: msgID,
        extensions: extensions,
      );
    }

    return await TIMMessageManager.instance.setMessageExtensions(
      message: message,
      msgID: msgID,
      extensions: extensions,
    );
  }

  /// 获取消息扩展（Flutter SDK 4.2.0及以上版本支持，需要您购买旗舰版套餐）
  ///
  /// [message]	消息对象
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  Future<V2TimValueCallback<List<V2TimMessageExtension>>> getMessageExtensions({
    V2TimMessage? message,
    String? msgID,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.getMessageExtensions(
        msgID: msgID,
    );
    }
    return await TIMMessageManager.instance.getMessageExtensions(
      message: message,
      msgID: msgID,
    );
  }

  Future<V2TimValueCallback<List<V2TimMessageExtensionResult>>> deleteMessageExtensions({
    V2TimMessage? message,
    String? msgID,
    required List<String> keys,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.deleteMessageExtensions(
        msgID: msgID,
        keys: keys,
      );
    }

    return await TIMMessageManager.instance.deleteMessageExtensions(
      message: message,
      msgID: msgID,
      keys: keys,
    );
  }

  /// 添加消息回应（可以用于实现表情回应）
  ///
  /// [message] 消息对象
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  /// 注意：
  /// - 该功能为旗舰版功能，需要您购买旗舰版套餐。
  /// - 如果单条消息 Reaction 数量超过最大限制，调用接口会报 23005 错误。
  /// - 如果单个 Reaction 用户数量超过最大限制，调用接口会报 23006 错误。
  /// - 如果 Reaction 已经包含当前用户，调用接口会报 23007 错误。
  Future<V2TimCallback> addMessageReaction({V2TimMessage? message, String? msgID, required String reactionID}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.addMessageReaction(msgID: msgID, reactionID: reactionID);
    }

    return TIMMessageManager.instance.addMessageReaction(message: message, msgID: msgID, reactionID: reactionID);
  }

  Future<V2TimCallback> removeMessageReaction({
    V2TimMessage? message,
    String? msgID,
    required String reactionID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.removeMessageReaction(msgID: msgID, reactionID: reactionID);
    }

    return TIMMessageManager.instance.removeMessageReaction(message: message, msgID: msgID, reactionID: reactionID);
  }

  /// 批量拉取多条消息回应信息
  ///
  /// [messageList] 消息列表，一次最大支持 20 条消息，消息必须属于同一个会话。
  ///
  /// [maxUserCountPerReaction] maxUserCountPerReaction 取值范围 【0,10】，每个 Reaction 最多只返回前 10 个用户信息，如需更多用户信息，可以按需调用 getAllUserListOfMessageReaction 接口分页拉取。
  ///
  /// [msgIDList] **待废弃** 请使用 [messageList] 参数
  Future<V2TimValueCallback<List<V2TimMessageReactionResult>>> getMessageReactions({
    List<V2TimMessage>? messageList,
    List<String>? msgIDList,
    required int maxUserCountPerReaction,
    List<String>? webMessageInstanceList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getMessageReactions(
        msgIDList: msgIDList,
        maxUserCountPerReaction: maxUserCountPerReaction,
        webMessageInstanceList: webMessageInstanceList,
      );
    }

    return TIMMessageManager.instance.getMessageReactions(
      messageList: messageList,
      msgIDList: msgIDList,
      maxUserCountPerReaction: maxUserCountPerReaction,
    );
  }

  /// 分页拉取使用指定消息回应用户信息
  ///
  /// [message] 消息对象
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  /// [reactionID] 消息回应 ID
  ///
  /// [nextSeq] 分页拉取的起始位置，第一次拉取填 0，回调返回的 nextSeq 填入下次拉取的 nextSeq 参数
  ///
  /// [count] 本次拉取的消息回应用户数量，取值范围 【0,100】
  Future<V2TimValueCallback<V2TimMessageReactionUserResult>> getAllUserListOfMessageReaction({
    V2TimMessage? message,
    String? msgID,
    required String reactionID,
    required int nextSeq,
    required int count,
    String? webMessageInstance,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getAllUserListOfMessageReaction(
        msgID: msgID,
        reactionID: reactionID,
        nextSeq: nextSeq,
        count: count,
        webMessageInstance: webMessageInstance,
      );
    }

    return TIMMessageManager.instance.getAllUserListOfMessageReaction(
      message: message,
      msgID: msgID,
      reactionID: reactionID,
      nextSeq: nextSeq,
      count: count,
    );
  }

  /// 翻译文本消息
  ///
  /// [texts] 待翻译文本数组。
  ///
  /// [sourceLanguage] 源语言。可以设置为特定语言或”auto“。“auto“表示自动识别源语言。传空默认为”auto“。
  ///
  /// [targetLanguage] 目标语言。支持的目标语言有多种，例如：英语-“en“，简体中文-”zh“，法语-”fr“，德语-”de“等。
  Future<V2TimValueCallback<Map<String, String>>> translateText({
    required List<String> texts,
    String? sourceLanguage,
    required String targetLanguage,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.translateText(
        texts: texts,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );
    }

    return await TIMMessageManager.instance.translateText(
      texts: texts,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage,
    );
  }

  /// 将语音转成文字
  Future<V2TimValueCallback<String>> convertVoiceToText({
    V2TimMessage? message,
    String? msgID,
    required String language, // "zh (cmn-Hans-CN)" "yue-Hant-HK" "en-US" "ja-JP"
    String? webMessageInstance,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.convertVoiceToText(
        msgID: msgID,
        language: language,
        webMessageInstance: webMessageInstance,
      );
    }

    return TIMMessageManager.instance.convertVoiceToText(message: message, msgID: msgID, language: language);
  }

  /// 设置群消息置顶
  ///
  /// [message] 置顶的消息对象
  ///
  /// [groupID] 群 ID
  ///
  /// [isPinned] 是否置顶
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  Future<V2TimCallback> pinGroupMessage({
    V2TimMessage? message,
    String? msgID,
    required String groupID,
    required bool isPinned,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.pinGroupMessage(msgID: msgID, groupID: groupID, isPinned: isPinned);
    }

    return TIMMessageManager.instance
        .pinGroupMessage(message: message, msgID: msgID, groupID: groupID, isPinned: isPinned);
  }

  /// 获取已置顶的群消息列表
  Future<V2TimValueCallback<List<V2TimMessage>>> getPinnedGroupMessageList({required String groupID}) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getPinnedGroupMessageList(groupID: groupID);
    }

    return TIMMessageManager.instance.getPinnedGroupMessageList(groupID: groupID);
  }

  /// 获取多媒体消息URL
  ///
  /// [message]  消息对象
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  Future<V2TimValueCallback<V2TimMessageOnlineUrl>> getMessageOnlineUrl({
    V2TimMessage? message,
    String? msgID,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.getMessageOnlineUrl(msgID: msgID);
    }

    return await TIMMessageManager.instance.getMessageOnlineUrl(message: message, msgID: msgID);
  }

  /// 下载多媒体消息
  ///
  /// [message] 消息对象
  ///
  /// [msgID] **待废弃** 请使用 [message] 参数
  ///
  /// [onDownloadFinished] 新增下载完成的回调，可以获取当前包含下载路径的消息对象（8.6.7019+3）
  Future<V2TimCallback> downloadMessage({
    V2TimMessage? message,
    String? msgID,
    required int messageType,
    required int imageType, // 图片类型，仅messageType为图片消息是有效
    required bool isSnapshot, // 是否是视频封面，仅messageType为视频消息是有效
    String? downloadPath, // 指定的下载路径
    void Function(V2TimMessage message)? onDownloadFinished, // 下载完成的回调
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.downloadMessage(
        msgID: msgID,
        messageType: messageType,
        imageType: imageType,
        isSnapshot: isSnapshot,
      );
    }

    return await TIMMessageManager.instance.downloadMessage(
      message: message,
      msgID: msgID,
      imageType: imageType,
      isSnapshot: isSnapshot,
      downloadPath: downloadPath,
      onDownloadFinished: onDownloadFinished,
    );
  }

  /// @nodoc
  formatJson(jsonSrc) {
    return json.decode(json.encode(jsonSrc));
  }

  /// @nodoc
  Future<bool> pathExits(String fpath) async {
    if (kIsWeb) {
      return true;
    }
    if (fpath.isEmpty) {
      return false;
    }
    return await File(fpath).exists();
  }

  /// **该接口已废弃** 获取历史消息高级接口(没有处理Native返回数据)
  ///
  /// 参数
  /// option	拉取消息选项设置，可以设置从云端、本地拉取更老或更新的消息
  ///
  /// 请注意：
  /// 如果设置为拉取云端消息，当 SDK 检测到没有网络，默认会直接返回本地数据
  /// 只有会议群（Meeting）才能拉取到进群前的历史消息，直播群（AVChatRoom）消息不存漫游和本地数据库，调用这个接口无效
  ///
  /// 注意： web不支持该接口
  ///
  @Deprecated("no longer supported")
  Future<LinkedHashMap<dynamic, dynamic>> getHistoryMessageListWithoutFormat({
    HistoryMsgGetTypeEnum? getType =
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .getHistoryMessageListWithoutFormat(
        count: count,
        getType: getType!.index,
        userID: userID,
        groupID: groupID,
        lastMsgSeq: lastMsgSeq,
        lastMsgID: lastMsgID,
        messageSeqList: messageSeqList,
        timeBegin: timeBegin,
        timePeriod: timePeriod,
      );
    }

    // native 暂不支持，后续如有需求再考虑，需要兼容原来的 toJson 方法
    return LinkedHashMap<dynamic, dynamic>();
  }

  /// **该接口已废弃** 发送图片消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createVideoMessage创建消息,再调用sendMessage发送消息'
  ///
  /// web 端发送图片消息时需要传入fileName、fileContent 字段
  ///
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendImageMessage({
    required String imagePath,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
    String? fileName,
    Uint8List? fileContent,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送视频消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createVideoMessage创建消息,再调用sendMessage发送消息'
  ///
  /// web 端发送视频消息时需要传入fileName, fileContent字段
  /// 不支持 snapshotPath、duration、type
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendVideoMessage({
    required String videoFilePath,
    required String receiver,
    required String type,
    required String snapshotPath,
    required int duration,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
    String? fileName,
    Uint8List? fileContent,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送高级文本消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createTextMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendTextMessage({
    required String text,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送自定义消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createCustomMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendCustomMessage({
    required String data,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    String desc = "",
    String extension = "",
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送文件。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createFileMessage创建消息,再调用sendMessage发送消息
  /// 
  /// web 端 fileName、fileContent 为必传字段
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendFileMessage(
      {required String filePath,
        required String fileName,
        required String receiver,
        required String groupID,
        MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
        bool onlineUserOnly = false,
        bool isExcludedFromUnreadCount = false,
        OfflinePushInfo? offlinePushInfo,
        Uint8List? fileContent}) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送语音消息。
  ///
  /// 注意： web不支持该接口
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendSoundMessage({
    required String soundPath,
    required String receiver,
    required String groupID,
    required int duration,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 创建文本消息，并且可以附带 @ 提醒功能。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createTextAtMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendTextAtMessage({
    required String text,
    required List<String> atUserList,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送地理位置消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createLocationMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendLocationMessage({
    required String desc,
    required double longitude,
    required double latitude,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送表情消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createFaceMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendFaceMessage({
    required int index,
    required String data,
    required String receiver,
    required String groupID,
    MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool onlineUserOnly = false,
    bool isExcludedFromUnreadCount = false,
    OfflinePushInfo? offlinePushInfo,
  }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送合并消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createMergerMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendMergerMessage(
      {required List<String> msgIDList,
        required String title,
        required List<String> abstractList,
        required String compatibleText,
        required String receiver,
        required String groupID,
        MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
        bool onlineUserOnly = false,
        bool isExcludedFromUnreadCount = false,
        OfflinePushInfo? offlinePushInfo,
        List<String>? webMessageInstanceList}) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送转发消息。自3.6.0开始弃用，我们将创建消息与发送消息分离，请先使用createForwardMessage创建消息,再调用sendMessage发送消息
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> sendForwardMessage(
      {required String msgID,
        required String receiver,
        required String groupID,
        MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
        bool onlineUserOnly = false,
        bool isExcludedFromUnreadCount = false,
        OfflinePushInfo? offlinePushInfo,
        String? webMessageInstance}) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 发送回复消息。
  @Deprecated('sendReplyMessage 从 8.3 版本开始弃用，推荐直接使用 sendMessage')
  Future<V2TimValueCallback<V2TimMessage>> sendReplyMessage(
      {required String id, // 自己创建的ID
        required String receiver,
        required String groupID,
        required V2TimMessage replyMessage, // 被回复的消息
        MessagePriorityEnum? priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
        bool onlineUserOnly = false,
        bool isExcludedFromUnreadCount = false,
        bool needReadReceipt = false,
        OfflinePushInfo? offlinePushInfo,
        String? localCustomData,
      }) async {
    return V2TimValueCallback<V2TimMessage>.fromBool(false, 'not support');
  }

  /// **该接口已废弃** 消息重发。
  @Deprecated("no longer supported")
  Future<V2TimValueCallback<V2TimMessage>> reSendMessage({
    required String msgID,
    bool onlineUserOnly = false,
    Object? webMessageInstatnce
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance
          .reSendMessage(msgID: msgID, onlineUserOnly: onlineUserOnly, webMessageInstatnce: webMessageInstatnce);
    }

    return await TIMMessageManager.instance.reSendMessage(
        msgID: msgID,
        onlineUserOnly: onlineUserOnly
    );
  }

  /// **该接口已废弃，请使用 insertGroupMessageToLocalStorageV2**。向群组消息列表中添加一条消息。
  @Deprecated("use insertGroupMessageToLocalStorageV2 instead")
  Future<V2TimValueCallback<V2TimMessage>> insertGroupMessageToLocalStorage({
    required String data,
    required String groupID,
    required String sender,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.insertGroupMessageToLocalStorage(
          data: data, groupID: groupID, sender: sender);
    }

    return TIMMessageManager.instance.insertGroupMessageToLocalStorage(
        data: data, groupID: groupID, sender: sender);

  }

  /// **该接口已废弃，请使用 insertC2CMessageToLocalStorageV2**。向C2C消息列表中添加一条消息。
  @Deprecated("use insertC2CMessageToLocalStorageV2 instead")
  Future<V2TimValueCallback<V2TimMessage>> insertC2CMessageToLocalStorage({
    required String data,
    required String userID,
    required String sender,
  }) async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance
          .insertC2CMessageToLocalStorage(
          data: data, userID: userID, sender: sender);
    }

    return await TIMMessageManager.instance
        .insertC2CMessageToLocalStorage(
        data: data, userID: userID, sender: sender);
  }

  /// **待废弃** 请使用 [V2TIMConversationManager.cleanConversationUnreadMessageCount] 接口。设置单聊消息已读。
  @Deprecated("no longer supported")
  Future<V2TimCallback> markC2CMessageAsRead({
    required String userID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.markC2CMessageAsRead(userID: userID);
    }

    return TIMMessageManager.instance.markC2CMessageAsRead(userID: userID);
  }

  /// **待废弃** 请使用 [V2TIMConversationManager.cleanConversationUnreadMessageCount] 接口。设置群组消息已读。
  @Deprecated("no longer supported")
  Future<V2TimCallback> markGroupMessageAsRead({
    required String groupID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.markGroupMessageAsRead(groupID: groupID);
    }

    return TIMMessageManager.instance.markGroupMessageAsRead(groupID: groupID);
  }

  /// **待废弃** 请使用 [V2TIMConversationManager.cleanConversationUnreadMessageCount] 接口。标记所有消息为已读。
  @Deprecated("no longer supported")
  Future<V2TimCallback> markAllMessageAsRead() async {
    if (kIsWeb) {
      return await TencentCloudChatSdkPlatform.instance.markAllMessageAsRead();
    }

    return await TIMMessageManager.instance.markAllMessageAsRead();
  }
}
