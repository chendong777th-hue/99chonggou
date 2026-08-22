/// Whether warm/foreground recovery may call V2TIM_GET_CLOUD_NEWER_MSG
/// even when conversation preview is not ahead of local history.
bool shouldAllowCloudCatchUp({
  required String? source,
  required bool previewAhead,
}) {
  if (previewAhead) {
    return true;
  }
  switch (source) {
    case 'app_resumed':
    case 'im_reconnected':
    case 'connect_success':
    case 'sync_server_finish':
      return true;
    default:
      return false;
  }
}
