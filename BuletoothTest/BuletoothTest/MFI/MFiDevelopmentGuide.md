# 苹果 MFi 开发完整指南 (Swift)

## 目录
1. [概述](#1-概述)
2. [开发前准备](#2-开发前准备)
3. [设备发现](#3-设备发现)
4. [设备连接](#4-设备连接)
5. [数据通信](#5-数据通信)
6. [断开连接](#6-断开连接)
7. [自动重连](#7-自动重连)
8. [完整流程图](#8-完整流程图)
9. [常见问题](#9-常见问题)

---

## 1. 概述

### 1.1 什么是 MFi
MFi (Made for iPhone/iPad/iPod) 是苹果公司的外部配件认证程序。通过 MFi 认证的配件可以：
- 通过 Lightning/USB-C 接口与 iOS 设备通信
- 通过蓝牙与 iOS 设备通信
- 使用苹果专有的通信协议

### 1.2 核心框架
iOS 开发中使用 **ExternalAccessory.framework** 与 MFi 配件通信。

### 1.3 通信方式
| 方式 | 说明 |
|------|------|
| 有线连接 | Lightning/USB-C 直连 |
| 蓝牙 SPP | 经典蓝牙串口协议 |
| iAP2 | iPod Accessory Protocol 2.0 |

---

## 2. 开发前准备

### 2.1 硬件要求
- 配件厂商必须加入苹果 MFi 计划
- 配件需通过 MFi 认证
- 配件需要有唯一的 **Protocol String**（由苹果分配）

### 2.2 Info.plist 配置

```xml
<!-- 声明支持的外部配件协议 -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <!-- 替换为你的配件协议字符串 -->
    <string>com.yourcompany.yourprotocol</string>
</array>

<!-- 如果需要后台通信，添加后台模式 -->
<key>UIBackgroundModes</key>
<array>
    <string>external-accessory</string>
</array>
```

### 2.3 导入框架

```swift
import ExternalAccessory
```

---

## 3. 设备发现

### 3.1 核心类
- `EAAccessoryManager`: 配件管理器单例，管理所有已连接的配件
- `EAAccessory`: 代表一个外部配件

### 3.2 获取已连接设备

```swift
// 获取配件管理器单例
let accessoryManager = EAAccessoryManager.shared()

// 获取当前已连接的所有配件
let connectedAccessories = accessoryManager.connectedAccessories

// 遍历查找目标配件
for accessory in connectedAccessories {
    print("配件名称: \(accessory.name)")
    print("制造商: \(accessory.manufacturer)")
    print("型号: \(accessory.modelNumber)")
    print("序列号: \(accessory.serialNumber)")
    print("固件版本: \(accessory.firmwareRevision)")
    print("硬件版本: \(accessory.hardwareRevision)")
    print("支持的协议: \(accessory.protocolStrings)")
}
```

### 3.3 监听设备连接/断开通知

```swift
// 注册通知
NotificationCenter.default.addObserver(
    self,
    selector: #selector(accessoryDidConnect(_:)),
    name: .EAAccessoryDidConnect,
    object: nil
)

NotificationCenter.default.addObserver(
    self,
    selector: #selector(accessoryDidDisconnect(_:)),
    name: .EAAccessoryDidDisconnect,
    object: nil
)

// 开始监听连接事件（重要！必须调用）
EAAccessoryManager.shared().registerForLocalNotifications()

// 处理连接事件
@objc func accessoryDidConnect(_ notification: Notification) {
    if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
        print("配件已连接: \(accessory.name)")
    }
}

// 处理断开事件
@objc func accessoryDidDisconnect(_ notification: Notification) {
    if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
        print("配件已断开: \(accessory.name)")
    }
}
```

### 3.4 显示蓝牙配件选择器（可选）

```swift
// 显示系统蓝牙配件选择界面
EAAccessoryManager.shared().showBluetoothAccessoryPicker(withNameFilter: nil) { error in
    if let error = error {
        print("选择配件失败: \(error.localizedDescription)")
    } else {
        print("用户已选择配件")
    }
}
```

---

## 4. 设备连接

### 4.1 核心类
- `EASession`: 与配件的通信会话
- `InputStream`: 输入流，用于接收数据
- `OutputStream`: 输出流，用于发送数据

### 4.2 建立会话连接

```swift
class AccessoryConnection: NSObject {
    var accessory: EAAccessory?
    var session: EASession?
    var protocolString: String

    // 输入输出流
    var inputStream: InputStream?
    var outputStream: OutputStream?

    init(protocolString: String) {
        self.protocolString = protocolString
        super.init()
    }

    /// 连接到指定配件
    func connect(to accessory: EAAccessory) -> Bool {
        // 检查配件是否支持目标协议
        guard accessory.protocolStrings.contains(protocolString) else {
            print("配件不支持协议: \(protocolString)")
            return false
        }

        // 创建会话
        guard let session = EASession(accessory: accessory, forProtocol: protocolString) else {
            print("创建会话失败")
            return false
        }

        self.accessory = accessory
        self.session = session

        // 获取输入输出流
        self.inputStream = session.inputStream
        self.outputStream = session.outputStream

        // 配置流
        setupStreams()

        return true
    }

    /// 配置输入输出流
    private func setupStreams() {
        // 设置代理
        inputStream?.delegate = self
        outputStream?.delegate = self

        // 将流加入 RunLoop（重要！否则无法接收事件）
        inputStream?.schedule(in: .main, forMode: .default)
        outputStream?.schedule(in: .main, forMode: .default)

        // 打开流
        inputStream?.open()
        outputStream?.open()
    }
}
```

### 4.3 关键点说明

| 步骤 | 说明 |
|------|------|
| 协议匹配 | 必须使用配件支持的协议字符串创建会话 |
| 创建 EASession | 会话创建成功后才能获取输入输出流 |
| 配置 RunLoop | 流必须加入 RunLoop 才能接收事件 |
| 打开流 | 必须显式调用 open() 方法 |

---

## 5. 数据通信

### 5.1 实现 StreamDelegate

```swift
extension AccessoryConnection: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            // 流已打开
            print("流已打开")

        case .hasBytesAvailable:
            // 有数据可读（输入流）
            if aStream == inputStream {
                readData()
            }

        case .hasSpaceAvailable:
            // 可以写入数据（输出流）
            if aStream == outputStream {
                print("输出流就绪，可以发送数据")
            }

        case .errorOccurred:
            // 发生错误
            print("流错误: \(aStream.streamError?.localizedDescription ?? "未知错误")")

        case .endEncountered:
            // 流结束
            print("流已结束")
            closeSession()

        default:
            break
        }
    }
}
```

### 5.2 接收数据

```swift
extension AccessoryConnection {
    /// 读取数据缓冲区大小
    private static let bufferSize = 1024

    /// 从输入流读取数据
    func readData() {
        guard let inputStream = inputStream else { return }

        var buffer = [UInt8](repeating: 0, count: Self.bufferSize)
        var receivedData = Data()

        // 循环读取所有可用数据
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: Self.bufferSize)

            if bytesRead > 0 {
                receivedData.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                // 读取错误
                print("读取数据错误")
                break
            }
        }

        if !receivedData.isEmpty {
            // 处理接收到的数据
            handleReceivedData(receivedData)
        }
    }

    /// 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        print("收到数据: \(data.count) 字节")

        // 示例：转换为字符串
        if let string = String(data: data, encoding: .utf8) {
            print("数据内容: \(string)")
        }

        // 示例：转换为十六进制
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("十六进制: \(hexString)")

        // TODO: 根据你的协议解析数据
    }
}
```

### 5.3 发送数据

```swift
extension AccessoryConnection {
    /// 发送数据到配件
    /// - Parameter data: 要发送的数据
    /// - Returns: 实际发送的字节数，-1 表示失败
    @discardableResult
    func sendData(_ data: Data) -> Int {
        guard let outputStream = outputStream else {
            print("输出流不可用")
            return -1
        }

        // 检查流状态
        guard outputStream.hasSpaceAvailable else {
            print("输出流暂时不可写")
            return 0
        }

        // 发送数据
        let bytesWritten = data.withUnsafeBytes { buffer -> Int in
            guard let pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return outputStream.write(pointer, maxLength: data.count)
        }

        if bytesWritten > 0 {
            print("已发送 \(bytesWritten) 字节")
        } else if bytesWritten < 0 {
            print("发送数据失败: \(outputStream.streamError?.localizedDescription ?? "未知错误")")
        }

        return bytesWritten
    }

    /// 发送字符串
    func sendString(_ string: String) -> Int {
        guard let data = string.data(using: .utf8) else {
            return -1
        }
        return sendData(data)
    }

    /// 发送十六进制命令
    func sendHexCommand(_ hexString: String) -> Int {
        let data = hexStringToData(hexString)
        return sendData(data)
    }

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
}
```

### 5.4 大数据分包发送

```swift
extension AccessoryConnection {
    /// 分包发送大数据
    /// - Parameters:
    ///   - data: 要发送的数据
    ///   - packetSize: 每包大小（默认512字节）
    ///   - completion: 完成回调
    func sendLargeData(_ data: Data, packetSize: Int = 512, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            var offset = 0
            let totalSize = data.count

            while offset < totalSize {
                let chunkSize = min(packetSize, totalSize - offset)
                let chunk = data.subdata(in: offset..<(offset + chunkSize))

                // 等待输出流可写
                while !(self.outputStream?.hasSpaceAvailable ?? false) {
                    Thread.sleep(forTimeInterval: 0.01)
                }

                let bytesWritten = self.sendData(chunk)
                if bytesWritten < 0 {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }

                offset += bytesWritten
            }

            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}
```

---

## 6. 断开连接

### 6.1 关闭会话

```swift
extension AccessoryConnection {
    /// 关闭会话并释放资源
    func closeSession() {
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

        // 释放会话
        session = nil
        accessory = nil

        print("会话已关闭")
    }
}
```

### 6.2 注销通知

```swift
deinit {
    // 注销通知
    NotificationCenter.default.removeObserver(self)

    // 停止监听连接事件
    EAAccessoryManager.shared().unregisterForLocalNotifications()

    // 关闭会话
    closeSession()
}
```

---

## 7. 自动重连

### 7.1 重连策略

```swift
class AutoReconnectManager {
    /// 目标配件的序列号（用于识别配件）
    var targetSerialNumber: String?

    /// 目标协议字符串
    let protocolString: String

    /// 连接对象
    var connection: AccessoryConnection?

    /// 重连定时器
    private var reconnectTimer: Timer?

    /// 重连间隔（秒）
    private let reconnectInterval: TimeInterval = 3.0

    /// 最大重连次数
    private let maxReconnectAttempts = 10

    /// 当前重连次数
    private var reconnectAttempts = 0

    init(protocolString: String) {
        self.protocolString = protocolString
        setupNotifications()
    }

    /// 设置通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidConnect(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidDisconnect(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )

        // App 进入前台时检查连接
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        EAAccessoryManager.shared().registerForLocalNotifications()
    }
}
```

### 7.2 保存配件信息

```swift
extension AutoReconnectManager {
    /// UserDefaults 键
    private static let lastConnectedSerialKey = "MFi_LastConnectedSerial"

    /// 保存最后连接的配件信息
    func saveLastConnectedAccessory(_ accessory: EAAccessory) {
        targetSerialNumber = accessory.serialNumber
        UserDefaults.standard.set(accessory.serialNumber, forKey: Self.lastConnectedSerialKey)
    }

    /// 加载最后连接的配件信息
    func loadLastConnectedAccessory() -> String? {
        return UserDefaults.standard.string(forKey: Self.lastConnectedSerialKey)
    }

    /// 清除保存的配件信息
    func clearLastConnectedAccessory() {
        targetSerialNumber = nil
        UserDefaults.standard.removeObject(forKey: Self.lastConnectedSerialKey)
    }
}
```

### 7.3 自动重连逻辑

```swift
extension AutoReconnectManager {
    /// 配件连接时的处理
    @objc private func accessoryDidConnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else {
            return
        }

        // 停止重连定时器
        stopReconnectTimer()
        reconnectAttempts = 0

        // 检查是否是目标配件
        if let targetSerial = targetSerialNumber {
            if accessory.serialNumber == targetSerial {
                // 自动连接到之前的配件
                connectToAccessory(accessory)
            }
        } else {
            // 没有目标配件，连接新配件
            connectToAccessory(accessory)
        }
    }

    /// 配件断开时的处理
    @objc private func accessoryDidDisconnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else {
            return
        }

        // 检查是否是当前连接的配件
        if accessory.serialNumber == connection?.accessory?.serialNumber {
            connection?.closeSession()

            // 开始重连
            startReconnectTimer()
        }
    }

    /// App 进入前台
    @objc private func appDidBecomeActive() {
        // 检查是否需要重连
        if connection?.session == nil {
            attemptReconnect()
        }
    }

    /// 连接到配件
    private func connectToAccessory(_ accessory: EAAccessory) {
        let conn = AccessoryConnection(protocolString: protocolString)
        if conn.connect(to: accessory) {
            self.connection = conn
            saveLastConnectedAccessory(accessory)
            print("已连接到配件: \(accessory.name)")
        }
    }
}
```

### 7.4 重连定时器

```swift
extension AutoReconnectManager {
    /// 开始重连定时器
    func startReconnectTimer() {
        stopReconnectTimer()

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            self?.attemptReconnect()
        }
    }

    /// 停止重连定时器
    func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    /// 尝试重连
    func attemptReconnect() {
        // 检查重连次数
        guard reconnectAttempts < maxReconnectAttempts else {
            print("已达到最大重连次数")
            stopReconnectTimer()
            return
        }

        reconnectAttempts += 1
        print("尝试重连 (\(reconnectAttempts)/\(maxReconnectAttempts))")

        // 加载目标配件序列号
        if targetSerialNumber == nil {
            targetSerialNumber = loadLastConnectedAccessory()
        }

        // 查找目标配件
        let accessories = EAAccessoryManager.shared().connectedAccessories

        if let targetSerial = targetSerialNumber {
            // 查找特定配件
            if let accessory = accessories.first(where: { $0.serialNumber == targetSerial }) {
                connectToAccessory(accessory)
                stopReconnectTimer()
                reconnectAttempts = 0
            }
        } else {
            // 连接第一个支持协议的配件
            if let accessory = accessories.first(where: { $0.protocolStrings.contains(protocolString) }) {
                connectToAccessory(accessory)
                stopReconnectTimer()
                reconnectAttempts = 0
            }
        }
    }
}
```

---

## 8. 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                        MFi 通信流程                              │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   App 启动   │────▶│  注册通知    │────▶│  检查已连接  │
└──────────────┘     │  监听事件    │     │  的配件列表  │
                     └──────────────┘     └──────┬───────┘
                                                 │
                     ┌───────────────────────────┼───────────────────────────┐
                     │                           │                           │
                     ▼                           ▼                           ▼
              ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
              │  无配件连接  │           │  找到目标配件 │           │  找到新配件  │
              └──────┬───────┘           └──────┬───────┘           └──────┬───────┘
                     │                          │                          │
                     ▼                          ▼                          ▼
              ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
              │  等待配件    │           │  创建 Session │           │  提示用户    │
              │  连接通知    │           │  打开流      │           │  是否连接    │
              └──────────────┘           └──────┬───────┘           └──────────────┘
                                                │
                                                ▼
                                         ┌──────────────┐
                                         │  配置流代理  │
                                         │  加入RunLoop │
                                         └──────┬───────┘
                                                │
                     ┌──────────────────────────┼──────────────────────────┐
                     │                          │                          │
                     ▼                          ▼                          ▼
              ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
              │  发送数据    │           │  接收数据    │           │  错误处理    │
              │  outputStream│           │  inputStream │           │              │
              └──────────────┘           └──────────────┘           └──────┬───────┘
                                                                          │
                                                                          ▼
                                                                   ┌──────────────┐
                                                                   │  关闭会话    │
                                                                   │  尝试重连    │
                                                                   └──────────────┘
```

---

## 9. 常见问题

### 9.1 无法发现配件
- 检查 `Info.plist` 中的协议字符串是否正确
- 确认配件已通过 MFi 认证
- 检查配件是否正确连接（有线/蓝牙）

### 9.2 创建 Session 失败
- 确认协议字符串与配件支持的协议匹配
- 检查是否已有其他 Session 占用该配件
- 尝试断开重连配件

### 9.3 无法收发数据
- 确认流已正确打开
- 检查流是否已加入 RunLoop
- 确认 StreamDelegate 已正确设置

### 9.4 后台通信中断
- 确认已添加 `external-accessory` 后台模式
- 检查是否有其他 App 抢占了配件连接

### 9.5 蓝牙配件无法发现
- 确认配件已进入配对模式
- 在系统设置中检查蓝牙配对状态
- 使用 `showBluetoothAccessoryPicker` 方法

---

## 附录：关键 API 参考

| 类/方法 | 说明 |
|---------|------|
| `EAAccessoryManager.shared()` | 获取配件管理器单例 |
| `connectedAccessories` | 获取已连接的配件列表 |
| `registerForLocalNotifications()` | 开始监听配件连接事件 |
| `showBluetoothAccessoryPicker()` | 显示蓝牙配件选择器 |
| `EASession(accessory:forProtocol:)` | 创建通信会话 |
| `EAAccessoryDidConnect` | 配件连接通知 |
| `EAAccessoryDidDisconnect` | 配件断开通知 |

### 10 一个外设对象信息
<EAAccessory: 0x282afdab0> { 
  connected:YES 
  connectionID:33685633 
  name: 李未可 View AI眼镜 
  manufacturer: 李未可 
  modelNumber: LAWK View 
  serialNumber: 040025380108A000608 
  ppid: cf9734dfae8b4078 
  regioncode: (null) 
  firmwareRevisionActive: 1 
  firmwareRevisionPending: (null) 
  hardwareRevision: 1 
  dockType:  
  certSerial: 16 bytes 
  certData: 607 bytes 
  protocols: (
    "com.lawaken.iap2"
) 
  delegate: (null) 
}
