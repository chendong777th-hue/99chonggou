import 'package:flutter/material.dart';
import 'package:tencent_calls_uikit/src/data/constants.dart';

const String kCallAvatarPlaceholder = 'assets/default_c2c_head.png';

class CallAvatarView extends StatelessWidget {
  final String? url;
  final double size;
  final BoxFit fit;

  const CallAvatarView({
    Key? key,
    required this.url,
    required this.size,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CallAvatarImage(url: url, fit: fit),
      ),
    );
  }
}

class CallAvatarImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const CallAvatarImage({
    Key? key,
    required this.url,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final src = _cleanUrl(url);
    if (src.isEmpty) {
      return Image.asset(kCallAvatarPlaceholder, fit: fit);
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(kCallAvatarPlaceholder, fit: fit),
      );
    }

    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset(kCallAvatarPlaceholder, fit: fit),
      );
    }

    return Image.asset(kCallAvatarPlaceholder, fit: fit);
  }

  String _cleanUrl(String? value) {
    final src = (value ?? '').trim();
    if (src.isEmpty || src == 'null' || src == Constants.defaultAvatar) {
      return '';
    }
    return src;
  }
}
