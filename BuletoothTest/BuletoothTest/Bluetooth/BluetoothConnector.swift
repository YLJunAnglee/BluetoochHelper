//
//  BluetoothConnector.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//
//  蓝牙连接工具

import Foundation
import CoreBluetooth

class BluetoothConnector: NSObject {
    /// 工具
    private var centralManager: CBCentralManager?
    /// 单例
    static let shared = BluetoothConnector()
    /// 状态代理
    public weak var statusDelegate: BluetoothConnectorStatusDelegate?
    /// 数据代理
    public weak var dataSource: BluetoothConnectorDataSourceDelegate?
    /// 扫描状态
    private var scanStatus: BluetoothScanStatus = .unknow
    /// 记录当前正在连接的config，连接完成置空
    private var currentConnectConfig: BluetoothConfig?
    /// 连接状态
    private var connectStatus: BluetoothConnectStatus = .unknow
    /// 数据存储
    private var mBlePeripheralStore: BlePeripheralStore = BlePeripheralStore()
    /// 连接超时标记
    private var connectTimeout: Bool = false
    
    private override init() {
        super.init()
        if centralManager == nil {
            initCentralManager()
        }
    }
    
    /// 获取管理器
    public func getCentralManager() -> CBCentralManager? {
        return centralManager
    }
    
    /// 销毁
    public func destroy() {
        
    }

    /// 1.扫描
    public func startScan(with services: [CBUUID]?, options: [String: Any]?) {
        if scanStatus == .scaning {
            Logger.d(self, "正在扫描中...")
            return
        }
        var tmpOptions = [String: Any]()
        tmpOptions[CBCentralManagerScanOptionAllowDuplicatesKey] = false
        if let options = options,
           let solicitedServiceUUIDs = options[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] {
            tmpOptions[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = solicitedServiceUUIDs
        }
        centralManager?.scanForPeripherals(withServices: services, options: tmpOptions)
        scanStatusChange(status: .scaning)
    }
    
    /// 2.注册方法
    public func startRegist(with options: [CBConnectionEventMatchingOption: Any]?) {
        if scanStatus == .scaning {
            Logger.d(self, "正在注册扫描中...")
            return
        }
        Logger.d(self, "开始注册...\(String(describing: options))")
        /// 注册一个系统蓝牙连接事件的监听
        /// 系统蓝牙连接或者断开，都会回调centralManager:connectionEventDidOccur:forPeripheral
        centralManager?.registerForConnectionEvents(options: options)
        scanStatusChange(status: .scaning)
    }
    
    /// 3.停止扫描
    public func stopScan() {
        if scanStatus == .scaning {
            centralManager?.stopScan()
            scanStatusChange(status: .stop)
        }
    }
    
    /// 4.连接设备
    public func connectToPeripheral(peripheral: CBPeripheral, bluetoothConfig: BluetoothConfig) {
        if connectStatus == .connecting {
            Logger.d(self, "正在连接中...")
            return
        }
        /// 1.停止扫描
        stopScan()
        /// 2.存储对象
        let isNew = mBlePeripheralStore.isNewPeripheralOrService(peripheral: peripheral, bluetoothConfig: bluetoothConfig)
        currentConnectConfig = bluetoothConfig
        if isNew.0 {
            /// 新连接
            var connectPeripheral = BlePeripheralModel()
            connectPeripheral.peripheral = peripheral
            connectPeripheral.config = bluetoothConfig
            mBlePeripheralStore.addPeripheralModel(model: connectPeripheral)
            centralManager?.connect(peripheral, options: nil) /// 参数options待发掘
        } else {
            /// 旧连接，认为是重连
            centralManager?.connect(peripheral, options: nil) /// 参数options待发掘
        }
        /// 3.返回状态
        connectStatusChange(status: .connecting)
        /// 4.10s如果连接不上，认为是失败
        connectTimeout = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if (self.connectTimeout) {
                self.connectStatusChange(status: .failure)
                self.currentConnectConfig = nil
            }
        }
        Logger.d(self, "开始连接...")
    }
    
    /// 5.发送指令
    public func sendData(data: Data, peripheral: CBPeripheral, config: BluetoothConfig) {
        Logger.i(self, "sendData---\(data.hex)")
        let characteristic = getWriteCharacteristic(peripheral: peripheral, config: config)
        guard characteristic.0 == true else {
            Logger.i(self, "当前连接已断开...")
            return
        }
        guard let characteristic = characteristic.1 else {
            Logger.i(self, "没有发现可写属性，peripheral=\(peripheral)")
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// 6.断开连接
    public func disConnectToPeripheral(peripheral: CBPeripheral) {
        guard let centralManager = centralManager else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        self.currentConnectConfig = nil
    }
}

/// 初始化
extension BluetoothConnector {
    /// 初始化中心管理器
    private func initCentralManager() {
        /**
            对应info.plist里面的 Required background modes
            结果：["audio", "bluetooth-central", "location", "bluetooth-peripheral", "remote-notification"]
         */
        let backgroundModes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String]
        
        if (backgroundModes?.contains("bluetooth-central") ?? false) {
            /// The background model
            ///  *    @seealso        CBCentralManagerOptionShowPowerAlertKey
            ///  *    @seealso        CBCentralManagerOptionRestoreIdentifierKey
            let options: [String: Any] = [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: "yljBluetoothRestore"
            ]
            centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: options)
        } else {
            /// Non-background mode
            centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        }
    }
}

/// CBCentralManagerDelegate
extension BluetoothConnector: CBCentralManagerDelegate {
    /// 基本上系统蓝牙关闭和打开，就回调poweredOff和poweredOn
    /// 初始化的时候，也会回调
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        statusDelegate?.connectorBluetoothStatusReturn(status: central.state)
        switch central.state {
        case .unknown:
            Logger.d(self, "蓝牙状态未知")
        case .resetting:
            Logger.d(self, "与系统服务的连接，暂时丢失，即将更新")
        case .unsupported:
            Logger.d(self, "不支持低功耗蓝牙")
        case .unauthorized:
            Logger.d(self, "未经授权低功耗蓝牙")
        case .poweredOff:
            Logger.d(self, "低功耗蓝牙关闭")
            disconnectAllPeripheral()
        case .poweredOn:
            Logger.d(self, "低功耗蓝牙打开，可供使用")
        default:
            break
        }
    }
    /// 1.1扫描回调centralManager:didDiscoverPeripheral:advertisementData:RSSI:
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        dataSource?.centralManagerDidDiscoverPeripheral(central: central, peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI)
    }
    /// 1.2系统蓝牙连接回调
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        dataSource?.centralManagerConnectionEventDidOccur(central: central, event: event, peripheral: peripheral)
    }
    
    /// 1.3连接外设成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Logger.d(self, "centralManager didConnect")
        /// 1.注册设备的设备id
        centralManager?.registerForConnectionEvents(options: [CBConnectionEventMatchingOption.peripheralUUIDs: [peripheral.identifier]])
        guard let currentConnectConfig = currentConnectConfig else {
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        peripheral.delegate = self
        peripheral.discoverServices([currentConnectConfig.serviceUUID])
    }
    
    /// 1.4连接外设失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        Logger.d(self, "centralManager didFailToConnect：\(peripheral)，error：\(String(describing: error))")
        connectTimeout = false
        currentConnectConfig = nil
        connectStatusChange(status: .failure)
    }
    
    /// 1.5取消外设连接
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        Logger.d(self, "centralManager didDisconnectPeripheral：\(peripheral)，error：\(String(describing: error))")
        disconnectCommonAction(peripheral: peripheral)
        connectStatusChange(status: .disConnect)
    }
    /// 1.6自动重连 TODO
    /// 感觉没用
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        Logger.d(self, "willRestoreState：\(central)")
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        for p in peripherals ?? [] {
            central.connect(p, options: nil)
        }
    }
}

/// 外设代理回调
extension BluetoothConnector: CBPeripheralDelegate {
    ///2.1外设的服务被发现
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        connectTimeout = false
        if error != nil {
            Logger.d(self, "peripheral didDiscoverServices：\(peripheral)，error：\(String(describing: error))")
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        guard let currentConnectConfig = currentConnectConfig else {
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        var findService: CBService? = nil
        for service in peripheral.services ?? [] {
            if service.uuid.isEqual(currentConnectConfig.serviceUUID) {
                findService = service
            }
        }
        guard let findService = findService else {
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        var tmpCharacteristicsUUID: [CBUUID] = []
        if currentConnectConfig.characteristicsUUID.uuidString != "" {
            tmpCharacteristicsUUID.append(currentConnectConfig.characteristicsUUID)
        }
        if currentConnectConfig.characteristicsUUIDRx.uuidString != "" {
            tmpCharacteristicsUUID.append(currentConnectConfig.characteristicsUUIDRx)
        }
        peripheral.discoverCharacteristics(tmpCharacteristicsUUID, for: findService)
    }
    
    ///2.2外设的特征被发现
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if error != nil {
            Logger.d(self, "peripheral didDiscoverCharacteristicsFor：\(peripheral)，service:\(service), error：\(String(describing: error))")
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        guard let currentConnectConfig = currentConnectConfig else {
            /// 返回状态
            connectStatusChange(status: .failure)
            return
        }
        for characteristic in service.characteristics ?? [] {
            Logger.d(self, "发现特征：\(characteristic.uuid), 属性：\(testPropsType(props: characteristic.properties))")
            if characteristic.uuid.isEqual(currentConnectConfig.characteristicsUUID) {
                addCharacteristic(for: peripheral, config: currentConnectConfig, characteristic: characteristic)
            }
            if characteristic.uuid.isEqual(currentConnectConfig.characteristicsUUIDRx) {
                addCharacteristic(for: peripheral, config: currentConnectConfig, characteristic: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        connectStatusChange(status: .connected)
    }
    
    /// 2.3特征值监听成功
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let currentConnectConfig = currentConnectConfig {
            updateStoreConfig(peripheral: peripheral, config: currentConnectConfig, isConnect: true)
        }
        self.currentConnectConfig = nil
        if error != nil {
            Logger.d(self, "peripheral didUpdateNotificationStateFor：\(peripheral)，characteristic:\(characteristic), error：\(String(describing: error))")
            statusDelegate?.connectorCharacteristicNotifyReturn(peripheral: peripheral, characteristic: characteristic, status: .failure)
        } else {
            if characteristic.isNotifying == true {
                statusDelegate?.connectorCharacteristicNotifyReturn(peripheral: peripheral, characteristic: characteristic, status: .success)
            } else {
                statusDelegate?.connectorCharacteristicNotifyReturn(peripheral: peripheral, characteristic: characteristic, status: .failure)
                centralManager?.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    /// 2.4特征值的更新
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if error != nil {
            Logger.e(self, "peripheral didUpdateValueFor：\(peripheral)，characteristic:\(characteristic), error：\(String(describing: error))")
        } else {
            Logger.e(self, "receiveData---\(characteristic.value?.hex ?? "空")")
            dataSource?.peripheralCharacteristicDidUpdateValue(peripheral: peripheral, characteristic: characteristic)
        }
    }
    
    /// 2.5特征值写入回调
    /// 只有写入时，参数为CBCharacteristicWriteWithResponse，会每次都回调，如果是CBCharacteristicWriteWithoutResponse就不会回调
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if error != nil {
            Logger.e(self, "peripheral didWriteValueFor：\(peripheral)，characteristic:\(characteristic), error：\(String(describing: error))")
        } else {
            Logger.d(self, "写入数据成功")
        }
    }
    
    ///2.6准备好发送下一个数据
    ///当写入数据的方法失败后，当外设已经准备好可以写入的时候，会回调
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        Logger.d(self, "准备好发送下一个数据")
    }
}

extension BluetoothConnector {
    /// 扫描状态改变
    private func scanStatusChange(status: BluetoothScanStatus) {
        scanStatus = status
        statusDelegate?.connectorScanStatusReturn(status: scanStatus)
    }
    /// 连接状态改变
    private func connectStatusChange(status: BluetoothConnectStatus) {
        connectStatus = status
        statusDelegate?.connectorConnectorStatusReturn(status: connectStatus)
    }
    /// 获取当前未连接的config-未用到
    func getCurrentUnConnectConfig(peripheral: CBPeripheral) -> BluetoothConfig? {
        return mBlePeripheralStore.getUnConnectConfig(peripheral: peripheral)
    }
    /// 更新当前未连接的config存储的特征
    func addCharacteristic(for peripheral: CBPeripheral, config: BluetoothConfig, characteristic: CBCharacteristic) {
        mBlePeripheralStore.addCharacteristic(for: peripheral, config: config, characteristic: characteristic)
    }
    /// 更新当前未连接的config存储的连接状态
    func updateStoreConfig(peripheral: CBPeripheral, config: BluetoothConfig, isConnect: Bool) {
        mBlePeripheralStore.updateUnConnectConfig(peripheral: peripheral, config: config, isConnect: isConnect)
    }
    /// 获取可写的特征值
    func getWriteCharacteristic(peripheral: CBPeripheral, config: BluetoothConfig) -> (Bool, CBCharacteristic?) {
        return mBlePeripheralStore.findPeripheralWriteCharacteristic(peripheral: peripheral, config: config)
    }
    /// 获取可读的特征值
    func getNotifyCharacteristics(peripheral: CBPeripheral) -> [CBCharacteristic]? {
        return mBlePeripheralStore.findPeripheralNotifyCharacteristics(peripheral: peripheral)
    }
    /// 被动的断开，统一的数据处理
    /// 如系统蓝牙关闭，系统列表内蓝牙断开、外设关闭等
    func updateStoreConfigForDisconnect(peripheral: CBPeripheral, isConnect: Bool, needClearCharacteristics: Bool) {
        mBlePeripheralStore.updateConfigStats(for: peripheral, isConnect: isConnect, needClearCharacteristics: needClearCharacteristics)
    }
    /// 断开连接的统一处理
    func disconnectCommonAction(peripheral: CBPeripheral) {
        let characteristics = getNotifyCharacteristics(peripheral: peripheral)
        if let characteristics = characteristics, characteristics.count > 0 {
            for c in characteristics {
                peripheral.setNotifyValue(false, for: c)
            }
        }
        updateStoreConfigForDisconnect(peripheral: peripheral, isConnect: false, needClearCharacteristics: true)
        self.currentConnectConfig = nil
    }
    /// 系统蓝牙关闭，统一断开所有外设
    func disconnectAllPeripheral() {
        for pm in mBlePeripheralStore.connectPeripherals {
            if let peripheral = pm.peripheral, let characteristics = pm.characteristics, characteristics.count > 0 {
                let notifyCharacteristics = characteristics.filter({$0.properties.contains(.notify) || $0.properties.contains(.notifyEncryptionRequired)})
                for nc in notifyCharacteristics {
                    peripheral.setNotifyValue(false, for: nc)
                }
            }
        }
        mBlePeripheralStore.updateAllConfigStats(isConnect: false, needClearCharacteristics: true)
        self.currentConnectConfig = nil
    }
}
