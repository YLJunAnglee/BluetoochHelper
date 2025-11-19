//
//  BluetoothDoc.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//
/**
 
 1.初始化CBCentralManager时，后台模式的两个key，都有什么用？
 CBCentralManagerOptionShowPowerAlertKey + CBCentralManagerOptionRestoreIdentifierKey
    
 let options: [String: Any] = [
     CBCentralManagerOptionShowPowerAlertKey: true
 ]
 
 这个选项是一个布尔值，用来决定是否在设备蓝牙未开启时弹出警告。
 如果设置为 true，当蓝牙未开启时，CBCentralManager 会自动显示一个提示框，告知用户开启蓝牙。这对于需要确保蓝牙可用的应用非常有用
 （验证：有提示框，提示内容："xxx想要使用蓝牙进行新连接，你可以在设置中允许新连接"）
 
 如果设备蓝牙关闭了，系统会弹出一个提示，用户可以选择打开蓝牙。（验证：主动关闭，并没有提示框弹出来）
 
 let options: [String: Any] = [
     CBCentralManagerOptionRestoreIdentifierKey: "yljBluetoothRestore"
 ]
 这个选项用于指定一个标识符，允许在应用被终止后恢复连接。通过这个选项，CBCentralManager 会保存连接的状态，并允许应用在重新启动时恢复已断开的蓝牙设备连接。

 例如，如果你在应用运行时已经连接了某个蓝牙设备，使用这个选项可以在应用重启时，恢复与该设备的连接状态。
 这个标识符将用于在应用重新启动时恢复上次的蓝牙状态。
 
 有这个参数，就必须实现 func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any])
 如果说，这个管理对象在应用启动时，就已经实例化了，那么系统就会自动回调这个方法
 
 
 2.扫描需要在蓝牙状态为power on 的情况下，进入到app需要请求蓝牙权限
    2.1Privacy - Bluetooth Always Usage Description 添加之后，app首次进入就会有弹窗，允许的话，下次就可以直接使用
    2.1.1这个权限描述是用来申请应用在任何时候使用蓝牙的权限，无论应用是否在前台运行（例如后台扫描设备或处理蓝牙连接）。
    ->这个有用
    
    2.2NSBluetoothPeripheralUsageDescription
    2.2.1这个权限描述是用来申请应用访问和使用蓝牙外设的权限。例如，当应用需要扫描周围的蓝牙外设（如蓝牙耳机、传感器等）时，需要提供这个权限说明。
    ->测试过，没用
 
 3.扫描方法分析
 centralManager?.scanForPeripherals(withServices: services, options: options)
    3.1 参数services（通过传递具体的服务 UUID 数组，蓝牙扫描将只返回提供了这些特定服务的外设）
    
 工作方式：

 如果你传递了 serviceUUIDs，蓝牙扫描将会过滤掉所有没有指定服务的外设。
 如果 serviceUUIDs 为 nil，则扫描所有设备，不管它们提供了哪些服务。
 
 serviceUUIDs：直接指定扫描时要关注的服务。如果外设提供了这些服务，它就会被返回；如果不提供这些服务，则会被忽略。
 目的：控制扫描时关注哪些服务。
 范围：影响扫描的设备类型，不管设备是否广播这些服务。
 
    3.2 参数options（CBCentralManagerScanOptionSolicitedServiceUUIDsKey）
 工作方式：

 CBCentralManagerScanOptionSolicitedServiceUUIDsKey 只会影响已经广播了这些服务 UUID 的外设。如果外设没有广播这些服务（即没有在广告包中包含相关的 UUID），它们将不会被扫描到。
 它通常与 scanForPeripherals 方法配合使用，帮助减少扫描过程中不必要的设备信息
 
 示例：
 let serviceUUIDs: [CBUUID] = [CBUUID(string: "180D")] // 心率服务 UUID
 let options: [String: Any] = [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: serviceUUIDs]
 centralManager.scanForPeripherals(withServices: nil, options: options)
 
 在这个示例中，蓝牙扫描将只返回在广告包中包含 180D 服务的设备。如果设备没有广播 180D 服务，虽然它可能提供这个服务，但它不会出现在扫描结果中。
 
 目的：过滤扫描结果，只关注广播了指定服务的设备。
 范围：影响扫描结果，依赖于外设是否广播了相关的服务 UUID。
 
 {
    一个LAWK City_Air眼镜，左右任意镜腿单独打开的扫描结果
    CBPeripheral: 0x11e275c00, identifier = 8F2B24CE-20A7-653D-651F-1525E7871D93, name = LAWK City_Air, mtu = 0, state = disconnected>
 
    广播信息：
    ["kCBAdvDataIsConnectable": 1,
    "kCBAdvDataTimestamp": 773823566.490423,
    "kCBAdvDataRxSecondaryPHY": 0,
    "kCBAdvDataServiceUUIDs": <__NSArrayM 0x11ec46070>(
    00001100-D102-11E1-9B23-00025B00A5A5
    ),
    "kCBAdvDataRxPrimaryPHY": 129,
    "kCBAdvDataLocalName": LAWK City_Air]
 
    rssi：-37
 
    第二个：
    CBPeripheral: 0x11e275c00, identifier = 8F2B24CE-20A7-653D-651F-1525E7871D93, name = LAWK City_Air, mtu = 0, state = disconnected>
 
    ["kCBAdvDataTimestamp": 773823565.986636,
    "kCBAdvDataServiceUUIDs": <__NSArrayM 0x11ec45500>(
    00001100-D102-11E1-9B23-00025B00A5A5
    ),
    "kCBAdvDataRxPrimaryPHY": 1,
    "kCBAdvDataIsConnectable": 1,
    "kCBAdvDataRxSecondaryPHY": 0]
 
    rssi：-38
 
    总结：无论是两个镜腿一起打开，还是单个打开任意一个，都会扫描到两个广播结果，外设的对象地址和id都是一样的，其他的稍有差异
 
    Meta Lens Chat 不能通过scan方法扫描到
    LAWK City_Air 可以通过scan方法扫描到,但并不是每次打开都能扫描到
    BrandSound01 可以通过scan方法扫描到，每次打开都能扫描到
 
    品声眼镜的扫描结果
    {
        CBPeripheral: 0x280d91a40, identifier = 37088EBD-6BB1-B85B-83D1-61DDCF8FDDD4, name = BrandSound01, mtu = 0, state = disconnected>
        ["kCBAdvDataManufacturerData": <5053658f 43c63b02>,
        "kCBAdvDataIsConnectable": 1,
        "kCBAdvDataTimestamp": 773904336.002775,
        "kCBAdvDataLocalName": BrandSound01,
        "kCBAdvDataRxSecondaryPHY": 0,
        "kCBAdvDataRxPrimaryPHY": 0]
    
        右耳数据 - 左耳数据也是这样
        CBPeripheral: 0x280d91b80, identifier = 37088EBD-6BB1-B85B-83D1-61DDCF8FDDD4, name = BrandSound01, mtu = 0, state = disconnected>
        ["kCBAdvDataManufacturerData": <5053658f 43c63b02>,
        "kCBAdvDataIsConnectable": 1,
        "kCBAdvDataTimestamp": 773904336.002775,
        "kCBAdvDataLocalName": BrandSound01,
        "kCBAdvDataRxSecondaryPHY": 0,
        "kCBAdvDataRxPrimaryPHY": 0]
    }
 
    
    3.3 通过服务id = 00001100-D102-11E1-9B23-00025B00A5A5，去扫描，品声的目前扫描不到，LAWK City_Air可以扫描到
 
    3.4 通过服务id = 00001100-D102-11E1-9B23-00025B00A5A5，用options扫描
        3.4.1如何服务id不传，无法收到回调
        3.4.2传服务id，brandsound、meta lane chat 都可以回调，LAWK City_Air不能
        3.4.3断开连接和连接上，都会回调，可以通过事件类型判断
 }
 
 4.蓝牙断开情况
    4.1手动调用centralManager.cancelPeripheralConnection(peripheral) 会走回调 didDisconnectPeripheral
    4.2关闭系统蓝牙，会走回调centralManagerDidUpdateState，stats=poweredOff
    4.3再次打开蓝牙，会走回调centralManagerDidUpdateState，stats=poweredOn
    4.4系统蓝牙列表里面，把蓝牙断开，会走回调didDisconnectPeripheral
    4.5主动关闭外设，会走回调didDisconnectPeripheral
 
 
 
 
 
 
 5. retrieveConnectedPeripherals(withServices: serviceIds)
    5.1系统蓝牙连接上，没有建立ble连接（没有调用注册方法）
        点击获取：CBPeripheral: 0x11c276a00,
                identifier = 07C49ADE-EC11-33A7-9921-C152D8D0EE9C,
                name = Meta Lens Chat D032,
                mtu = 0, state = disconnected
 
                品声
                CBPeripheral: 0x11c276ae0,
                identifier = 9071DF7F-8C64-14A1-7CF5-E90C650F7DDF,
                name = (null),
                mtu = 0, state = disconnected
 
        后台进入前台，打印结果同上，此时品声没有名称
 
    5.2系统蓝牙连接上，没有建立ble连接（调用注册方法）
    此时，详细的注册列表结果，都已经可以返回回来了
    点击获取：
    CBPeripheral: 0x148eec540, identifier = 07C49ADE-EC11-33A7-9921-C152D8D0EE9C, name = Meta Lens Chat D032, mtu = 672, state = disconnected
    CBPeripheral: 0x148eec460, identifier = 9071DF7F-8C64-14A1-7CF5-E90C650F7DDF, name = BrandSound01, mtu = 672, state = disconnected
    后台进前台，打印结果同上，此时品声有名称
 
 
 
 
 
 */
