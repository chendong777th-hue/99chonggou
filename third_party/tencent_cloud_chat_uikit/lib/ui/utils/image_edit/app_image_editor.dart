import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class AppImageEditor {
  AppImageEditor._();

  static bool get isSupported =>
      !kIsWeb && PlatformUtils().isMobile;

  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static const MainEditorStyle _mainEditorStyle = MainEditorStyle(
    background: Colors.black,
    bottomBarColor: Colors.white,
    bottomBarBackground: Colors.black,
    appBarColor: Colors.white,
    appBarBackground: Colors.black,
    uiOverlayStyle: _overlayStyle,
  );

  static const PaintEditorStyle _paintEditorStyle = PaintEditorStyle(
    background: Colors.black,
    appBarBackground: Colors.black,
    bottomBarBackground: Colors.black,
    uiOverlayStyle: _overlayStyle,
  );

  static const TextEditorStyle _textEditorStyle = TextEditorStyle(
    background: Colors.black,
    appBarBackground: Colors.black,
    bottomBarBackground: Colors.black,
    textFieldMargin: EdgeInsets.zero,
  );

  static const CropRotateEditorStyle _cropEditorStyle = CropRotateEditorStyle(
    background: Colors.black,
    appBarBackground: Colors.black,
    bottomBarBackground: Colors.black,
    cropCornerColor: Colors.white,
    helperLineColor: Colors.white,
    uiOverlayStyle: _overlayStyle,
  );

  static ProImageEditorConfigs get configs => ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.cupertino,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          canvasColor: Colors.black,
          dialogBackgroundColor: const Color(0xFF1C1C1E),
        ),
        i18n: const I18n(
          cancel: '取消',
          undo: '撤销',
          redo: '重做',
          done: '完成',
          doneLoadingMsg: '正在应用修改',
          various: I18nVarious(
            closeEditorWarningTitle: '关闭编辑器？',
            closeEditorWarningMessage: '确定要关闭编辑器吗？未保存的更改将丢失。',
            closeEditorWarningConfirmBtn: '确定',
            closeEditorWarningCancelBtn: '取消',
          ),
          paintEditor: I18nPaintEditor(
            bottomNavigationBarText: '涂鸦',
            freestyle: '画笔',
            arrow: '箭头',
            line: '直线',
            rectangle: '矩形',
            circle: '圆形',
            dashLine: '虚线',
            blur: '马赛克',
            eraser: '橡皮',
            moveAndZoom: '缩放',
            lineWidth: '线宽',
            changeOpacity: '透明度',
            undo: '撤销',
            redo: '重做',
            done: '完成',
          ),
          textEditor: I18nTextEditor(
            inputHintText: '输入文字',
            bottomNavigationBarText: '文字',
            back: '返回',
            done: '完成',
            textAlign: '对齐',
            fontScale: '字号',
            backgroundMode: '背景',
          ),
          cropRotateEditor: I18nCropRotateEditor(
            bottomNavigationBarText: '裁剪',
            rotate: '旋转',
            flip: '翻转',
            ratio: '比例',
            back: '返回',
            done: '完成',
            reset: '重置',
          ),
        ),
        mainEditor: const MainEditorConfigs(style: _mainEditorStyle),
        paintEditor: const PaintEditorConfigs(style: _paintEditorStyle),
        textEditor: const TextEditorConfigs(style: _textEditorStyle),
        cropRotateEditor: const CropRotateEditorConfigs(style: _cropEditorStyle),
        emojiEditor: EmojiEditorConfigs(enabled: false),
        filterEditor: FilterEditorConfigs(enabled: false),
        blurEditor: BlurEditorConfigs(enabled: false),
        tuneEditor: TuneEditorConfigs(enabled: false),
        stickerEditor: StickerEditorConfigs(enabled: false),
      );

  /// 打开完整图片编辑器，成功返回编辑后的临时文件。
  static Future<File?> open(BuildContext context, File sourceFile) async {
    if (!isSupported || !await sourceFile.exists()) {
      return null;
    }

    final Uint8List? bytes = await Navigator.of(context).push<Uint8List?>(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (editorContext, animation, secondaryAnimation) {
          Uint8List? editedBytes;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: _overlayStyle,
            child: ColoredBox(
              color: Colors.black,
              child: ProImageEditor.file(
                sourceFile,
                configs: configs,
                callbacks: ProImageEditorCallbacks(
                  onImageEditingComplete: (Uint8List result) async {
                    editedBytes = result;
                  },
                  onCloseEditor: (EditorMode mode) {
                    if (mode != EditorMode.main) {
                      Navigator.pop(editorContext);
                      return;
                    }
                    Navigator.pop(editorContext, editedBytes);
                  },
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }
}
