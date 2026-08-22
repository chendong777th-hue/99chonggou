import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/follow_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/v2_tim_conversation_marktype.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';

class EnumUtils {
  static int convertGroupMemberRoleTypeEnum(GroupMemberRoleTypeEnum role) {
    if (role == GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_ADMIN) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
    }
    if (role == GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_MEMBER) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    }
    if (role == GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_OWNER) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
    }
    if (role == GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_UNDEFINED) {
      return GroupMemberRoleType.V2TIM_GROUP_MEMBER_UNDEFINED;
    }
    return GroupMemberRoleType.V2TIM_GROUP_MEMBER_UNDEFINED;
  }

  static GroupMemberRoleTypeEnum convertGroupMemberRoleType(int role) {
    switch (role) {
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN:
        return GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER:
        return GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER:
        return GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_ROLE_OWNER;
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_UNDEFINED:
        return GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_UNDEFINED;
      default:
        return GroupMemberRoleTypeEnum.V2TIM_GROUP_MEMBER_UNDEFINED;
    }
  }

  static int dartReceiveMessageOpt2CReceiveMessageOpt(ReceiveMsgOptEnum opt) {
    switch (opt) {
      case ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Receive;
      case ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Receive;
      case ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Notify;
      case ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE_EXCEPT_AT:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Notify_Except_At;
      case ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE_EXCEPT_AT:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Receive_Except_At;
      default:
        return ReceiveMsgOptType.kTIMRecvMsgOpt_Receive;
    }
  }

  static ReceiveMsgOptEnum cReceiveMessageOpt2DartOpt(int opt) {
    switch (opt) {
      case ReceiveMsgOptType.kTIMRecvMsgOpt_Receive:
        return ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE;
      case ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Receive:
        return ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE;
      case ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Notify:
        return ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE;
      case ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Notify_Except_At:
        return ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE_EXCEPT_AT;
      case ReceiveMsgOptType.kTIMRecvMsgOpt_Not_Receive_Except_At:
        return ReceiveMsgOptEnum.V2TIM_NOT_RECEIVE_MESSAGE_EXCEPT_AT;
      default:
        return ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE;
    }
  }

  static int dartElemType2CElemType(int elemType) {
    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return CElemType.ElemText;
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return CElemType.ElemCustom;
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return CElemType.ElemImage;
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return CElemType.ElemSound;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return CElemType.ElemVideo;
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return CElemType.ElemFile;
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return CElemType.ElemLocation;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return CElemType.ElemFace;
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return CElemType.ElemGroupTips;
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return CElemType.ElemMerge;
      default:
        return CElemType.ElemInvalid;
    }
  }

  static int cElemType2DartElemType(int elemType) {
    switch (elemType) {
      case CElemType.ElemText:
        return MessageElemType.V2TIM_ELEM_TYPE_TEXT;
      case CElemType.ElemCustom:
        return MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
      case CElemType.ElemImage:
        return MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      case CElemType.ElemSound:
        return MessageElemType.V2TIM_ELEM_TYPE_SOUND;
      case CElemType.ElemVideo:
        return MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
      case CElemType.ElemFile:
        return MessageElemType.V2TIM_ELEM_TYPE_FILE;
      case CElemType.ElemLocation:
        return MessageElemType.V2TIM_ELEM_TYPE_LOCATION;
      case CElemType.ElemFace:
        return MessageElemType.V2TIM_ELEM_TYPE_FACE;
      case CElemType.ElemGroupTips:
        return MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;
      case CElemType.ElemMerge:
        return MessageElemType.V2TIM_ELEM_TYPE_MERGER;
      default:
        return MessageElemType.V2TIM_ELEM_TYPE_NONE;
    }
  }

  static int dartGroupType2CType(String groupType) {
    if (groupType == GroupType.Public) {
      return CGroupType.groupPublic;
    } else if (groupType == GroupType.Work) {
      return CGroupType.groupPrivate;
    } else if (groupType == GroupType.Meeting) {
      return CGroupType.groupChatRoom;
    } else if (groupType == GroupType.AVChatRoom) {
      return CGroupType.groupAVChatRoom;
    } else if (groupType == GroupType.Community) {
      return CGroupType.groupCommunity;
    } else {
      return CGroupType.groupPublic;
    }
  }

  static String cGroupType2DartType(int groupType) {
    switch (groupType) {
      case CGroupType.groupPublic:
        return GroupType.Public;
      case CGroupType.groupPrivate:
        return GroupType.Work;
      case CGroupType.groupChatRoom:
        return GroupType.Meeting;
      case CGroupType.groupAVChatRoom:
      case CGroupType.groupBChatRoom:
        return GroupType.AVChatRoom;
      case CGroupType.groupCommunity:
        return GroupType.Community;
      default:
        return GroupType.Public;
    }
  }

  static GroupAddOptTypeEnum cGroupAddOption2DartEnum(int groupAddOption) {
    switch (groupAddOption) {
      case CGroupAddOption.groupAddOptForbid:
        return GroupAddOptTypeEnum.V2TIM_GROUP_ADD_FORBID;
      case CGroupAddOption.groupAddOptAuth:
        return GroupAddOptTypeEnum.V2TIM_GROUP_ADD_AUTH;
      case CGroupAddOption.groupAddOptAny:
        return GroupAddOptTypeEnum.V2TIM_GROUP_ADD_ANY;
      default:
        print('error: invalid c group add option');
        return GroupAddOptTypeEnum.V2TIM_GROUP_ADD_FORBID;
    }
  }

  static int dartGroupAddOptEnum2CType(GroupAddOptTypeEnum groupAddOption) {
    switch (groupAddOption) {
      case GroupAddOptTypeEnum.V2TIM_GROUP_ADD_FORBID:
        return CGroupAddOption.groupAddOptForbid;
      case GroupAddOptTypeEnum.V2TIM_GROUP_ADD_AUTH:
        return CGroupAddOption.groupAddOptAuth;
      case GroupAddOptTypeEnum.V2TIM_GROUP_ADD_ANY:
        return CGroupAddOption.groupAddOptAny;
      default:
        print('error: invalid dart group add option');
        return CGroupAddOption.groupAddOptForbid;
    }
  }

  static int dartGroupAddOptType2CType(int groupAddOption) {
    if (groupAddOption >= 0 && groupAddOption <= GroupAddOptTypeEnum.values.length) {
      return dartGroupAddOptEnum2CType(GroupAddOptTypeEnum.values[groupAddOption]);
    }

    print('error: invalid dart group add option');
    return CGroupAddOption.groupAddOptForbid;
  }

  static int cFriendshipRelationType2DartType(int relationType) {
    switch (relationType) {
      case CFriendshipRelationType.friendshipRelationTypeNone:
        return FriendType.V2TIM_FRIEND_TYPE_NONE;
      case CFriendshipRelationType.friendshipRelationTypeInMyFriendList:
        return FriendType.V2TIM_FRIEND_TYPE_IN_MY_FRIEND_LIST;
      case CFriendshipRelationType.friendshipRelationTypeInOtherFriendList:
        return FriendType.V2TIM_FRIEND_TYPE_IN_OTHER_FRIEND_LIST;
      case CFriendshipRelationType.friendshipRelationTypeBothFriend:
        return FriendType.V2TIM_FRIEND_TYPE_BOTH;
      default:
        print('error: invalid c friendship relation type');
        return FriendType.V2TIM_FRIEND_TYPE_NONE;
    }
  }

  static int cFriendCheckRelationType2DartType(int checkResultType) {
    switch (checkResultType) {
      case CFriendCheckRelationType.friendCheckNoRelation:
        return FriendType.V2TIM_FRIEND_TYPE_NONE;
      case CFriendCheckRelationType.friendCheckAWithB:
        return FriendType.V2TIM_FRIEND_TYPE_IN_MY_FRIEND_LIST;
      case CFriendCheckRelationType.friendCheckBWithA:
        return FriendType.V2TIM_FRIEND_TYPE_IN_OTHER_FRIEND_LIST;
      case CFriendCheckRelationType.friendCheckBothWay:
        return FriendType.V2TIM_FRIEND_TYPE_BOTH;
      default:
        print('error: invalid c check friend type');
        return FriendType.V2TIM_FRIEND_TYPE_NONE;
    }
  }

  static int dartFriendTypeEnum2CType(FriendTypeEnum type) {
    switch (type) {
      case FriendTypeEnum.V2TIM_FRIEND_TYPE_SINGLE:
        return CFriendType.friendTypeSingle;
      case FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH:
        return CFriendType.friendTypeBoth;
      default:
        print('please input a valid FriendTypeEnum');
        return CFriendType.friendTypeSingle;
    }
  }

  static int cFriendPendencyType2DartType(int type) {
    switch (type) {
      case CFriendPendencyType.friendPendencyTypeComeIn:
        return FriendApplicationType.V2TIM_FRIEND_APPLICATION_COME_IN;
      case CFriendPendencyType.friendPendencyTypeSendOut:
        return FriendApplicationType.V2TIM_FRIEND_APPLICATION_SEND_OUT;
      case CFriendPendencyType.friendPendencyTypeBoth:
        return FriendApplicationType.V2TIM_FRIEND_APPLICATION_BOTH;
      default:
        print('error: invalid c friend pendency type');
        return FriendApplicationType.V2TIM_FRIEND_APPLICATION_COME_IN;
    }
  }

  static int dartFriendApplicationTypeEnum2CType(
      FriendApplicationTypeEnum type) {
    switch (type) {
      case FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN:
        return CFriendPendencyType.friendPendencyTypeComeIn;
      case FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_SEND_OUT:
        return CFriendPendencyType.friendPendencyTypeSendOut;
      case FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_BOTH:
        return CFriendPendencyType.friendPendencyTypeBoth;
      default:
        print('please input a valid FriendApplicationTypeEnum');
        return CFriendPendencyType.friendPendencyTypeComeIn;
    }
  }

  static int dartFriendApplicationType2CType(int type) {
    switch (type) {
      case FriendApplicationType.V2TIM_FRIEND_APPLICATION_COME_IN:
        return CFriendPendencyType.friendPendencyTypeComeIn;
      case FriendApplicationType.V2TIM_FRIEND_APPLICATION_SEND_OUT:
        return CFriendPendencyType.friendPendencyTypeSendOut;
      case FriendApplicationType.V2TIM_FRIEND_APPLICATION_BOTH:
        return CFriendPendencyType.friendPendencyTypeBoth;
      default:
        print('please input a valid FriendApplicationType');
        return CFriendPendencyType.friendPendencyTypeComeIn;
    }
  }

  static int cFollowType2DartType(int type) {
    switch (type) {
      case CFollowType.followLTypeNone:
        return FollowType.V2TIM_FOLLOW_TYPE_NONE;
      case CFollowType.followLTypeInMyFollowingList:
        return FollowType.V2TIM_FOLLOW_TYPE_IN_MY_FOLLOWING_LIST;
      case CFollowType.followLTypeInMyFollowersList:
        return FollowType.V2TIM_FOLLOW_TYPE_IN_MY_FOLLOWERS_LIST;
      case CFollowType.followLTypeInBothFollowersList:
        return FollowType.V2TIM_FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST;
      default:
        print('error: invalid c follow type');
        return FollowType.V2TIM_FOLLOW_TYPE_NONE;
    }
  }
}
