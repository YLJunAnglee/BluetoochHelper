//
//  BlueTool.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//

import Foundation
import UIKit
import CoreBluetooth

/// 特征值的读写类型
func testPropsType(props: CBCharacteristicProperties) -> String {
    var propertyStrings: [String] = []
    
    if props.contains(.read) {
        propertyStrings.append("Read")
    }
    if props.contains(.write) {
        propertyStrings.append("Write")
    }
    if props.contains(.writeWithoutResponse) {
        propertyStrings.append("WriteWithoutResponse")
    }
    if props.contains(.notify) {
        propertyStrings.append("Notify")
    }
    if props.contains(.indicate) {
        propertyStrings.append("Indicate")
    }
    if props.contains(.broadcast) {
        propertyStrings.append("Broadcast")
    }
    if props.contains(.authenticatedSignedWrites) {
        propertyStrings.append("AuthenticatedSignedWrites")
    }
    if props.contains(.extendedProperties) {
        propertyStrings.append("ExtendedProperties")
    }
    if props.contains(.notifyEncryptionRequired) {
        propertyStrings.append("NotifyEncryptionRequired")
    }
    if props.contains(.indicateEncryptionRequired) {
        propertyStrings.append("IndicateEncryptionRequired")
    }
    return propertyStrings.joined(separator: "，")
}

let nav_window = UIApplication.shared.windows.filter{$0.isKeyWindow}.first
// 状态栏高度
let StatusBarHeight : CGFloat = nav_window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
// 导航栏高度： 状态栏高度 + 44
let NavigationHeight : CGFloat = StatusBarHeight + 44

// 屏幕宽度
let Screen_width = UIScreen.main.bounds.size.width
// 屏幕高度
let Screen_height = UIScreen.main.bounds.size.height

extension Data {
    init?(hex: String) {
        guard hex.count % 2 == 0 else {
            return nil
        }
        let len = hex.count / 2
        var data = Data(capacity: len)
        
        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    
    /// Hexadecimal string representation of `Data` object.
    var hex: String {
        return map { String(format: "%02X", $0) }.joined()
    }
}

func matchBrandSoundDevice(deviceName: String) -> Bool {
    let name = deviceName.lowercased()
    if name.hasPrefix("BrandSound".lowercased()) || name.hasPrefix("B639".lowercased()) || name.hasPrefix("B626".lowercased()) {
        return true
    } else {
        return false
    }
}

func matchMetaLaneChatDevice(deviceName: String) -> Bool {
    let name = deviceName.lowercased()
    if name.hasPrefix("MetaLens Chat".lowercased()) || name.hasPrefix("Meta Lens Chat".lowercased()) {
        return true
    } else {
        return false
    }
}

func matchLAWKCityDevice(deviceName: String) -> Bool {
    let name = deviceName.lowercased()
    if name.hasPrefix("LAWK City".lowercased()) {
        return true
    } else {
        return false
    }
}
