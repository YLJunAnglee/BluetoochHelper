//
//  MFiAccessoryManager.swift
//  MFi 配件管理工具类
//
//  Created by xiandao on 2026/1/21.
//
//  功能：
//  1. 设备发现与监听
//  2. 设备连接与会话管理
//  3. 数据收发
//  4. 断开连接
//  5. 自动重连
//
//  使用方法：
//  let manager = MFiAccessoryManager(protocolString: "com.yourcompany.protocol")
//  manager.delegate = self
//  manager.startMonitoring()
//

import UIKit
import ExternalAccessory

// MARK: - 连接状态枚举

/// MFi 配件连接状态
public enum MFiConnectionState {
    case disconnected       // 未连接
    case connecting         // 连接中
    case connected          // 已连接
    case reconnecting       // 重连中
}

// MARK: - 代理协议

/// MFi 配件管理器代理协议
public protocol MFiAccessoryManagerDelegate: AnyObject {
    /// 配件已连接
    func accessoryManager(_ manager: MFiAccessoryManager, didConnect accessory: EAAccessory)

    /// 配件已断开
    func accessoryManager(_ manager: MFiAccessoryManager, didDisconnect accessory: EAAccessory)

    /// 收到数据
    func accessoryManager(_ manager: MFiAccessoryManager, didReceiveData data: Data)

    /// 连接状态改变
    func accessoryManager(_ manager: MFiAccessoryManager, didChangeState state: MFiConnectionState)

    /// 发生错误
    func accessoryManager(_ manager: MFiAccessoryManager, didEncounterError error: MFiAccessoryError)
}

// MARK: - 代理协议默认实现（可选方法）

public extension MFiAccessoryManagerDelegate {
    func accessoryManager(_ manager: MFiAccessoryManager, didChangeState state: MFiConnectionState) {}
    func accessoryManager(_ manager: MFiAccessoryManager, didEncounterError error: MFiAccessoryError) {}
}

// MARK: - 错误类型

/// MFi 配件错误类型
public enum MFiAccessoryError: Error, LocalizedError {
    case protocolNotSupported       // 协议不支持
    case sessionCreationFailed      // 会话创建失败
    case streamOpenFailed           // 流打开失败
    case streamWriteFailed          // 写入失败
    case streamReadFailed           // 读取失败
    case notConnected               // 未连接
    case accessoryNotFound          // 配件未找到
    case maxReconnectAttemptsReached // 达到最大重连次数

    public var errorDescription: String? {
        switch self {
        case .protocolNotSupported:
            return "配件不支持指定的协议"
        case .sessionCreationFailed:
            return "创建会话失败"
        case .streamOpenFailed:
            return "打开数据流失败"
        case .streamWriteFailed:
            return "发送数据失败"
        case .streamReadFailed:
            return "读取数据失败"
        case .notConnected:
            return "配件未连接"
        case .accessoryNotFound:
            return "未找到配件"
        case .maxReconnectAttemptsReached:
            return "已达到最大重连次数"
        }
    }
}

// MARK: - MFi 配件管理器

/// MFi 配件管理器
/// 提供完整的 MFi 配件连接、通信、重连功能
public final class MFiAccessoryManager: NSObject {

    // MARK: - 公开属性

    /// 代理
    public weak var delegate: MFiAccessoryManagerDelegate?

    /// 协议字符串
    public let protocolString: String

    /// 当前连接状态
    public private(set) var connectionState: MFiConnectionState = .disconnected {
        didSet {
            if oldValue != connectionState {
                delegate?.accessoryManager(self, didChangeState: connectionState)
            }
        }
    }

    /// 当前连接的配件
    public private(set) var connectedAccessory: EAAccessory?

    /// 是否启用自动重连
    public var autoReconnectEnabled: Bool = true

    /// 重连间隔（秒）
    public var reconnectInterval: TimeInterval = 3.0

    /// 最大重连次数（0 表示无限制）
    public var maxReconnectAttempts: Int = 10

    /// 数据接收缓冲区大小
    public var receiveBufferSize: Int = 1024

    // MARK: - 私有属性

    /// 会话
    private var session: EASession?

    /// 输入流
    private var inputStream: InputStream?

    /// 输出流
    private var outputStream: OutputStream?

    /// 重连定时器
    private var reconnectTimer: Timer?

    /// 当前重连次数
    private var reconnectAttempts: Int = 0

    /// 目标配件序列号（用于重连）
    private var targetSerialNumber: String?

    /// UserDefaults 键
    private static let lastConnectedSerialKey = "MFi_LastConnectedSerial"

    /// 数据发送队列
    private let sendQueue = DispatchQueue(label: "com.mfi.sendQueue", qos: .userInitiated)

    /// 待发送数据缓冲区
    private var pendingData: [Data] = []

    /// 是否正在发送
    private var isSending: Bool = false

    // MARK: - 初始化

    /// 初始化 MFi 配件管理器
    /// - Parameter protocolString: 配件协议字符串（在 Info.plist 中声明）
    public init(protocolString: String) {
        self.protocolString = protocolString
        super.init()
    }

    deinit {
        stopMonitoring()
        disconnect()
    }

    // MARK: - 公开方法

    /// 开始监听配件连接事件
    public func startMonitoring() {
        // 注册配件连接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessoryDidConnect(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )

        // 注册配件断开通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessoryDidDisconnect(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )

        // 注册 App 进入前台通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // 开始监听本地通知
        EAAccessoryManager.shared().registerForLocalNotifications()

        // 加载上次连接的配件信息
        targetSerialNumber = loadLastConnectedSerial()

        // 检查当前已连接的配件
        checkConnectedAccessories()
    }

    /// 停止监听配件连接事件
    public func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        stopReconnectTimer()
    }

    /// 获取所有已连接的配件
    /// - Returns: 已连接的配件列表
    public func getConnectedAccessories() -> [EAAccessory] {
        return EAAccessoryManager.shared().connectedAccessories
    }

    /// 获取支持当前协议的配件
    /// - Returns: 支持协议的配件列表
    public func getSupportedAccessories() -> [EAAccessory] {
        return getConnectedAccessories().filter { $0.protocolStrings.contains(protocolString) }
    }

    /// 连接到指定配件
    /// - Parameter accessory: 要连接的配件
    /// - Returns: 是否连接成功
    @discardableResult
    public func connect(to accessory: EAAccessory) -> Bool {
        // 检查协议支持
        guard accessory.protocolStrings.contains(protocolString) else {
            delegate?.accessoryManager(self, didEncounterError: .protocolNotSupported)
            return false
        }

        // 如果已连接，先断开
        if session != nil {
            disconnect()
        }

        connectionState = .connecting

        // 创建会话
        guard let newSession = EASession(accessory: accessory, forProtocol: protocolString) else {
            connectionState = .disconnected
            delegate?.accessoryManager(self, didEncounterError: .sessionCreationFailed)
            return false
        }

        session = newSession
        connectedAccessory = accessory

        // 配置流
        if !setupStreams() {
            disconnect()
            delegate?.accessoryManager(self, didEncounterError: .streamOpenFailed)
            return false
        }

        // 保存配件信息
        saveLastConnectedSerial(accessory.serialNumber)
        targetSerialNumber = accessory.serialNumber

        // 重置重连计数
        reconnectAttempts = 0
        stopReconnectTimer()

        connectionState = .connected
        delegate?.accessoryManager(self, didConnect: accessory)

        return true
    }

    /// 连接到第一个支持协议的配件
    /// - Returns: 是否连接成功
    @discardableResult
    public func connectToFirstAvailable() -> Bool {
        guard let accessory = getSupportedAccessories().first else {
            delegate?.accessoryManager(self, didEncounterError: .accessoryNotFound)
            return false
        }
        return connect(to: accessory)
    }

    /// 断开当前连接
    public func disconnect() {
        closeStreams()

        session = nil

        if let accessory = connectedAccessory {
            connectedAccessory = nil
            connectionState = .disconnected
            delegate?.accessoryManager(self, didDisconnect: accessory)
        } else {
            connectionState = .disconnected
        }
    }

    /// 发送数据
    /// - Parameter data: 要发送的数据
    /// - Returns: 是否成功加入发送队列
    @discardableResult
    public func send(_ data: Data) -> Bool {
        guard connectionState == .connected else {
            delegate?.accessoryManager(self, didEncounterError: .notConnected)
            return false
        }

        sendQueue.async { [weak self] in
            self?.pendingData.append(data)
            self?.processSendQueue()
        }

        return true
    }

    /// 发送字符串
    /// - Parameter string: 要发送的字符串
    /// - Returns: 是否成功加入发送队列
    @discardableResult
    public func send(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else {
            return false
        }
        return send(data)
    }

    /// 发送十六进制命令
    /// - Parameter hexString: 十六进制字符串（如 "FF 01 02 03"）
    /// - Returns: 是否成功加入发送队列
    @discardableResult
    public func sendHex(_ hexString: String) -> Bool {
        let data = hexStringToData(hexString)
        guard !data.isEmpty else {
            return false
        }
        return send(data)
    }

    /// 显示蓝牙配件选择器
    /// - Parameter completion: 完成回调
    public func showBluetoothPicker(completion: ((Error?) -> Void)? = nil) {
        EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
            completion?(error)
        }
    }

    /// 手动触发重连
    public func reconnect() {
        guard connectionState != .connected else { return }
        attemptReconnect()
    }

    /// 清除保存的配件信息
    public func clearSavedAccessory() {
        targetSerialNumber = nil
        UserDefaults.standard.removeObject(forKey: Self.lastConnectedSerialKey)
    }

    // MARK: - 私有方法 - 流管理

    /// 配置输入输出流
    private func setupStreams() -> Bool {
        guard let session = session else { return false }

        inputStream = session.inputStream
        outputStream = session.outputStream

        guard inputStream != nil, outputStream != nil else {
            return false
        }

        // 设置代理
        inputStream?.delegate = self
        outputStream?.delegate = self

        // 加入 RunLoop
        inputStream?.schedule(in: .main, forMode: .default)
        outputStream?.schedule(in: .main, forMode: .default)

        // 打开流
        inputStream?.open()
        outputStream?.open()

        return true
    }

    /// 关闭流
    private func closeStreams() {
        // 关闭输入流
        inputStream?.close()
        inputStream?.remove(from: .main, forMode: .default)
        inputStream?.delegate = nil
        inputStream = nil

        // 关闭输出流
        outputStream?.close()
        outputStream?.remove(from: .main, forMode: .default)
        outputStream?.delegate = nil
        outputStream = nil

        // 清空待发送数据
        sendQueue.async { [weak self] in
            self?.pendingData.removeAll()
            self?.isSending = false
        }
    }

    /// 读取数据
    private func readData() {
        guard let inputStream = inputStream else { return }

        var buffer = [UInt8](repeating: 0, count: receiveBufferSize)
        var receivedData = Data()

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: receiveBufferSize)

            if bytesRead > 0 {
                receivedData.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                delegate?.accessoryManager(self, didEncounterError: .streamReadFailed)
                break
            }
        }

        if !receivedData.isEmpty {
            delegate?.accessoryManager(self, didReceiveData: receivedData)
        }
    }

    /// 处理发送队列
    private func processSendQueue() {
        guard !isSending, !pendingData.isEmpty else { return }
        guard let outputStream = outputStream, outputStream.hasSpaceAvailable else { return }

        isSending = true

        let data = pendingData.removeFirst()

        let bytesWritten = data.withUnsafeBytes { buffer -> Int in
            guard let pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return outputStream.write(pointer, maxLength: data.count)
        }

        if bytesWritten < 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.accessoryManager(self, didEncounterError: .streamWriteFailed)
            }
        }

        isSending = false

        // 继续处理队列中的数据
        if !pendingData.isEmpty {
            processSendQueue()
        }
    }

    // MARK: - 私有方法 - 配件管理

    /// 检查已连接的配件
    private func checkConnectedAccessories() {
        let accessories = getSupportedAccessories()

        // 优先连接上次连接的配件
        if let targetSerial = targetSerialNumber,
           let accessory = accessories.first(where: { $0.serialNumber == targetSerial }) {
            connect(to: accessory)
        } else if let accessory = accessories.first {
            // 连接第一个可用配件
            connect(to: accessory)
        }
    }

    /// 保存最后连接的配件序列号
    private func saveLastConnectedSerial(_ serial: String) {
        UserDefaults.standard.set(serial, forKey: Self.lastConnectedSerialKey)
    }

    /// 加载最后连接的配件序列号
    private func loadLastConnectedSerial() -> String? {
        return UserDefaults.standard.string(forKey: Self.lastConnectedSerialKey)
    }

    // MARK: - 私有方法 - 重连

    /// 开始重连定时器
    private func startReconnectTimer() {
        guard autoReconnectEnabled else { return }

        stopReconnectTimer()
        connectionState = .reconnecting

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            self?.attemptReconnect()
        }
    }

    /// 停止重连定时器
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    /// 尝试重连
    private func attemptReconnect() {
        // 检查重连次数
        if maxReconnectAttempts > 0 && reconnectAttempts >= maxReconnectAttempts {
            stopReconnectTimer()
            connectionState = .disconnected
            delegate?.accessoryManager(self, didEncounterError: .maxReconnectAttemptsReached)
            return
        }

        reconnectAttempts += 1

        let accessories = getSupportedAccessories()

        // 优先连接目标配件
        if let targetSerial = targetSerialNumber,
           let accessory = accessories.first(where: { $0.serialNumber == targetSerial }) {
            if connect(to: accessory) {
                stopReconnectTimer()
            }
        } else if let accessory = accessories.first {
            if connect(to: accessory) {
                stopReconnectTimer()
            }
        }
    }

    // MARK: - 私有方法 - 工具

    /// 十六进制字符串转 Data
    private func hexStringToData(_ hex: String) -> Data {
        var data = Data()
        var temp = ""

        for char in hex.replacingOccurrences(of: " ", with: "") {
            temp += String(char)
            if temp.count == 2 {
                if let byte = UInt8(temp, radix: 16) {
                    data.append(byte)
                }
                temp = ""
            }
        }

        return data
    }

    // MARK: - 通知处理

    /// 处理配件连接通知
    @objc private func handleAccessoryDidConnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else {
            return
        }

        // 检查是否支持协议
        guard accessory.protocolStrings.contains(protocolString) else {
            return
        }

        // 如果已连接，忽略
        guard connectionState != .connected else {
            return
        }

        // 停止重连
        stopReconnectTimer()
        reconnectAttempts = 0

        // 检查是否是目标配件
        if let targetSerial = targetSerialNumber {
            if accessory.serialNumber == targetSerial {
                connect(to: accessory)
            }
        } else {
            connect(to: accessory)
        }
    }

    /// 处理配件断开通知
    @objc private func handleAccessoryDidDisconnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else {
            return
        }

        // 检查是否是当前连接的配件
        guard accessory.serialNumber == connectedAccessory?.serialNumber else {
            return
        }

        // 断开连接
        disconnect()

        // 开始重连
        if autoReconnectEnabled {
            startReconnectTimer()
        }
    }

    /// 处理 App 进入前台
    @objc private func handleAppDidBecomeActive() {
        // 如果未连接，尝试重连
        if connectionState != .connected {
            attemptReconnect()
        }
    }
}

// MARK: - StreamDelegate

extension MFiAccessoryManager: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            // 流已打开
            break

        case .hasBytesAvailable:
            // 有数据可读
            if aStream == inputStream {
                readData()
            }

        case .hasSpaceAvailable:
            // 可以写入数据
            if aStream == outputStream {
                sendQueue.async { [weak self] in
                    self?.processSendQueue()
                }
            }

        case .errorOccurred:
            // 发生错误
            if aStream == inputStream {
                delegate?.accessoryManager(self, didEncounterError: .streamReadFailed)
            } else if aStream == outputStream {
                delegate?.accessoryManager(self, didEncounterError: .streamWriteFailed)
            }

        case .endEncountered:
            // 流结束，断开连接
            disconnect()
            if autoReconnectEnabled {
                startReconnectTimer()
            }

        default:
            break
        }
    }
}

// MARK: - 配件信息扩展

public extension EAAccessory {
    /// 配件描述信息
    var accessoryDescription: String {
        return """
        名称: \(name)
        制造商: \(manufacturer)
        型号: \(modelNumber)
        序列号: \(serialNumber)
        固件版本: \(firmwareRevision)
        硬件版本: \(hardwareRevision)
        协议: \(protocolStrings.joined(separator: ", "))
        """
    }
}
