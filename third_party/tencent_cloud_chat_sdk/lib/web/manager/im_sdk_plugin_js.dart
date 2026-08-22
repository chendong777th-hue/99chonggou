@JS()
library js_interop;

import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';
import 'package:js/js.dart'; // Pull in our dependency

import 'dart:js' as js;

import 'package:tencent_cloud_chat_sdk/web/models/v2_tim_init_sdk.dart';

// 此为为自定义JS库实验性质，后面我会清除
// @JS("ImWrapper")
// class ImWrapper {
//   external ImWrapper();
//   external int create(param);
//   external void test();
// }
@JS("TIMUploadPlugin")
class TIMUploadPlugin {
  external TIMUploadPlugin();
}

// 引入TIM JS库
@JS("TencentCloudChat")
class TencentCloudChat {
  external static dynamic create(param);
  external static String VERSION;

  external void on(String enumValue, fun);
  external void off(String enumValue, fun);

  external Future login(param);
  external Future logout();
  external Future getMyProfile();
  external Future getUserProfile(param);
  external Future updateMyProfile(param);
  external destroy();

  // group releated call
  external Future createGroup(param);

  external Future getConversationList([param]);
  external Future getMessageList(param);
  external Future getMessageListHopping(param);
  external Future setMessageRead(param);
  external Future getConversationProfile(param);
  external Future deleteConversation(param);
  external Future pinConversation(param);
  external Future getGroupList();
  external Future joinGroup(param);
  external Future quitGroup(param);
  external Future dismissGroup(param);

  // friendship releated call
  external Future getFriendList();
  external Future getFriendProfile(param);
  external Future addFriend(param);
  external Future updateFriend(param);
  external Future deleteFriend(param);
  external Future checkFriend(param);
  external Future getFriendApplicationList();
  external Future acceptFriendApplication(param);
  external Future refuseFriendApplication(param);
  external Future deleteFriendApplication(param);
  external Future setFriendApplicationRead();
  external Future addToBlacklist(param);
  external Future removeFromBlacklist(param);
  external Future getBlacklist();
  external Future getFriendGroupList();
  external Future createFriendGroup(param);
  external Future deleteFriendGroup(param);
  external Future addToFriendGroup(param);
  external Future removeFromFriendGroup(param);
  external Future renameFriendGroup(param);
  external Future addFriendsToFriendGroup(param);
  external Future deleteFriendsFromFriendGroup(param);
  external Future searchCloudMessages(param);
  // message
  external findMessage(param);
  external createTextMessage(param);
  external createCustomMessage(param);
  external createImageMessage(params);
  external createTextAtMessage(params);
  external createLocationMessage(params);
  external createMergerMessage(params);
  external createForwardMessage(params);
  external createVideoMessage(params);
  external createFileMessage(params);
  external createFaceMessage(params);
  external Future revokeMessage(params);
  external Future sendMessage(param, [param2]);
  external Future reSendMessage(param);
  external Future deleteMessage(param);
  external Future setMessageRemindType(param);
  external Future modifyMessage(param);
  external Future downloadMergerMessage(param);
  external Future getMessageReadReceiptList(params);
  external Future sendMessageReadReceipt(params);
  external Future getGroupMessageReadMemberList(params);
  external Future translateText(params);
  external Future addMessageReaction(param, id);
  external Future removeMessageReaction(param, id);
  external Future getMessageReactions(param);
  external Future getAllUserListOfMessageReaction(param);
  external Future convertVoiceToText(param);
  // group
  external Future getGroupProfile(poaram);
  external Future updateGroupProfile(param);
  external Future getGroupOnlineMemberCount(param);
  external Future getGroupMemberList(param);
  external Future getGroupMemberProfile(param);
  external Future setGroupMemberNameCard(param);
  external Future setGroupMemberCustomField(param);
  external Future setGroupMemberMuteTime(param);
  external Future addGroupMember(param);
  external Future deleteGroupMember(param);
  external Future setGroupMemberRole(param);
  external Future changeGroupOwner(param);
  external Future setGroupAttributes(param);
  external Future deleteGroupAttributes(param);
  external Future getGroupAttributes(param);
  external Future handleGroupApplication(param);
  external Future searchGroupByID(param);
  external registerPlugin(param);
  external Future getJoinedCommunityList();
  external Future createTopicInCommunity(param);
  external Future getTopicList(param);
  external Future updateTopicProfile(param);
  external Future deleteTopicFromCommunity(param);
  external Future getUserStatus(param);
}

initTim(options) {
  return TencentCloudChat.create(options);
}

String getVersion() => TencentCloudChat.VERSION;

// 做TIM的初始化,timWeb是一个动态的dynamic（即JS的object）
class V2TIMManagerWeb {
  static dynamic timWeb;
  static bool _uploadPluginRegistered = false;

  static setTimWeb(myTimWeb) async {
    timWeb = myTimWeb;
  }

  static void resetWebTimState() {
    timWeb = null;
    _uploadPluginRegistered = false;
  }

  static dynamic initWebTim(TimParams params) {
    if (timWeb != null) {
      return timWeb;
    }
    timWeb = initTim(params);
    // ignore: avoid_print
    print(
      'V2TIMManagerWeb.initWebTim: timWebNull=${timWeb == null} '
      'type=${timWeb.runtimeType}',
    );
    if (!_uploadPluginRegistered) {
      timWeb!.registerPlugin(mapToJSObj({
        'tim-upload-plugin': js.allowInterop(() {
          return TIMUploadPlugin();
        })
      }));
      _uploadPluginRegistered = true;
    }
    return timWeb;
  }

  static String getWebSDKVersion() => getVersion();
}
