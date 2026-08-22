#import <AVFoundation/AVFoundation.h>

/// 避免主线程同步 XPC 调用 AVAudioSession 导致滑动时 UI hang。
FOUNDATION_EXPORT void AWVPSetAudioSessionActiveAsync(BOOL active, AVAudioSessionSetActiveOptions options);
FOUNDATION_EXPORT void AWVPSetAudioSessionCategoryAsync(NSString *category, AVAudioSessionCategoryOptions options);
