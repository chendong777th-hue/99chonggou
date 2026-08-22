import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

class Tools {
  static int _userDataSeq = 0;

  static String generateUserData(String apiName) {
    String userData = "";
    if (apiName.isNotEmpty) {
      ++_userDataSeq;
      userData = "$apiName-$_userDataSeq";
    } else {
      throw "get userData error";
    }
    return userData;
  }

  static ffi.Pointer<ffi.Char> string2PointerChar(String data) {
    return data.toNativeUtf8().cast<ffi.Char>();
  }

  static String pointerChar2String(ffi.Pointer<ffi.Char> data) {
    return data.cast<Utf8>().toDartString();
  }

  static ffi.Pointer<ffi.Void> string2PointerVoid(String data) {
    return data.toNativeUtf8().cast<ffi.Void>();
  }

  static void freePointer(ffi.Pointer pointer) {
    calloc.free(pointer);
  }

  static void freePointers(List<ffi.Pointer> pointers) {
    for (var pointer in pointers) {
      calloc.free(pointer);
    }
  }

  static List<Map<String, dynamic>> map2JsonList(Map<String, dynamic> originalMap, String key, String value) {
    return originalMap.entries.map((entry) => {key: entry.key, value: entry.value}).toList();
  }

  static Map<String, T> jsonList2Map<T>(List<Map<String, dynamic>> jsonList, String key, String value) {
    Map<String, T> resultMap = {};
    for (var item in jsonList) {
      if (item[key] is String && item[value] != null) {
        resultMap[item[key] as String] = item[value] as T;
      }
    }
    return resultMap;
  }
}
