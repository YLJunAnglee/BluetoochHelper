//
//  BLEManager.swift
//  iOS BLE 蓝牙管理器
//
//  功能：设备扫描、连接、数据收发、自动回连、多设备管理
//

import CoreBluetooth
import Foundation

// MARK: - 设备信息模型
/// 封装已发现的BLE设备信息
struct DiscoveredDevice {
    let peripheral: CBPeripheral          // 外围设备对象
    let advertisementData: [String: Any]  // 广播数据
    var rssi: NSNumber                    // 信号强度
    var lastSeen: Date                    // 最后发现时间

    /// 设备唯一标识符（用于多设备区分）
    var identifier: UUID {
        return peripheral.identifier
    }

    /// 设备名称
    var name: String {
        return peripheral.name ?? "Unknown Device"
    }
}

// MARK: - BLE管理器代理协议
protocol BLEManagerDelegate: AnyObject {
    func bleManagerDidUpdateState(_ state: CBManagerState)
    func bleManagerDidDiscoverDevice(_ device: DiscoveredDevice)
    func bleManagerDidConnect(_ peripheral: CBPeripheral)
    func bleManagerDidDisconnect(_ peripheral: CBPeripheral, error: Error?)
    func bleManagerDidReceiveData(_ data: Data, from peripheral: CBPeripheral, characteristic: CBCharacteristic)
}

// MARK: - BLE管理器核心类
class BLEManager: NSObject {

    // MARK: - 单例
    static let shared = BLEManager()

    // MARK: - 属性

    /// 中心管理器 - BLE操作的核心对象
    private var centralManager: CBCentralManager!

    /// 代理
    weak var delegate: BLEManagerDelegate?

    /// 已发现的设备字典 [UUID: DiscoveredDevice]
    /// 使用UUID作为key，方便多设备管理和区分
    private(set) var discoveredDevices: [UUID: DiscoveredDevice] = [:]

    /// 已连接的设备字典 [UUID: CBPeripheral]
    /// 支持同时连接多个设备
    private(set) var connectedPeripherals: [UUID: CBPeripheral] = [:]

    /// 设备的特征缓存 [PeripheralUUID: [CharacteristicUUID: CBCharacteristic]]
    /// 用于快速查找特定设备的特定特征
    private var characteristicsCache: [UUID: [CBUUID: CBCharacteristic]] = [:]

    /// 需要自动回连的设备UUID列表（持久化存储）
    private var autoReconnectDeviceIDs: [UUID] {
        get {
            let strings = UserDefaults.standard.stringArray(forKey: "BLE_AutoReconnect_Devices") ?? []
            return strings.compactMap { UUID(uuidString: $0) }
        }
        set {
            let strings = newValue.map { $0.uuidString }
            UserDefaults.standard.set(strings, forKey: "BLE_AutoReconnect_Devices")
        }
    }

    /// 目标服务UUID（根据你的设备配置）
    var targetServiceUUIDs: [CBUUID] = []

    /// 目标特征UUID
    var targetCharacteristicUUIDs: [CBUUID] = []

    /// 蓝牙状态
    var bluetoothState: CBManagerState {
        return centralManager.state
    }

    // MARK: - 初始化

    private override init() {
        super.init()

        // 创建中心管理器
        // queue: nil 表示使用主队列
        // options: 配置选项
        let options: [String: Any] = [
            // 状态恢复标识符 - 用于后台恢复
            CBCentralManagerOptionRestoreIdentifierKey: "com.yourapp.blemanager",
            // 是否在蓝牙关闭时显示系统提示
            CBCentralManagerOptionShowPowerAlertKey: true
        ]

        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
}

// MARK: - 设备发现
extension BLEManager {

    // ==========================================
    // 方式一：主动扫描（Scanning）
    // ==========================================

    /// 开始扫描BLE设备
    /// - Parameters:
    ///   - serviceUUIDs: 要扫描的服务UUID，nil表示扫描所有设备
    ///   - allowDuplicates: 是否允许重复上报同一设备（用于实时RSSI更新）
    func startScanning(serviceUUIDs: [CBUUID]? = nil, allowDuplicates: Bool = false) {
        // 检查蓝牙状态
        guard centralManager.state == .poweredOn else {
            print("⚠️ 蓝牙未开启，无法扫描")
            return
        }

        // 清空之前发现的设备
        discoveredDevices.removeAll()

        // 扫描选项
        let options: [String: Any] = [
            // 是否允许重复发现同一设备（用于实时更新RSSI）
            CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates
        ]

        // 开始扫描
        // serviceUUIDs: 指定服务UUID可以过滤设备，提高效率
        // nil: 扫描所有BLE设备
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)

        print("🔍 开始扫描BLE设备...")
    }

    /// 停止扫描
    func stopScanning() {
        centralManager.stopScan()
        print("⏹️ 停止扫描")
    }

    // ==========================================
    // 方式二：检索已知设备（Retrieve）
    // ==========================================

    /// 检索已连接的外围设备（通过服务UUID）
    /// 这些设备可能是被其他App或系统连接的
    /// - Parameter serviceUUIDs: 服务UUID列表
    /// - Returns: 已连接的外围设备列表
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] {
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs)

        // 将检索到的设备添加到已发现列表
        for peripheral in peripherals {
            let device = DiscoveredDevice(
                peripheral: peripheral,
                advertisementData: [:],
                rssi: 0,
                lastSeen: Date()
            )
            discoveredDevices[peripheral.identifier] = device
        }

        print("📱 检索到 \(peripherals.count) 个已连接设备")
        return peripherals
    }

    /// 检索已知的外围设备（通过UUID）
    /// 用于恢复之前连接过的设备
    /// - Parameter identifiers: 设备UUID列表
    /// - Returns: 外围设备列表
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)

        for peripheral in peripherals {
            let device = DiscoveredDevice(
                peripheral: peripheral,
                advertisementData: [:],
                rssi: 0,
                lastSeen: Date()
            )
            discoveredDevices[peripheral.identifier] = device
        }

        print("📱 检索到 \(peripherals.count) 个已知设备")
        return peripherals
    }

    /// 尝试恢复之前保存的设备连接
    /// 在App启动时调用
    func attemptAutoReconnect() {
        guard centralManager.state == .poweredOn else { return }

        let savedIDs = autoReconnectDeviceIDs
        guard !savedIDs.isEmpty else {
            print("📝 没有需要自动回连的设备")
            return
        }

        print("🔄 尝试自动回连 \(savedIDs.count) 个设备...")

        // 检索已知设备
        let peripherals = retrievePeripherals(withIdentifiers: savedIDs)

        // 尝试连接每个设备
        for peripheral in peripherals {
            connect(to: peripheral, autoReconnect: true)
        }
    }
}

// MARK: - 设备连接
extension BLEManager {

    /// 连接到指定设备
    /// - Parameters:
    ///   - peripheral: 要连接的外围设备
    ///   - autoReconnect: 是否启用自动回连
    func connect(to peripheral: CBPeripheral, autoReconnect: Bool = false) {
        // 设置代理（重要！必须在连接前设置）
        peripheral.delegate = self

        // 连接选项
        let options: [String: Any] = [
            // 连接时是否发送系统通知
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            // 断开时是否发送系统通知
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            // 收到通知时是否发送系统通知
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]

        // 发起连接
        centralManager.connect(peripheral, options: options)

        // 如果需要自动回连，保存设备ID
        if autoReconnect {
            addToAutoReconnect(peripheral.identifier)
        }

        print("🔗 正在连接设备: \(peripheral.name ?? peripheral.identifier.uuidString)")
    }

    /// 通过UUID连接设备
    /// - Parameter identifier: 设备UUID
    func connect(toDeviceWithID identifier: UUID, autoReconnect: Bool = false) {
        // 先从已发现设备中查找
        if let device = discoveredDevices[identifier] {
            connect(to: device.peripheral, autoReconnect: autoReconnect)
            return
        }

        // 尝试检索设备
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
        if let peripheral = peripherals.first {
            connect(to: peripheral, autoReconnect: autoReconnect)
        } else {
            print("❌ 未找到设备: \(identifier)")
        }
    }

    /// 发现服务
    /// - Parameters:
    ///   - peripheral: 外围设备
    ///   - serviceUUIDs: 要发现的服务UUID，nil表示发现所有服务
    private func discoverServices(for peripheral: CBPeripheral, serviceUUIDs: [CBUUID]? = nil) {
        // 发现服务
        // 传入特定UUID可以加快发现速度
        peripheral.discoverServices(serviceUUIDs ?? (targetServiceUUIDs.isEmpty ? nil : targetServiceUUIDs))
        print("🔍 正在发现服务...")
    }

    /// 发现特征
    /// - Parameters:
    ///   - service: 服务
    ///   - peripheral: 外围设备
    private func discoverCharacteristics(for service: CBService, peripheral: CBPeripheral) {
        // 发现特征
        // 传入特定UUID可以加快发现速度
        let characteristicUUIDs = targetCharacteristicUUIDs.isEmpty ? nil : targetCharacteristicUUIDs
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        print("🔍 正在发现特征 (服务: \(service.uuid))...")
    }

    /// 添加设备到自动回连列表
    private func addToAutoReconnect(_ identifier: UUID) {
        var ids = autoReconnectDeviceIDs
        if !ids.contains(identifier) {
            ids.append(identifier)
            autoReconnectDeviceIDs = ids
        }
    }

    /// 从自动回连列表移除设备
    func removeFromAutoReconnect(_ identifier: UUID) {
        var ids = autoReconnectDeviceIDs
        ids.removeAll { $0 == identifier }
        autoReconnectDeviceIDs = ids
    }
}

// MARK: - 数据通信
extension BLEManager {

    // ==========================================
    // 发送数据（写入）
    // ==========================================

    /// 向指定设备的特征写入数据
    /// - Parameters:
    ///   - data: 要写入的数据
    ///   - characteristicUUID: 特征UUID
    ///   - peripheralID: 设备UUID（用于多设备区分）
    ///   - writeType: 写入类型
    /// - Returns: 是否成功发起写入
    @discardableResult
    func writeData(_ data: Data,
                   to characteristicUUID: CBUUID,
                   peripheralID: UUID,
                   writeType: CBCharacteristicWriteType = .withResponse) -> Bool {

        // 1. 通过UUID找到对应的设备
        guard let peripheral = connectedPeripherals[peripheralID] else {
            print("❌ 设备未连接: \(peripheralID)")
            return false
        }

        // 2. 从缓存中找到对应的特征
        guard let characteristic = characteristicsCache[peripheralID]?[characteristicUUID] else {
            print("❌ 未找到特征: \(characteristicUUID)")
            return false
        }

        // 3. 检查特征是否支持写入
        let canWrite = characteristic.properties.contains(.write) ||
                       characteristic.properties.contains(.writeWithoutResponse)
        guard canWrite else {
            print("❌ 特征不支持写入")
            return false
        }

        // 4. 写入数据
        // .withResponse: 需要设备确认（可靠但慢）
        // .withoutResponse: 不需要确认（快但可能丢失）
        peripheral.writeValue(data, for: characteristic, type: writeType)

        print("📤 发送数据到设备[\(peripheral.name ?? "Unknown")]: \(data.hexString)")
        return true
    }

    /// 便捷方法：发送字符串
    @discardableResult
    func writeString(_ string: String,
                     to characteristicUUID: CBUUID,
                     peripheralID: UUID) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return writeData(data, to: characteristicUUID, peripheralID: peripheralID)
    }

    // ==========================================
    // 接收数据（读取和通知）
    // ==========================================

    /// 主动读取特征值
    /// - Parameters:
    ///   - characteristicUUID: 特征UUID
    ///   - peripheralID: 设备UUID
    func readValue(from characteristicUUID: CBUUID, peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID],
              let characteristic = characteristicsCache[peripheralID]?[characteristicUUID] else {
            print("❌ 设备或特征未找到")
            return
        }

        // 检查是否支持读取
        guard characteristic.properties.contains(.read) else {
            print("❌ 特征不支持读取")
            return
        }

        // 发起读取请求
        peripheral.readValue(for: characteristic)
        print("📥 请求读取特征值...")
    }

    /// 订阅特征通知（推荐方式）
    /// 设备主动推送数据时会收到回调
    /// - Parameters:
    ///   - characteristicUUID: 特征UUID
    ///   - peripheralID: 设备UUID
    ///   - enabled: 是否启用通知
    func setNotify(_ enabled: Bool,
                   for characteristicUUID: CBUUID,
                   peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID],
              let characteristic = characteristicsCache[peripheralID]?[characteristicUUID] else {
            print("❌ 设备或特征未找到")
            return
        }

        // 检查是否支持通知
        let canNotify = characteristic.properties.contains(.notify) ||
                        characteristic.properties.contains(.indicate)
        guard canNotify else {
            print("❌ 特征不支持通知")
            return
        }

        // 设置通知状态
        peripheral.setNotifyValue(enabled, for: characteristic)
        print(enabled ? "🔔 订阅通知" : "🔕 取消订阅")
    }

    /// 为设备的所有可通知特征启用通知
    func enableAllNotifications(for peripheralID: UUID) {
        guard let characteristics = characteristicsCache[peripheralID] else { return }

        for (uuid, _) in characteristics {
            setNotify(true, for: uuid, peripheralID: peripheralID)
        }
    }
}

// MARK: - 断开连接
extension BLEManager {

    /// 断开指定设备连接
    /// - Parameters:
    ///   - peripheralID: 设备UUID
    ///   - removeAutoReconnect: 是否同时移除自动回连
    func disconnect(peripheralID: UUID, removeAutoReconnect: Bool = false) {
        guard let peripheral = connectedPeripherals[peripheralID] else {
            print("⚠️ 设备未连接")
            return
        }

        // 取消连接
        centralManager.cancelPeripheralConnection(peripheral)

        // 是否移除自动回连
        if removeAutoReconnect {
            removeFromAutoReconnect(peripheralID)
        }

        print("🔌 断开设备连接: \(peripheral.name ?? "Unknown")")
    }

    /// 断开所有设备连接
    func disconnectAll(removeAutoReconnect: Bool = false) {
        for (id, _) in connectedPeripherals {
            disconnect(peripheralID: id, removeAutoReconnect: removeAutoReconnect)
        }
    }

    /// 处理意外断开后的自动回连
    private func handleUnexpectedDisconnection(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier

        // 检查是否在自动回连列表中
        guard autoReconnectDeviceIDs.contains(id) else { return }

        print("🔄 设备意外断开，尝试自动回连...")

        // 延迟重连，避免立即重连失败
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.connect(to: peripheral, autoReconnect: true)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {

    /// 蓝牙状态更新回调
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ 蓝牙已开启")
            // 蓝牙开启后尝试自动回连
            attemptAutoReconnect()
        case .poweredOff:
            print("❌ 蓝牙已关闭")
        case .resetting:
            print("⚠️ 蓝牙正在重置")
        case .unauthorized:
            print("❌ 蓝牙未授权")
        case .unsupported:
            print("❌ 设备不支持蓝牙")
        case .unknown:
            print("❓ 蓝牙状态未知")
        @unknown default:
            print("❓ 未知状态")
        }

        delegate?.bleManagerDidUpdateState(central.state)
    }

    /// 发现设备回调
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {

        // 创建或更新设备信息
        let device = DiscoveredDevice(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI,
            lastSeen: Date()
        )

        // 使用UUID作为key存储，确保多设备不会混淆
        discoveredDevices[peripheral.identifier] = device

        print("📡 发现设备: \(device.name) | RSSI: \(RSSI) | ID: \(peripheral.identifier)")

        delegate?.bleManagerDidDiscoverDevice(device)
    }

    /// 连接成功回调
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ 连接成功: \(peripheral.name ?? "Unknown")")

        // 添加到已连接设备字典
        connectedPeripherals[peripheral.identifier] = peripheral

        // 初始化特征缓存
        characteristicsCache[peripheral.identifier] = [:]

        // 设置代理
        peripheral.delegate = self

        // 开始发现服务
        discoverServices(for: peripheral)

        delegate?.bleManagerDidConnect(peripheral)
    }

    /// 连接失败回调
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("❌ 连接失败: \(peripheral.name ?? "Unknown"), 错误: \(error?.localizedDescription ?? "未知")")

        // 如果在自动回连列表中，尝试重连
        if autoReconnectDeviceIDs.contains(peripheral.identifier) {
            handleUnexpectedDisconnection(peripheral)
        }
    }

    /// 断开连接回调
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        let id = peripheral.identifier

        print("🔌 设备断开: \(peripheral.name ?? "Unknown"), 错误: \(error?.localizedDescription ?? "无")")

        // 从已连接列表移除
        connectedPeripherals.removeValue(forKey: id)
        characteristicsCache.removeValue(forKey: id)

        delegate?.bleManagerDidDisconnect(peripheral, error: error)

        // 如果是意外断开且在自动回连列表中，尝试重连
        if error != nil && autoReconnectDeviceIDs.contains(id) {
            handleUnexpectedDisconnection(peripheral)
        }
    }

    /// 状态恢复回调（后台恢复）
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        // 恢复之前连接的设备
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                connectedPeripherals[peripheral.identifier] = peripheral
                print("🔄 恢复设备连接: \(peripheral.name ?? "Unknown")")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {

    /// 发现服务回调
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ 发现服务失败: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }

        print("📋 发现 \(services.count) 个服务:")

        for service in services {
            print("  - 服务: \(service.uuid)")
            // 发现每个服务的特征
            discoverCharacteristics(for: service, peripheral: peripheral)
        }
    }

    /// 发现特征回调
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("❌ 发现特征失败: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        let peripheralID = peripheral.identifier

        print("📋 服务[\(service.uuid)]的特征:")

        for characteristic in characteristics {
            // 缓存特征，方便后续使用
            characteristicsCache[peripheralID]?[characteristic.uuid] = characteristic

            // 打印特征属性
            var properties: [String] = []
            if characteristic.properties.contains(.read) { properties.append("读") }
            if characteristic.properties.contains(.write) { properties.append("写") }
            if characteristic.properties.contains(.writeWithoutResponse) { properties.append("无响应写") }
            if characteristic.properties.contains(.notify) { properties.append("通知") }
            if characteristic.properties.contains(.indicate) { properties.append("指示") }

            print("  - 特征: \(characteristic.uuid) | 属性: \(properties.joined(separator: ", "))")

            // 自动订阅支持通知的特征
            if characteristic.properties.contains(.notify) ||
               characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    /// 特征值更新回调（读取或通知）
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ 读取特征值失败: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else { return }

        print("📥 收到数据 [设备: \(peripheral.name ?? "Unknown")] [特征: \(characteristic.uuid)]: \(data.hexString)")

        // 通知代理
        delegate?.bleManagerDidReceiveData(data, from: peripheral, characteristic: characteristic)
    }

    /// 写入完成回调
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ 写入失败: \(error.localizedDescription)")
        } else {
            print("✅ 写入成功 [特征: \(characteristic.uuid)]")
        }
    }

    /// 通知状态更新回调
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ 通知状态更新失败: \(error.localizedDescription)")
        } else {
            let status = characteristic.isNotifying ? "已订阅" : "已取消"
            print("🔔 通知状态: \(status) [特征: \(characteristic.uuid)]")
        }
    }
}

// MARK: - Data扩展（十六进制转换）
extension Data {
    var hexString: String {
        return map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    init?(hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex,
                  let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
