/// Pure helper for foreground history recovery early-exit decisions.
bool isRecoveryAlreadySatisfied({
  required bool changed,
  required bool hasMessages,
  required bool previewAhead,
  bool hasDeferredIncoming = false,
  bool cloudCatchUpRequired = false,
  bool cloudCatchUpAttempted = false,
}) {
  if (changed) {
    return false;
  }
  if (!hasMessages) {
    return false;
  }
  if (previewAhead) {
    return false;
  }
  if (hasDeferredIncoming) {
    return false;
  }
  // Warm resume: local bubbles alone do not prove the server gap is closed.
  if (cloudCatchUpRequired && !cloudCatchUpAttempted) {
    return false;
  }
  return true;
}
