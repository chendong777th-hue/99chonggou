import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

import 'calling_message_data_provider.dart';

class GroupCallMessageItem extends StatelessWidget {
  final CallingMessageDataProvider callingMessageDataProvider;

  const GroupCallMessageItem({
    Key? key,
    required this.callingMessageDataProvider,
  }) : super(key: key);

  Widget _wrapMessageTips(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!callingMessageDataProvider.shouldDisplayInHistory) {
      return const SizedBox.shrink();
    }

    return _wrapMessageTips(
      Text(
        callingMessageDataProvider.content,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: hexToColor('888888'),
        ),
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
  }
}
