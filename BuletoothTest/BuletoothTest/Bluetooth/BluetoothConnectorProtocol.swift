//
//  BluetoothConnectorProtocol.swift
//  BuletoothTest
//
//  Created by 连俊杨 on 2025/7/16.
//

import Foundation
import CoreBluetooth

/// 状态返回代理
protocol BluetoothConnectorStatusDelegate: NSObjectProtocol {
    func connectorBluetoothStatusReturn(status: CBManagerState)
    func connectorScanStatusReturn(status: BluetoothScanStatus)
    func connectorConnectorStatusReturn(status: BluetoothConnectStatus)
    func connectorCharacteristicNotifyReturn(peripheral: CBPeripheral,
                                             characteristic: CBCharacteristic,
                                             status: BluetoothCharacteristicNotifyStatus)
}

/// 事件返回代理
protocol BluetoothConnectorDataSourceDelegate: NSObjectProtocol {
    /// 扫描结果
    func centralManagerDidDiscoverPeripheral(central: CBCentralManager,
                                             peripheral: CBPeripheral,
                                             advertisementData: [String: Any],
                                             RSSI: NSNumber)
    /// 注册方法结果
    func centralManagerConnectionEventDidOccur(central: CBCentralManager,
                                               event: CBConnectionEvent,
                                               peripheral: CBPeripheral)
    /// 特征值更新
    func peripheralCharacteristicDidUpdateValue(peripheral: CBPeripheral,
                                                characteristic: CBCharacteristic)
}
