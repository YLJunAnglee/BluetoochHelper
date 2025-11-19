//
//  Logger.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//

import Foundation
import os.log

public class Logger {
    
    public static var logger: LoggerDelegate?
    public static var logLevel: OSLogType = .default
    
    public static func log(message: String, ofCategory category: String, withType type: OSLogType) {
        guard type >= logLevel else { return }
        guard let logger = logger else { return }
        
        logger.log(message: message, ofCategory: category, withType: type)
    }
    /// 绿色
    public static func d(_ category: String, _ message: String) {
        log(message: message, ofCategory: category, withType: .debug)
    }
    /// 绿色
    public static func d(_ categoryClass: Any, _ message: String) {
        log(message: message, ofCategory: String(describing: type(of: categoryClass)), withType: .debug)
    }
    /// 蓝色
    public static func i(_ categoryClass: Any, _ message: String) {
        log(message: message, ofCategory: String(describing: type(of: categoryClass)), withType: .info)
    }
    /// 蓝色
    public static func i(_ category: String, _ message: String) {
        log(message: message, ofCategory: category, withType: .info)
    }
    /// 黑色
    public static func n(_ category: String, _ message: String) {
        log(message: message, ofCategory: category, withType: .default)
    }
    /// 黑色
    public static func n(_ categoryClass: Any, _ message: String) {
        log(message: message, ofCategory: String(describing: type(of: categoryClass)), withType: .default)
    }
    /// 红色
    public static func e(_ category: String, _ message: String) {
        log(message: message, ofCategory: category, withType: .error)
    }
    /// 红色
    public static func e(_ categoryClass: Any, _ message: String) {
        log(message: message, ofCategory: String(describing: type(of: categoryClass)), withType: .error)
    }
    /// 红色
    public static func e(_ category: String, _ error: Error) {
        log(message: error.localizedDescription, ofCategory: category, withType: .error)
    }
    /// 红色
    public static func e(_ categoryClass: Any, _ error: Error) {
        log(message: error.localizedDescription, ofCategory: String(describing: type(of: categoryClass)), withType: .error)
    }
    /// 棕色
    public static func f(_ category: String, _ message: String) {
        log(message: message, ofCategory: category, withType: .fault)
    }
    /// 棕色
    public static func f(_ categoryClass: Any, _ message: String) {
        log(message: message, ofCategory: String(describing: type(of: categoryClass)), withType: .fault)
    }
    /// 棕色
    public static func f(_ category: String, _ error: Error) {
        log(message: error.localizedDescription, ofCategory: category, withType: .fault)
    }
    /// 棕色
    public static func f(_ categoryClass: Any, _ error: Error) {
        log(message: error.localizedDescription, ofCategory: String(describing: type(of: categoryClass)), withType: .fault)
    }
}

fileprivate extension OSLogType {
    var logLevel: Int {
        switch self {
        case .debug:    return 2
        case .info:     return 3
        case .default:  return 4
        case .error:    return 5
        case .fault:    return 6
        default:        return 4 // never happen
        }
    }
}

fileprivate extension OSLogType {
    
    static func < (lhs: OSLogType, rhs: OSLogType) -> Bool {
        return lhs.logLevel < rhs.logLevel
    }
    
    static func <= (lhs: OSLogType, rhs: OSLogType) -> Bool {
        return lhs.logLevel <= rhs.logLevel
    }
    
    static func >= (lhs: OSLogType, rhs: OSLogType) -> Bool {
        return lhs.logLevel >= rhs.logLevel
    }
    
    static func > (lhs: OSLogType, rhs: OSLogType) -> Bool {
        return lhs.logLevel > rhs.logLevel
    }
}

