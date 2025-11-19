//
//  AppLogger.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//

import Foundation
import os.log
import ABLoggerKit

public class AppLogger: ABLogger {
    
    public override class func setupLogger() {
        // 配置FOTA的Log代理
        Logger.logger = {
            class AnonymousLogger: LoggerDelegate {
                func log(message: String, ofCategory category: String, withType type: OSLogType) {
                    ABLogger.log(message, ofCategory: category, withType: type)
                }
            }
            return AnonymousLogger()
        }()
        
        super.setupLogger()
    }
    
    public class func enableVerboseMode() {
        Logger.logLevel = .debug
        
        // 输入Level
        Logger.logLevel = .debug
        // View/File/Console的Level，可分开设置
        setLogLevel(.debug)
    }
}

