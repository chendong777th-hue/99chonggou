#import "AWVPAudioSessionAsync.h"

void AWVPSetAudioSessionActiveAsync(BOOL active, AVAudioSessionSetActiveOptions options) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [[AVAudioSession sharedInstance] setActive:active withOptions:options error:nil];
    });
}

void AWVPSetAudioSessionCategoryAsync(NSString *category, AVAudioSessionCategoryOptions options) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [[AVAudioSession sharedInstance] setCategory:category
                                         withOptions:options
                                               error:nil];
    });
}
