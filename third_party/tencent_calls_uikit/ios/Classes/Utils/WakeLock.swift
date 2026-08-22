//
//  WakeLock.swift
//  tencent_calls_uikit
//
//  Created by vincepzhang on 2024/5/17.
//

import Foundation
import UIKit

enum CallScreenPowerPolicy: Int {
    case off = 0
    case keepAwake = 1
    case proximityEarpiece = 2
}

class WakeLock {
    
    private static let instance = WakeLock()
    
    private init() {}
    
    static func shareInstance() -> WakeLock {
        return instance
    }
    
    private var currentPolicy: CallScreenPowerPolicy = .off
    private var savedIdleTimerDisabled = false
    private var didCaptureIdleTimerState = false
    
    func enable() {
        applyPolicy(.keepAwake)
    }

    func disable() {
        applyPolicy(.off)
    }
    
    func applyPolicy(_ policy: CallScreenPowerPolicy) {
        DispatchQueue.main.async {
            if self.currentPolicy == policy {
                return
            }
            self.currentPolicy = policy
            self.applyPolicyOnMainThread(policy)
        }
    }
    
    private func applyPolicyOnMainThread(_ policy: CallScreenPowerPolicy) {
        switch policy {
        case .off:
            self.disableProximityMonitoring()
            self.restoreIdleTimer()
        case .keepAwake:
            self.disableProximityMonitoring()
            self.enableIdleTimerLock()
        case .proximityEarpiece:
            self.restoreIdleTimer()
            self.enableProximityMonitoring()
        }
    }
    
    private func enableIdleTimerLock() {
        if !didCaptureIdleTimerState {
            savedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            didCaptureIdleTimerState = true
        }
        if !savedIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    private func restoreIdleTimer() {
        if didCaptureIdleTimerState && !savedIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        didCaptureIdleTimerState = false
    }
    
    private func enableProximityMonitoring() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled && device.proximityState {
            // 系统会在 proximityState=true 时自动熄屏；此处确保监听已生效。
        }
    }
    
    private func disableProximityMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = false
    }
}
