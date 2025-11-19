//
//  BlePeripheralStore.swift
//  BuletoothTest
//
//  Created by 连俊杨 on 2025/7/14.
//

import Foundation
import CoreBluetooth

struct BlePeripheralStore {
    /// 连接的外设
    var connectPeripherals: [BlePeripheralModel] = [BlePeripheralModel]()
}

extension BlePeripheralStore {
    /// 判断想连接的外设和服务是否之前没有
    func isNewPeripheralOrService(peripheral: CBPeripheral, bluetoothConfig: BluetoothConfig) -> (Bool, Int) {
        var ret: Bool = true
        var retIndex: Int = -1
        for (idx, pm) in connectPeripherals.enumerated() {
            if pm.peripheral == peripheral && pm.config == bluetoothConfig {
                ret = false
                retIndex = idx
                break
            }
        }
        return (ret, retIndex)
    }
    /// 增加模型
    mutating func addPeripheralModel(model: BlePeripheralModel) {
        connectPeripherals.append(model)
    }
    /// 获取当前未连接成功的模型
    func getUnConnectConfig(peripheral: CBPeripheral) -> BluetoothConfig? {
        let ret = connectPeripherals.filter({$0.peripheral == peripheral && $0.isConnect == false}).first
        return ret?.config
    }
    /// 寻找下标
    private func findTargetIndex(peripheral: CBPeripheral, config: BluetoothConfig) -> Int {
        var retIndex: Int = -1
        for (idx, pm) in connectPeripherals.enumerated() {
            if pm.peripheral == peripheral && pm.config == config {
                retIndex = idx
                break
            }
        }
        return retIndex
    }
    /// 更新特征
    mutating func addCharacteristic(for peripheral: CBPeripheral, config: BluetoothConfig, characteristic: CBCharacteristic) {
        let index = findTargetIndex(peripheral: peripheral, config: config)
        if index < 0 || index >= connectPeripherals.count {
            Logger.d(self, "未找到需要更新的存储对象")
            return
        }
        var targetPM = connectPeripherals[index]
        if targetPM.characteristics == nil {
            targetPM.characteristics = [characteristic]
            connectPeripherals[index] = targetPM
        } else {
            var characteristics = targetPM.characteristics
            if !(characteristics?.contains(characteristic) ?? false) {
                characteristics?.append(characteristic)
                targetPM.characteristics = characteristics
                connectPeripherals[index] = targetPM
            }
        }
    }
    /// 更新模型的连接状态
    mutating func updateUnConnectConfig(peripheral: CBPeripheral, config: BluetoothConfig, isConnect: Bool) {
        let index = findTargetIndex(peripheral: peripheral, config: config)
        if index < 0 || index >= connectPeripherals.count {
            Logger.d(self, "未找到需要更新的存储对象")
            return
        }
        connectPeripherals[index].isConnect = isConnect
    }
    /// 更新某个外设关联的所有模型的连接状态
    mutating func updateConfigStats(for peripheral: CBPeripheral, isConnect: Bool, needClearCharacteristics: Bool = false) {
        for (idx, pm) in connectPeripherals.enumerated() {
            if pm.peripheral == peripheral {
                connectPeripherals[idx].isConnect = isConnect
                if needClearCharacteristics {
                    connectPeripherals[idx].characteristics = nil
                }
            }
        }
    }
    /// 更新所有外设关联的所有模型的连接状态为初始值
    mutating func updateAllConfigStats(isConnect: Bool, needClearCharacteristics: Bool = false) {
        for (idx, pm) in connectPeripherals.enumerated() {
            connectPeripherals[idx].isConnect = isConnect
            if needClearCharacteristics {
                connectPeripherals[idx].characteristics = nil
            }
        }
    }
    /// 查找PM中可写的特征
    /// 返回值1表示，当前是否连接
    func findPeripheralWriteCharacteristic(peripheral: CBPeripheral, config: BluetoothConfig) -> (Bool ,CBCharacteristic?) {
        let pm = connectPeripherals.filter({$0.peripheral == peripheral && $0.config == config}).first
        let writeCharacteristic = pm?.characteristics?.filter({$0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)}).first
        return (pm?.isConnect ?? false, writeCharacteristic)
    }
    /// 查找特定config对应的PM中可读的特征
    func findPeripheralNotifyCharacteristic(peripheral: CBPeripheral, config: BluetoothConfig) -> CBCharacteristic? {
        let pm = connectPeripherals.filter({$0.peripheral == peripheral && $0.config == config}).first
        let notifyCharacteristic = pm?.characteristics?.filter({$0.properties.contains(.notify) || $0.properties.contains(.notifyEncryptionRequired)}).first
        return notifyCharacteristic
    }
    /// 查找某个外设的所有服务中的可读特征
    /// 用于断开连接取消监听
    func findPeripheralNotifyCharacteristics(peripheral: CBPeripheral) -> [CBCharacteristic]? {
        let pms = connectPeripherals.filter({$0.peripheral == peripheral})
        if pms.count == 0 {
            return nil
        }
        var ret: [CBCharacteristic] = [CBCharacteristic]()
        for pm in pms {
            if let notifyCharacteristics = pm.characteristics?.filter({$0.properties.contains(.notify) || $0.properties.contains(.notifyEncryptionRequired)}), notifyCharacteristics.count > 0 {
                ret.append(contentsOf: notifyCharacteristics)
            }
        }
        return ret
    }
}

struct BlePeripheralModel: Equatable {
    /// 是否已经连接
    var isConnect: Bool = false
    /// 外设
    var peripheral: CBPeripheral?
    /// 每个外设的连接配置
    var config: BluetoothConfig?
    /// 外设的特征
    var characteristics: [CBCharacteristic]?
    
    /// 判断相等
    static func == (lhs: BlePeripheralModel, rhs: BlePeripheralModel) -> Bool {
        return (lhs.peripheral == rhs.peripheral) && (lhs.peripheral != nil) && (rhs.peripheral != nil)
    }
}
