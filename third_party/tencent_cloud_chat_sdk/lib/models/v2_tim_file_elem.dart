import 'dart:io';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFileElem
///
/// {@category Models}
///
class V2TimFileElem extends V2TIMElem {
  /// 文件本地路径，仅在发送消息成功之前有效，用作文件本地预览
  late String? path;

  /// 文件名
  late String? fileName;
  // ignore: non_constant_identifier_names
  late String? UUID;

  /// 文件url，默认不返回，通过getMessageOnlineUrl获取
  late String? url;

  /// 文件大小
  late int? fileSize;

  /// 文件本地路径，downloadMessage之后有值
  String? localUrl;

  V2TimFileElem({
    this.path,
    this.fileName,
    // ignore: non_constant_identifier_names
    this.UUID,
    this.url,
    this.fileSize,
    this.localUrl,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_FILE);

  bool renameFile(String sourceFile, String destinationFile) {
    final file = File(sourceFile);

    try {
      if (file.existsSync()) {
        file.renameSync(destinationFile);
        print("rename file successfully | sourceFile: $sourceFile | destinationFile: $destinationFile");
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Error in renaming file: ${e.toString()}");
      return false;
    }
  }

  String? getDefaultLocalUrl() {
    var cacheDir = CommonUtils.appFileDir;
    String filePath = UUID ?? '';
    String filePathOld = UUID ?? '';

    if (Platform.isAndroid) {
      var separator = UUID?.contains('.') == true ? '' : '_';
      filePath = 'file_$UUID$separator${Uri.encodeComponent(fileName ?? "").replaceAll('%20', '+')}';
    } else if (Platform.isIOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/$UUID/${fileName ?? ""}';
      filePathOld = '$filePathPrefix/$UUID/${Uri.encodeComponent(fileName ?? "")}';
    } else if (Platform.isMacOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/$UUID/${fileName ?? ""}';
    } else if (Platform.isWindows) {
      String filePathPrefix = 'TencentCloudChat/DownLoad/${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/$UUID/$fileName';
    } else if (Platform.operatingSystem == 'ohos') {
      filePath = 'file_${Uri.encodeComponent(fileName ?? "")}';
    }

    var defaultLocalUrl = '${cacheDir.path}/$filePath';
    if (File(defaultLocalUrl).existsSync()) {
      return defaultLocalUrl;
    }

    if (Platform.isAndroid && CommonUtils.externalCacheDir != null) {
      defaultLocalUrl = '${CommonUtils.externalCacheDir!.parent.path}/cache/$filePath';
      if (File(defaultLocalUrl).existsSync()) {
        return defaultLocalUrl;
      }
    }

    if (Platform.isIOS) {
      var localUrlOld = '${cacheDir.path}/$filePathOld';
      if (renameFile(localUrlOld, defaultLocalUrl)) {
        return defaultLocalUrl;
      }
    }

    return null;
  }

  V2TimFileElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_FILE;
    json = Utils.formatJson(json);
    path = json['file_elem_file_path'];
    UUID = json['file_elem_file_id'];
    fileName = json['file_elem_file_name'];
    fileSize = json['file_elem_file_size'];
    url = json['file_elem_url'];

    localUrl = getDefaultLocalUrl();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemFile;
    data['file_elem_file_path'] = path;
    data['file_elem_file_id'] = UUID;
    data['file_elem_file_name'] = fileName;
    data['file_elem_file_size'] = fileSize;
    data['file_elem_url'] = url;

    data['localUrl'] = localUrl;
    return data;
  }
  String toLogString() {
    String res = "path:${path == null ? false : true}|fileName:$fileName|UUID:$UUID|fileSize:$fileSize|localUrl:${localUrl == null ? false : true}";
    return res;
  }
}
