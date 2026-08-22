// Copyright (c) 2021 Tencent. All rights reserved.
// Author: abyyxwang

import Flutter
import UIKit
import RTCRoomEngine

public class TUICallKitPlugin: NSObject, BackToFlutterWidgetDelegate, VoIPDataSyncHandlerDelegate, FlutterPlugin {
    static var plugin: TUICallKitPlugin? = nil
    static var isAppInForeground: Bool = false
    let registrar: FlutterPluginRegistrar
    let callKitManager: TUICallKitHandler
    let callEngineManager: TUICallEngineHandler
    var messager: FlutterBinaryMessenger {
        return registrar.messenger()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        TUICallKitPlugin.plugin = TUICallKitPlugin.init(registrar: registrar)
        registrar.register(PlatformVideoViewFactory(messager: registrar.messenger()), withId: "TUICallKitVideoView")
    }
        
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        self.callEngineManager = TUICallEngineHandler(registrar: registrar)
        self.callKitManager = TUICallKitHandler(registrar: registrar)
        
        super.init()
        
        WindowManger.instance.backToFlutterWidgetDelegate = self
        TUICallKitService.instance.voipDataSyncHandler.voipDataSyncHandlerDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func applicationWillResignActive() {
        TUICallKitPlugin.isAppInForeground = false
        CallPipLogger.log("applicationWillResignActive")
        CallPictureInPictureBridge.enterBackgroundIfNeeded()
        callKitManager.appEnterBackground()
    }

    @objc func applicationDidEnterBackground() {
        CallPipLogger.log("applicationDidEnterBackground")
        CallPictureInPictureBridge.enterBackgroundIfNeeded()
    }

    @objc func applicationDidBecomeActive() {
        TUICallKitPlugin.isAppInForeground = true
        CallPipLogger.log("applicationDidBecomeActive")
        CallPictureInPictureBridge.enterForegroundIfNeeded()
        if WindowManger.instance.isCallFloatWindowVisible() {
            WindowManger.instance.closeFloatWindow()
        }
        callKitManager.appEnterForeground()
    }
}

extension TUICallKitPlugin {
    // MARK: BackToFlutterWidgetDelegate
    func backCallingPageFromFloatWindow() {
        callKitManager.backCallingPageFromFloatWindow()
    }
    
    func launchCallingPageFromIncomingBanner() {
        callKitManager.launchCallingPageFromIncomingBanner()
    }
    
    // MARK: TUICallKitServiceDelegate
    func callMethodVoipChangeMute(mute: Bool) {
        callKitManager.callMethodVoipChangeMute(mute: mute)
    }
    
    func callMethodVoipChangeAudioPlaybackDevice(audioPlaybackDevice: TUIAudioPlaybackDevice) {
        callKitManager.callMethodVoipChangeAudioPlaybackDevice(audioPlaybackDevice: audioPlaybackDevice)
    }
    
    func callMethodVoipHangup() {
        callKitManager.callMethodVoipHangup()
    }
    
    func callMethodVoipAccept() {
        callKitManager.callMethodVoipAccept()
    }
}
