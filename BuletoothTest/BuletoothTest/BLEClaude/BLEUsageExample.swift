//
//  BLEUsageExample.swift
//  BLE 使用示例
//
//  演示如何使用 BLEManager 进行设备扫描、连接、数据收发
//

import UIKit
import CoreBluetooth

// MARK: - 使用示例 ViewController
class BLEExampleViewController: UIViewController {

    // ==========================================
    // 配置你的设备UUID（根据实际设备修改）
    // ==========================================

    /// 目标服务UUID
    let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")

    /// 写入特征UUID（用于发送数据）
    let writeCharacteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

    /// 通知特征UUID（用于接收数据）
    let notifyCharacteristicUUID = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")

    // ==========================================
    // UI 组件
    // ==========================================

    private let statusLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let deviceTableView = UITableView()

    /// 已发现设备列表（用于TableView显示）
    private var deviceList: [DiscoveredDevice] = []

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBLEManager()
    }

    // MARK: - 初始化设置

    private func setupBLEManager() {
        // 1. 设置代理
        BLEManager.shared.delegate = self

        // 2. 配置目标服务和特征（可选，用于过滤）
        BLEManager.shared.targetServiceUUIDs = [serviceUUID]
        BLEManager.shared.targetCharacteristicUUIDs = [writeCharacteristicUUID, notifyCharacteristicUUID]
    }

    private func setupUI() {
        view.backgroundColor = .white
        title = "BLE 示例"

        // 状态标签
        statusLabel.text = "等待蓝牙..."
        statusLabel.textAlignment = .center
        statusLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 30)
        view.addSubview(statusLabel)

        // 扫描按钮
        scanButton.setTitle("开始扫描", for: .normal)
        scanButton.frame = CGRect(x: 20, y: 140, width: 100, height: 40)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        view.addSubview(scanButton)

        // 断开按钮
        disconnectButton.setTitle("断开全部", for: .normal)
        disconnectButton.frame = CGRect(x: 130, y: 140, width: 100, height: 40)
        disconnectButton.addTarget(self, action: #selector(disconnectButtonTapped), for: .touchUpInside)
        view.addSubview(disconnectButton)

        // 发送按钮
        sendButton.setTitle("发送测试", for: .normal)
        sendButton.frame = CGRect(x: 240, y: 140, width: 100, height: 40)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        view.addSubview(sendButton)

        // 设备列表
        deviceTableView.frame = CGRect(x: 0, y: 200, width: view.bounds.width, height: view.bounds.height - 200)
        deviceTableView.delegate = self
        deviceTableView.dataSource = self
        deviceTableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        view.addSubview(deviceTableView)
    }

    // MARK: - 按钮事件

    /// 扫描按钮点击
    @objc private func scanButtonTapped() {
        if BLEManager.shared.bluetoothState == .poweredOn {
            // 清空列表
            deviceList.removeAll()
            deviceTableView.reloadData()

            // 开始扫描（传入服务UUID可过滤设备）
            BLEManager.shared.startScanning(serviceUUIDs: nil)

            scanButton.setTitle("停止扫描", for: .normal)
            statusLabel.text = "正在扫描..."

            // 10秒后自动停止扫描
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.stopScanning()
            }
        } else {
            statusLabel.text = "蓝牙未开启"
        }
    }

    /// 停止扫描
    private func stopScanning() {
        BLEManager.shared.stopScanning()
        scanButton.setTitle("开始扫描", for: .normal)
        statusLabel.text = "扫描完成，发现 \(deviceList.count) 个设备"
    }

    /// 断开按钮点击
    @objc private func disconnectButtonTapped() {
        BLEManager.shared.disconnectAll()
        statusLabel.text = "已断开所有设备"
    }

    /// 发送按钮点击
    @objc private func sendButtonTapped() {
        // 向所有已连接设备发送测试数据
        let connectedDevices = BLEManager.shared.connectedPeripherals

        guard !connectedDevices.isEmpty else {
            statusLabel.text = "没有已连接的设备"
            return
        }

        // 测试数据
        let testData = Data([0x01, 0x02, 0x03, 0x04])

        for (deviceID, peripheral) in connectedDevices {
            let success = BLEManager.shared.writeData(
                testData,
                to: writeCharacteristicUUID,
                peripheralID: deviceID
            )

            if success {
                statusLabel.text = "已发送到: \(peripheral.name ?? "Unknown")"
            }
        }
    }
}

// MARK: - BLEManagerDelegate
extension BLEExampleViewController: BLEManagerDelegate {

    /// 蓝牙状态更新
    func bleManagerDidUpdateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            statusLabel.text = "蓝牙已开启，可以扫描"
        case .poweredOff:
            statusLabel.text = "蓝牙已关闭"
        case .unauthorized:
            statusLabel.text = "蓝牙未授权"
        default:
            statusLabel.text = "蓝牙状态: \(state.rawValue)"
        }
    }

    /// 发现设备
    func bleManagerDidDiscoverDevice(_ device: DiscoveredDevice) {
        // 检查是否已存在（根据UUID判断）
        if let index = deviceList.firstIndex(where: { $0.identifier == device.identifier }) {
            // 更新已有设备
            deviceList[index] = device
        } else {
            // 添加新设备
            deviceList.append(device)
        }

        // 按信号强度排序
        deviceList.sort { $0.rssi.intValue > $1.rssi.intValue }

        // 刷新列表
        deviceTableView.reloadData()
    }

    /// 连接成功
    func bleManagerDidConnect(_ peripheral: CBPeripheral) {
        statusLabel.text = "已连接: \(peripheral.name ?? "Unknown")"
        stopScanning()
        deviceTableView.reloadData()
    }

    /// 断开连接
    func bleManagerDidDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            statusLabel.text = "断开连接: \(error.localizedDescription)"
        } else {
            statusLabel.text = "已断开: \(peripheral.name ?? "Unknown")"
        }
        deviceTableView.reloadData()
    }

    /// 收到数据
    func bleManagerDidReceiveData(_ data: Data, from peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // 根据设备UUID区分数据来源
        let deviceID = peripheral.identifier
        let deviceName = peripheral.name ?? "Unknown"

        print("收到数据 - 设备: \(deviceName) (\(deviceID))")
        print("特征: \(characteristic.uuid)")
        print("数据: \(data.hexString)")

        // 在主线程更新UI
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "收到[\(deviceName)]: \(data.hexString)"
        }

        // 根据不同设备处理数据
        handleReceivedData(data, fromDevice: deviceID)
    }

    /// 处理接收到的数据（根据设备区分）
    private func handleReceivedData(_ data: Data, fromDevice deviceID: UUID) {
        // 示例：根据设备UUID进行不同处理
        // 你可以在这里添加自己的业务逻辑

        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return }

        // 解析数据示例
        let commandType = bytes[0]
        switch commandType {
        case 0x01:
            print("设备[\(deviceID)] - 收到心跳响应")
        case 0x02:
            print("设备[\(deviceID)] - 收到状态数据")
        case 0x03:
            print("设备[\(deviceID)] - 收到传感器数据")
        default:
            print("设备[\(deviceID)] - 收到未知命令: \(commandType)")
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension BLEExampleViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let device = deviceList[indexPath.row]

        // 检查是否已连接
        let isConnected = BLEManager.shared.connectedPeripherals[device.identifier] != nil
        let statusIcon = isConnected ? "🟢" : "⚪️"

        cell.textLabel?.text = "\(statusIcon) \(device.name) | RSSI: \(device.rssi)"
        cell.detailTextLabel?.text = device.identifier.uuidString

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let device = deviceList[indexPath.row]
        let deviceID = device.identifier

        // 检查是否已连接
        if BLEManager.shared.connectedPeripherals[deviceID] != nil {
            // 已连接，断开
            BLEManager.shared.disconnect(peripheralID: deviceID)
        } else {
            // 未连接，发起连接（启用自动回连）
            BLEManager.shared.connect(to: device.peripheral, autoReconnect: true)
            statusLabel.text = "正在连接: \(device.name)"
        }
    }
}

// MARK: - 多设备管理示例
class MultiDeviceManager {

    /// 设备类型枚举
    enum DeviceType {
        case sensor      // 传感器
        case controller  // 控制器
        case display     // 显示器
    }

    /// 设备信息
    struct ManagedDevice {
        let id: UUID
        let type: DeviceType
        var name: String
        var isConnected: Bool = false
    }

    /// 管理的设备列表
    private var managedDevices: [UUID: ManagedDevice] = [:]

    /// 添加设备
    func addDevice(id: UUID, type: DeviceType, name: String) {
        managedDevices[id] = ManagedDevice(id: id, type: type, name: name)
    }

    /// 向特定类型的设备发送数据
    func sendToDevices(ofType type: DeviceType, data: Data, characteristicUUID: CBUUID) {
        let targetDevices = managedDevices.filter { $0.value.type == type }

        for (deviceID, device) in targetDevices {
            let success = BLEManager.shared.writeData(
                data,
                to: characteristicUUID,
                peripheralID: deviceID
            )
            print("发送到[\(device.name)]: \(success ? "成功" : "失败")")
        }
    }

    /// 向所有设备广播数据
    func broadcast(data: Data, characteristicUUID: CBUUID) {
        for (deviceID, device) in managedDevices {
            BLEManager.shared.writeData(
                data,
                to: characteristicUUID,
                peripheralID: deviceID
            )
            print("广播到[\(device.name)]")
        }
    }

    /// 根据设备ID获取设备类型
    func getDeviceType(for deviceID: UUID) -> DeviceType? {
        return managedDevices[deviceID]?.type
    }
}

// MARK: - 使用多设备管理器示例
/*

 let multiManager = MultiDeviceManager()

 // 添加设备
 multiManager.addDevice(id: sensorUUID, type: .sensor, name: "温度传感器")
 multiManager.addDevice(id: controllerUUID, type: .controller, name: "主控制器")

 // 只向传感器发送数据
 let sensorCommand = Data([0x01, 0x02])
 multiManager.sendToDevices(ofType: .sensor, data: sensorCommand, characteristicUUID: writeUUID)

 // 向所有设备广播
 let broadcastData = Data([0xFF, 0x00])
 multiManager.broadcast(data: broadcastData, characteristicUUID: writeUUID)

 */
