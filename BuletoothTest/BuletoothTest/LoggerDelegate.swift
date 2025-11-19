//
//  LoggerDelegate.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//

import Foundation
import os.log

public protocol LoggerDelegate {
    func log(message: String, ofCategory category: String, withType type: OSLogType)
}
