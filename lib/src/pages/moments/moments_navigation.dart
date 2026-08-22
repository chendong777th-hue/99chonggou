import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_page.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';

Future<void> openAuthorMomentsPage(
  BuildContext context, {
  required MomentUserSnapshot author,
}) async {
  final authorId = author.id.trim();
  if (authorId.isEmpty) {
    return;
  }
  final profileName = UserDisplayProfile.nameOfSnapshot(author);
  final avatarUrl = UserDisplayProfile.avatarOfSnapshot(author);
  await Navigator.push<void>(
    context,
    AppMaterialPageRoute(
      builder: (_) => MomentsPage(
        authorId: authorId,
        profileName: profileName,
        profileAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        showCoverHeader: true,
      ),
    ),
  );
}
