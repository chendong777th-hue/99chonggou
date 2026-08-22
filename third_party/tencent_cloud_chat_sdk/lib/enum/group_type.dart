/// 群组类型
///
/// {@category Enums}
///
// ignore_for_file: constant_identifier_names
import 'group_type_enum.dart';

class GroupType {
  static const String Work = "Work";
  static const String Public = "Public";
  static const String Meeting = "Meeting";
  static const String AVChatRoom = "AVChatRoom";
  static const String Community = "Community";

  static String convertGroupTypeEnum(int groupType){
    if (groupType < 0 || groupType >= GroupTypeEnum.values.length) {
      return "";
    }

    switch (GroupTypeEnum.values[groupType]) {
      case GroupTypeEnum.kTIMGroup_Public:
        return GroupType.Public;
      case GroupTypeEnum.kTIMGroup_Private:
        return GroupType.Work;
      case GroupTypeEnum.kTIMGroup_ChatRoom:
        return GroupType.Meeting;
      case GroupTypeEnum.kTIMGroup_AVChatRoom:
      case GroupTypeEnum.kTIMGroup_BChatRoom:
        return GroupType.AVChatRoom;
      case GroupTypeEnum.kTIMGroup_Community:
        return GroupType.Community;
      default:
        return "";
    }
  }

  static int convertGroupType(String groupType){
    if (groupType == GroupType.Public) {
      return GroupTypeEnum.kTIMGroup_Public.index;
    } else if (groupType == GroupType.Work) {
      return GroupTypeEnum.kTIMGroup_Private.index;
    } else if (groupType == GroupType.Meeting) {
      return GroupTypeEnum.kTIMGroup_ChatRoom.index;
    } else if (groupType == GroupType.AVChatRoom) {
      return GroupTypeEnum.kTIMGroup_AVChatRoom.index;
    } else if (groupType == GroupType.Community) {
      return GroupTypeEnum.kTIMGroup_Community.index;
    } else {
      return GroupTypeEnum.kTIMGroup_Public.index;
    }
  }
}
