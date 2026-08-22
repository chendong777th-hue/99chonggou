import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
