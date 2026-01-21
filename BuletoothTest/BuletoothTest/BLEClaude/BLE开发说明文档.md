# iOS BLE 蓝牙开发说明文档

## 目录

1. [概述](#概述)
2. [文件说明](#文件说明)
3. [核心架构](#核心架构)
4. [快速开始](#快速开始)
5. [功能详解](#功能详解)
6. [API 参考](#api-参考)
7. [常见问题](#常见问题)

---

## 概述

本项目提供了一套完整的 iOS BLE（Bluetooth Low Energy）蓝牙开发解决方案，基于 Apple 的 CoreBluetooth 框架封装，支持：

- 设备扫描与发现
- 设备连接与断开
- 数据收发通信
- 自动回连机制
- 多设备同时管理

---

## 文件说明

| 文件名 | 说明 |
|--------|------|
| `BLEManager.swift` | BLE 核心管理类，包含所有蓝牙操作逻辑 |
| `BLEUsageExample.swift` | 使用示例，包含 UI 界面和多设备管理示例 |

---

## 核心架构

### CoreBluetooth 框架结构

```
┌─────────────────────────────────────────────────────────────┐
│                    CoreBluetooth 架构                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │ CBCentralManager│ ◄─────► │  CBPeripheral   │           │
│  │   (中心设备)     │         │   (外围设备)     │           │
│  └────────┬────────┘         └────────┬────────┘           │
│           │                           │                     │
│           │ 管理                       │ 包含                │
│           ▼                           ▼                     │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │ 扫描/连接/断开   │         │   CBService     │           │
│  │                 │         │    (服务)        │           │
│  └─────────────────┘         └────────┬────────┘           │
│                                       │ 包含                │
│                                       ▼                     │
│                              ┌─────────────────┐           │
│                              │CBCharacteristic │           │
│                              │    (特征)        │           │
│                              └─────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 核心类说明

| 类名 | 作用 |
|------|------|
| `CBCentralManager` | 中心管理器，负责扫描、连接外围设备 |
| `CBPeripheral` | 外围设备，代表一个 BLE 设备 |
| `CBService` | 服务，设备提供的功能分组 |
| `CBCharacteristic` | 特征，实际的数据读写点 |
| `CBUUID` | 蓝牙 UUID，标识服务和特征 |

### BLE 通信流程

```
蓝牙开启 → 扫描设备 → 发现设备 → 连接设备 → 发现服务 → 发现特征 → 数据通信 → 断开连接
    │                                                              │
    └──────────────────── 自动回连 ◄────────────────────────────────┘
```

---

## 快速开始

### 1. 添加文件到项目

将 `BLEManager.swift` 和 `BLEUsageExample.swift` 添加到你的 Xcode 项目中。

### 2. 配置 Info.plist

在 `Info.plist` 中添加蓝牙权限说明：

```xml
<!-- 蓝牙权限说明（必须） -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限来连接您的设备</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要蓝牙权限来连接您的设备</string>

<!-- 后台模式（如需后台运行，可选） -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

### 3. 基本使用

```swift
import CoreBluetooth

class YourViewController: UIViewController, BLEManagerDelegate {

    // 定义你的服务和特征 UUID
    let serviceUUID = CBUUID(string: "YOUR-SERVICE-UUID")
    let characteristicUUID = CBUUID(string: "YOUR-CHARACTERISTIC-UUID")

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. 设置代理
        BLEManager.shared.delegate = self

        // 2. 配置目标 UUID（可选，用于过滤）
        BLEManager.shared.targetServiceUUIDs = [serviceUUID]
    }

    // 3. 开始扫描
    func startScan() {
        BLEManager.shared.startScanning()
    }

    // 4. 实现代理方法
    func bleManagerDidDiscoverDevice(_ device: DiscoveredDevice) {
        print("发现设备: \(device.name)")
        // 连接设备
        BLEManager.shared.connect(to: device.peripheral, autoReconnect: true)
    }

    func bleManagerDidConnect(_ peripheral: CBPeripheral) {
        print("连接成功")
        BLEManager.shared.stopScanning()
    }

    func bleManagerDidReceiveData(_ data: Data, from peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("收到数据: \(data.hexString)")
    }

    func bleManagerDidUpdateState(_ state: CBManagerState) {
        if state == .poweredOn {
            startScan()
        }
    }

    func bleManagerDidDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        print("设备断开")
    }
}
```

---

## 功能详解

### 1. 设备发现

#### 方式一：主动扫描

```swift
// 扫描所有设备
BLEManager.shared.startScanning()

// 扫描指定服务的设备（推荐，更高效）
BLEManager.shared.startScanning(serviceUUIDs: [serviceUUID])

// 允许重复上报（用于实时 RSSI 更新）
BLEManager.shared.startScanning(allowDuplicates: true)

// 停止扫描
BLEManager.shared.stopScanning()
```

#### 方式二：检索已知设备

```swift
// 检索系统已连接的设备（可能被其他 App 连接）
let connected = BLEManager.shared.retrieveConnectedPeripherals(withServices: [serviceUUID])

// 检索之前连接过的设备（通过 UUID）
let known = BLEManager.shared.retrievePeripherals(withIdentifiers: [deviceUUID])
```

### 2. 设备连接

```swift
// 连接设备
BLEManager.shared.connect(to: peripheral, autoReconnect: true)

// 通过 UUID 连接
BLEManager.shared.connect(toDeviceWithID: deviceUUID, autoReconnect: true)
```

### 3. 数据发送

```swift
// 发送 Data
let data = Data([0x01, 0x02, 0x03])
BLEManager.shared.writeData(data, to: characteristicUUID, peripheralID: deviceID)

// 发送字符串
BLEManager.shared.writeString("Hello", to: characteristicUUID, peripheralID: deviceID)

// 指定写入类型
BLEManager.shared.writeData(data, to: characteristicUUID, peripheralID: deviceID, writeType: .withoutResponse)
```

**写入类型说明：**

| 类型 | 说明 |
|------|------|
| `.withResponse` | 需要设备确认，可靠但较慢（默认） |
| `.withoutResponse` | 不需要确认，快速但可能丢失 |

### 4. 数据接收

#### 方式一：订阅通知（推荐）

```swift
// 订阅通知
BLEManager.shared.setNotify(true, for: characteristicUUID, peripheralID: deviceID)

// 取消订阅
BLEManager.shared.setNotify(false, for: characteristicUUID, peripheralID: deviceID)

// 订阅所有可通知特征
BLEManager.shared.enableAllNotifications(for: deviceID)
```

#### 方式二：主动读取

```swift
BLEManager.shared.readValue(from: characteristicUUID, peripheralID: deviceID)
```

### 5. 断开连接

```swift
// 断开指定设备
BLEManager.shared.disconnect(peripheralID: deviceID)

// 断开并移除自动回连
BLEManager.shared.disconnect(peripheralID: deviceID, removeAutoReconnect: true)

// 断开所有设备
BLEManager.shared.disconnectAll()
```

### 6. 自动回连

```swift
// 连接时启用自动回连
BLEManager.shared.connect(to: peripheral, autoReconnect: true)

// 手动触发自动回连（App 启动时自动调用）
BLEManager.shared.attemptAutoReconnect()

// 从自动回连列表移除
BLEManager.shared.removeFromAutoReconnect(deviceID)
```

### 7. 多设备管理

```swift
// 获取所有已连接设备
let connectedDevices = BLEManager.shared.connectedPeripherals

// 遍历发送数据
for (deviceID, peripheral) in connectedDevices {
    BLEManager.shared.writeData(data, to: characteristicUUID, peripheralID: deviceID)
}

// 根据 UUID 区分设备
func bleManagerDidReceiveData(_ data: Data, from peripheral: CBPeripheral, characteristic: CBCharacteristic) {
    let deviceID = peripheral.identifier

    switch deviceID {
    case sensorDeviceID:
        handleSensorData(data)
    case controllerDeviceID:
        handleControllerData(data)
    default:
        break
    }
}
```

---

## API 参考

### BLEManager 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `shared` | `BLEManager` | 单例实例 |
| `delegate` | `BLEManagerDelegate?` | 代理 |
| `discoveredDevices` | `[UUID: DiscoveredDevice]` | 已发现设备 |
| `connectedPeripherals` | `[UUID: CBPeripheral]` | 已连接设备 |
| `bluetoothState` | `CBManagerState` | 蓝牙状态 |
| `targetServiceUUIDs` | `[CBUUID]` | 目标服务 UUID |
| `targetCharacteristicUUIDs` | `[CBUUID]` | 目标特征 UUID |

### BLEManager 方法

| 方法 | 说明 |
|------|------|
| `startScanning(serviceUUIDs:allowDuplicates:)` | 开始扫描 |
| `stopScanning()` | 停止扫描 |
| `retrieveConnectedPeripherals(withServices:)` | 检索已连接设备 |
| `retrievePeripherals(withIdentifiers:)` | 检索已知设备 |
| `connect(to:autoReconnect:)` | 连接设备 |
| `connect(toDeviceWithID:autoReconnect:)` | 通过 UUID 连接 |
| `disconnect(peripheralID:removeAutoReconnect:)` | 断开连接 |
| `disconnectAll(removeAutoReconnect:)` | 断开所有连接 |
| `writeData(_:to:peripheralID:writeType:)` | 写入数据 |
| `writeString(_:to:peripheralID:)` | 写入字符串 |
| `readValue(from:peripheralID:)` | 读取特征值 |
| `setNotify(_:for:peripheralID:)` | 设置通知 |
| `enableAllNotifications(for:)` | 启用所有通知 |
| `attemptAutoReconnect()` | 尝试自动回连 |
| `removeFromAutoReconnect(_:)` | 移除自动回连 |

### BLEManagerDelegate 方法

| 方法 | 说明 |
|------|------|
| `bleManagerDidUpdateState(_:)` | 蓝牙状态更新 |
| `bleManagerDidDiscoverDevice(_:)` | 发现设备 |
| `bleManagerDidConnect(_:)` | 连接成功 |
| `bleManagerDidDisconnect(_:error:)` | 断开连接 |
| `bleManagerDidReceiveData(_:from:characteristic:)` | 收到数据 |

### DiscoveredDevice 结构

| 属性 | 类型 | 说明 |
|------|------|------|
| `peripheral` | `CBPeripheral` | 外围设备对象 |
| `advertisementData` | `[String: Any]` | 广播数据 |
| `rssi` | `NSNumber` | 信号强度 |
| `lastSeen` | `Date` | 最后发现时间 |
| `identifier` | `UUID` | 设备唯一标识 |
| `name` | `String` | 设备名称 |

---

## 常见问题

### Q1: 扫描不到设备？

1. 确认蓝牙已开启
2. 确认设备正在广播
3. 检查 Info.plist 权限配置
4. 尝试不指定 serviceUUIDs 扫描所有设备

### Q2: 连接后无法发送数据？

1. 确认已发现服务和特征
2. 检查特征是否支持写入（查看 properties）
3. 确认使用正确的特征 UUID

### Q3: 收不到设备数据？

1. 确认已订阅通知 `setNotify(true, ...)`
2. 检查特征是否支持 notify 或 indicate
3. 确认设备端正在发送数据

### Q4: 自动回连不生效？

1. 确认连接时设置了 `autoReconnect: true`
2. 确认设备在附近且正在广播
3. 检查 `autoReconnectDeviceIDs` 是否包含设备 UUID

### Q5: 如何区分多个设备？

使用 `peripheral.identifier`（UUID）作为唯一标识：

```swift
let deviceID = peripheral.identifier

// 存储设备信息
deviceInfoMap[deviceID] = DeviceInfo(...)

// 发送数据时指定设备
BLEManager.shared.writeData(data, to: charUUID, peripheralID: deviceID)
```

### Q6: 后台运行蓝牙？

1. 在 Info.plist 添加后台模式：
```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

2. 使用状态恢复（已在 BLEManager 中配置）

---

## 特征属性说明

| 属性 | 说明 |
|------|------|
| `.read` | 支持读取 |
| `.write` | 支持写入（需要响应） |
| `.writeWithoutResponse` | 支持写入（无需响应） |
| `.notify` | 支持通知 |
| `.indicate` | 支持指示（带确认的通知） |

---

## 数据转换工具

```swift
// Data 转十六进制字符串
let hexString = data.hexString  // "01 02 03 04"

// 十六进制字符串转 Data
let data = Data(hexString: "01 02 03 04")

// Data 转字节数组
let bytes = [UInt8](data)

// 字节数组转 Data
let data = Data([0x01, 0x02, 0x03])
```

---

## 版本信息

- 适用平台：iOS 10.0+
- 开发语言：Swift 5.0+
- 依赖框架：CoreBluetooth

---

## 联系方式

如有问题，请联系开发者。
