import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk_example/utils/log_manager.dart';

// 通用样式常量
class APITestStyle {
  // 输入框样式常量
  static const double INPUT_HEIGHT = 30.0;           // 输入框高度
  static const double INPUT_FONT_SIZE = 13.0;        // 输入框字体大小
  static const double INPUT_LABEL_FONT_SIZE = 12.0;  // 输入框标签字体大小
  static const EdgeInsets INPUT_PADDING = EdgeInsets.symmetric(horizontal: 8, vertical: 8); // 输入框内边距
  
  // 按钮样式常量
  static const double BUTTON_HORIZONTAL_PADDING = 5.0;   // 按钮内部左右内边距
  static const double BUTTON_VERTICAL_PADDING = 3.0;     // 按钮内部上下内边距
  static const double BUTTON_MIN_HEIGHT = 30.0;          // 按钮最小高度
  static const double BUTTON_FONT_SIZE = 12.0;           // 按钮文字大小
  static const double BUTTON_BORDER_RADIUS = 4.0;        // 按钮圆角半径
  static const double BUTTON_CHAR_WIDTH = 6.0;           // 每个字符的估计宽度
  static const double BUTTON_EXTRA_WIDTH = 12.0;         // 按钮额外宽度
  static const Color BUTTON_TEXT_COLOR = Colors.white;   // 按钮文字颜色
  static const Color BUTTON_BG_COLOR = Colors.blue;      // 按钮背景颜色
  
  // 布局常量
  static const double HORIZONTAL_SPACING = 8.0;         // 水平间距
  static const double VERTICAL_SPACING = 4.0;           // 垂直间距
  static const double LABEL_WIDTH = 80.0;               // 标签宽度
  
  // 日志区域样式常量
  static const double LOG_AREA_HEIGHT = 180.0;           // 日志区域高度
  static const double LOG_LABEL_FONT_SIZE = 13.0;        // 日志标签字体大小
  static const double LOG_CONTENT_FONT_SIZE = 10.0;      // 日志内容字体大小
  static const Color LOG_LABEL_COLOR = Colors.black;     // 日志标签颜色
  static const Color LOG_CONTENT_COLOR = Colors.black54; // 日志内容颜色
  static const Color LOG_AREA_BG_COLOR = Color(0xFFE8F0F8); // 日志区域背景色
}

// 通用按钮组件
class APITestButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? textColor;

  const APITestButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double buttonWidth = width ?? (text.length * APITestStyle.BUTTON_CHAR_WIDTH + APITestStyle.BUTTON_EXTRA_WIDTH);

    return Container(
      margin: const EdgeInsets.only(bottom: 1.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: APITestStyle.BUTTON_HORIZONTAL_PADDING,
            vertical: APITestStyle.BUTTON_VERTICAL_PADDING,
          ),
          minimumSize: Size(buttonWidth, height ?? APITestStyle.BUTTON_MIN_HEIGHT),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: TextStyle(
            fontSize: fontSize ?? APITestStyle.BUTTON_FONT_SIZE,
          ),
          foregroundColor: textColor ?? APITestStyle.BUTTON_TEXT_COLOR,
          backgroundColor: backgroundColor ?? APITestStyle.BUTTON_BG_COLOR,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(APITestStyle.BUTTON_BORDER_RADIUS),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

// 基础API测试页面组件
class BaseAPITest extends StatefulWidget {
  final String title;
  final List<Widget> inputFields;
  final List<Widget> buttons;
  final VoidCallback onClearLog;

  const BaseAPITest({
    Key? key,
    required this.title,
    required this.inputFields,
    required this.buttons,
    required this.onClearLog,
  }) : super(key: key);

  @override
  State<BaseAPITest> createState() => _BaseAPITestState();
}

class _BaseAPITestState extends State<BaseAPITest> {
  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 监听 LogManager 的变化
    return Consumer<LogManager>(
      builder: (context, logManager, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              TextButton(
                onPressed: widget.onClearLog,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
                child: const Text('清空日志'),
              ),
            ],
          ),
          body: Column(
            children: [
              // 日志区域
              Container(
                height: APITestStyle.LOG_AREA_HEIGHT,
                color: APITestStyle.LOG_AREA_BG_COLOR,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('操作日志: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.logText,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('SDK回调: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.timSDKLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('简单消息: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.simpleMsgLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('高级消息: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.advMsgLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('群组回调: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.groupLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('会话回调: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.conversationLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('好友回调: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.friendshipLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 4),
                        Row(
                          children: [
                            const Text('社群回调: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: APITestStyle.LOG_LABEL_FONT_SIZE,
                                color: APITestStyle.LOG_LABEL_COLOR,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                logManager.communityLog,
                                style: const TextStyle(
                                  fontSize: APITestStyle.LOG_CONTENT_FONT_SIZE,
                                  color: APITestStyle.LOG_CONTENT_COLOR,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // 输入和按钮区域
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 输入字段
                        ...widget.inputFields.map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: APITestStyle.VERTICAL_SPACING),
                          child: field,
                        )).toList(),
                        
                        // 按钮区域
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: APITestStyle.HORIZONTAL_SPACING,
                          runSpacing: APITestStyle.VERTICAL_SPACING,
                          children: widget.buttons,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 