//
//  CallPipLogger.swift
//  tencent_calls_uikit
//

import Foundation

enum CallPipLogger {
    static func log(_ message: String) {
        NSLog("[CallPip] %@", message)
    }
}
