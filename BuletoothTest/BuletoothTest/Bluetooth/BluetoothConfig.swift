//
//  BluetoothConfig.swift
//  BuletoothTest
//
//  Created by 连俊杨 on 2025/7/12.
//

import Foundation
import CoreBluetooth

struct BluetoothConfig: Equatable {
    /// 一个外设服务连接时对应一个BluetoothConfig
    /// 一个外设可以连接多个服务，那么这个外设就可以对应多个BluetoothConfig
    /// 多个BluetoothConfig之间通过identify区分
    var identify: String = ""
    var serviceUUID             = CBUUID(string: "00001100-D102-11E1-9B23-00025B00A5A5")
    var characteristicsUUID     = CBUUID(string: "00001101-D102-11E1-9B23-00025B00A5A5")
    var characteristicsUUIDRx   = CBUUID(string: "00001102-D102-11E1-9B23-00025B00A5A5")
    
    /// 判断相等
    static func == (lhs: BluetoothConfig, rhs: BluetoothConfig) -> Bool {
        return (lhs.identify == rhs.identify)
    }
}
