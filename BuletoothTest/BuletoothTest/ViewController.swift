//
//  ViewController.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/7/9.
//

/**
 iOS连接外设的代码实现流程
 
 1. 建立中心角色
 2. 扫描外设（discover）
 3. 连接外设(connect)
 4. 扫描外设中的服务和特征(discover)
     - 4.1 获取外设的services
     - 4.2 获取外设的Characteristics,获取Characteristics的值，获取Characteristics的Descriptor和Descriptor的值
 5. 与外设做数据交互(explore and interact)
 6. 订阅Characteristic的通知
 7. 断开连接(disconnect)
 */

import UIKit
import ABLoggerKit
import SnapKit
import CoreBluetooth

public let v6ServiceId = "0000fff1-0000-1000-8000-00805f9b34fb"
public let aacServiceId = "00001100-D102-11E1-9B23-00025B00A5A5"

class ViewController: UIViewController {
    private var spaceing: CGFloat = 15.0
    private var selectButton: UIBarButtonItem!
    private var logButton: UIBarButtonItem!
    private var serviceLogButton: UIBarButtonItem!
    private var identifyLogButton: UIBarButtonItem!
    private var statusLabel: UILabel!
    private var tableView: UITableView!
    
    /// 外设列表
    private var peripheralList: [CBPeripheral] = [CBPeripheral]()

    private lazy var bluetoothConfig = {
        var config = BluetoothConfig()
        config.identify = "brandsoundbase"
        return config
    }()
    
    private lazy var brandsoundOTAConfig = {
        var config = BluetoothConfig()
        config.identify                 = "brandsoundota"
        config.serviceUUID              = CBUUID(string: "FF12")
        config.characteristicsUUID      = CBUUID(string: "FF14")
        config.characteristicsUUIDRx    = CBUUID(string: "FF15")
        return config
    }()
    
    private lazy var metalanechatConfig = {
        var config = BluetoothConfig()
        config.identify = "metalanechatConfig"
        return config
    }()
    
    private var connectPeripheral: CBPeripheral?
    private var metachatConnectPeripheral: CBPeripheral?
    private var btConnector: BluetoothConnector?

    override func viewDidLoad() {
        super.viewDidLoad()
        // 监听进入前台通知
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeGround), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.darkGray
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: "customCell")
        self.view.addSubview(tableView)
        
        setupViews()
        
        btConnector = BluetoothConnector.shared
        btConnector?.statusDelegate = self
        btConnector?.dataSource = self
    }
    
    @objc func appWillEnterForeGround() {
        let serviceIds = [CBUUID.init(string: "00001100-D102-11E1-9B23-00025B00A5A5")]
        let pps = BluetoothConnector.shared.getCentralManager()?.retrieveConnectedPeripherals(withServices: serviceIds)
        Logger.i(self, "ForeGround - \(String(describing: pps))")
    }

    private func setupViews() {
        // Right Buttons
        selectButton = UIBarButtonItem(title: "选择",
                                       style: .plain,
                                       target: self,
                                       action: #selector(selectOtaFile(_:)))
        logButton = UIBarButtonItem(title: "Log",
                                    style: .plain,
                                    target: self,
                                    action: #selector(openLogViewer))
        serviceLogButton = UIBarButtonItem(title: "retriveService",
                                    style: .plain,
                                    target: self,
                                    action: #selector(retriveByServices(_:)))
        identifyLogButton = UIBarButtonItem(title: "retriveById",
                                    style: .plain,
                                    target: self,
                                    action: #selector(retriveByIdentifiers(_:)))
        navigationItem.rightBarButtonItems = [logButton, selectButton, serviceLogButton, identifyLogButton]
        
        let buttonW = (Screen_width - spaceing * 4) / 3
        let buttonH = 40
        
        let label = UILabel()
        label.text = "状态显示："
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.black
        self.view.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(NavigationHeight + spaceing)
            make.left.equalTo(spaceing)
            make.height.equalTo(25)
            make.width.equalTo(100)
        }
        statusLabel = UILabel()
        statusLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        statusLabel.textColor = UIColor.black
        self.view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(NavigationHeight + spaceing)
            make.left.equalTo(label.snp_rightMargin)
            make.right.equalToSuperview().offset(-spaceing)
            make.height.equalTo(25)
        }
        
        /// 开始扫描
        let scanBtn = createButton(title: "开始扫描", action: #selector(startScan))
        scanBtn.snp.makeConstraints { make in
            make.top.equalTo(label.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        /// 开始注册
        let registerBtn = createButton(title: "开始注册", action: #selector(registerScan))
        registerBtn.snp.makeConstraints { make in
            make.top.equalTo(scanBtn)
            make.left.equalTo(scanBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        /// 开始扫描
        let settingBtn = createButton(title: "跳转系统蓝牙", action: #selector(gotoSettingPage))
        settingBtn.snp.makeConstraints { make in
            make.top.equalTo(registerBtn)
            make.left.equalTo(registerBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }

        /// 结果列表
        tableView.snp.makeConstraints { make in
            make.top.equalTo(scanBtn.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(spaceing)
            make.right.equalToSuperview().offset(-spaceing)
            make.height.equalTo(200)
        }
        
        /// MIC
        let micOpenBtn = createButton(title: "MIC开", action: #selector(sendMicOpen))
        micOpenBtn.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        /// MIC扫描
        let micCloseBtn = createButton(title: "MIC关", action: #selector(sendMicClose))
        micCloseBtn.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(micOpenBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        /// 断开连接
        let disconnectBtn = createButton(title: "断开连接", action: #selector(setDisconnect))
        disconnectBtn.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(micCloseBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let beepBtn0 = createButton(title: "提示音-闭麦", action: #selector(sendBeedClose))
        beepBtn0.snp.makeConstraints { make in
            make.top.equalTo(micOpenBtn.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(micOpenBtn)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let beepBtn1 = createButton(title: "提示音-开麦", action: #selector(sendBeedOpen))
        beepBtn1.snp.makeConstraints { make in
            make.top.equalTo(beepBtn0)
            make.left.equalTo(beepBtn0.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let beepBtn2 = createButton(title: "提示音-等待", action: #selector(sendBeedWait))
        beepBtn2.snp.makeConstraints { make in
            make.top.equalTo(beepBtn0)
            make.left.equalTo(beepBtn1.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let brandsoundOtaConnect = createButton(title: "品声ota连接", action: #selector(brandsoundOtaConnect))
        brandsoundOtaConnect.snp.makeConstraints { make in
            make.top.equalTo(beepBtn0.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(beepBtn0)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let brandsoundOtaDisConnect = createButton(title: "品声ota断开", action: #selector(brandsoundOtaDisConnect))
        brandsoundOtaDisConnect.snp.makeConstraints { make in
            make.top.equalTo(brandsoundOtaConnect)
            make.left.equalTo(brandsoundOtaConnect.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let lanechatDisConnect = createButton(title: "Meta断开", action: #selector(metalanechatDisConnect))
        lanechatDisConnect.snp.makeConstraints { make in
            make.top.equalTo(brandsoundOtaConnect)
            make.left.equalTo(brandsoundOtaDisConnect.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let chatBeepBtn0 = createButton(title: "chat提示音闭麦", action: #selector(sendChatBeedClose))
        chatBeepBtn0.snp.makeConstraints { make in
            make.top.equalTo(brandsoundOtaConnect.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(brandsoundOtaConnect)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let chatBeepBtn1 = createButton(title: "chat提示音开麦", action: #selector(sendChatBeedOpen))
        chatBeepBtn1.snp.makeConstraints { make in
            make.top.equalTo(chatBeepBtn0)
            make.left.equalTo(chatBeepBtn0.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let chatBeepBtn2 = createButton(title: "chat提示音等待", action: #selector(sendChatBeedWait))
        chatBeepBtn2.snp.makeConstraints { make in
            make.top.equalTo(chatBeepBtn0)
            make.left.equalTo(chatBeepBtn1.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let brandsoundOtasend = createButton(title: "OTA眼睛信息", action: #selector(sendBrandsoundOtaMic))
        brandsoundOtasend.snp.makeConstraints { make in
            make.top.equalTo(chatBeepBtn0.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(chatBeepBtn0)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        let zhilingji = createButton(title: "指令合集", action: #selector(zhilingji))
        zhilingji.snp.makeConstraints { make in
            make.top.equalTo(chatBeepBtn0.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(brandsoundOtasend.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        
        let audioJump = createButton(title: "手机录音", action: #selector(jumpAudioRecord))
        audioJump.snp.makeConstraints { make in
            make.top.equalTo(chatBeepBtn0.snp_bottomMargin).offset(2*spaceing)
            make.left.equalTo(zhilingji.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
    }
    
    @objc
    private func openLogViewer() {
        openOpenLogViewer()
    }
    
    private func openOpenLogViewer() {
        let vc = LogViewerViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    func selectOtaFile(_ sender: Any) {}
    
    /**
     
        1. retrievePeripherals(withIdentifiers:) 只返回系统已记住的设备
        2. retrieveConnectedPeripherals(withServices:) 只返回当前已连接的设备
     
     */
    
    @objc
    func retriveByServices(_ sender: Any) {
        let serviceIds = [CBUUID.init(string: v6ServiceId)]
        let pps = BluetoothConnector.shared.getCentralManager()?.retrieveConnectedPeripherals(withServices: serviceIds)
        Logger.i(self, "\(String(describing: pps))")
    }
    
    @objc
    func retriveByIdentifiers(_ sender: Any) {
        if let connectPeripheral = connectPeripheral {
            let pps = BluetoothConnector.shared.getCentralManager()?.retrievePeripherals(withIdentifiers: [connectPeripheral.identifier])
            Logger.i(self, "\(String(describing: pps))")
        } else {
            if let brandsoundP = peripheralList.filter({matchBrandSoundDevice(deviceName: $0.name ?? "")}).first {
                let pps = BluetoothConnector.shared.getCentralManager()?.retrievePeripherals(withIdentifiers: [brandsoundP.identifier])
                Logger.i(self, "\(String(describing: pps))")
            }
        }
    }
    
    @objc
    func startScan() {
        /// 附带服务id扫描
        let serviceIds = [CBUUID.init(string: "00001100-D102-11E1-9B23-00025B00A5A5")]
        
        let option = [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: serviceIds]
        
        BluetoothConnector.shared.startScan(with: [CBUUID(string:"00001100-D102-11E1-9B23-00025B00A5A5")], options: [CBConnectionEventMatchingOption.serviceUUIDs.rawValue:[CBUUID(string:"00001100-D102-11E1-9B23-00025B00A5A5")]])
        
        showToast(message: "开始扫描")
    }
    
    @objc
    func registerScan() {
        ///*  @seealso            CBConnectionEventMatchingOptionServiceUUIDs
        ///*  @seealso            CBConnectionEventMatchingOptionPeripheralUUIDs
        /// 附带服务id扫描
        let serviceIds = [CBUUID.init(string: v6ServiceId)]
        
        let options = [CBConnectionEventMatchingOption.serviceUUIDs: serviceIds]
        
        BluetoothConnector.shared.startRegist(with: options)
        
        showToast(message: "开始注册")
    }
    
    @objc
    func gotoSettingPage() {
        if let bluetoothSettingsURL = URL(string: "App-prefs:Bluetooth") {
            if UIApplication.shared.canOpenURL(bluetoothSettingsURL) {
                UIApplication.shared.open(bluetoothSettingsURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    @objc
    func setDisconnect() {
        guard let connectPeripheral = connectPeripheral else { return }
        btConnector?.disConnectToPeripheral(peripheral: connectPeripheral)
    }
    
    @objc
    func brandsoundOtaConnect() {
        if let connectPeripheral = connectPeripheral {
            BluetoothConnector.shared.connectToPeripheral(peripheral: connectPeripheral, bluetoothConfig: brandsoundOTAConfig)
            showToast(message: "正在连接...")
        } else {
            if let brandsoundP = peripheralList.filter({matchBrandSoundDevice(deviceName: $0.name ?? "")}).first {
                connectPeripheral = brandsoundP
                BluetoothConnector.shared.connectToPeripheral(peripheral: brandsoundP, bluetoothConfig: brandsoundOTAConfig)
                showToast(message: "正在连接...")
            }
        }
    }
    
    @objc
    func brandsoundOtaDisConnect() {
        guard let connectPeripheral = connectPeripheral else { return }
        BluetoothConnector.shared.disConnectToPeripheral(peripheral: connectPeripheral)
    }
    
    @objc
    func metalanechatDisConnect() {
        guard let metachatConnectPeripheral = metachatConnectPeripheral else { return }
        BluetoothConnector.shared.disConnectToPeripheral(peripheral: metachatConnectPeripheral)
    }
}

extension ViewController: BluetoothConnectorStatusDelegate {
    func connectorBluetoothStatusReturn(status: CBManagerState) {
        switch status {
        case .unknown:
            statusLabel.text = "蓝牙状态未知"
        case .resetting:
            statusLabel.text = "与系统服务的连接，暂时丢失，即将更新"
        case .unsupported:
            statusLabel.text = "不支持低功耗蓝牙"
        case .unauthorized:
            statusLabel.text = "未经授权低功耗蓝牙"
        case .poweredOff:
            statusLabel.text = "低功耗蓝牙关闭"
        case .poweredOn:
            statusLabel.text = "低功耗蓝牙打开，可供使用"
        default:
            break
        }
    }
    
    func connectorScanStatusReturn(status: BluetoothScanStatus) {
        switch status {
        case .unknow:
            statusLabel.text = "未知状态"
        case .scaning:
            statusLabel.text = "扫描中"
        case .stop:
            statusLabel.text = "停止扫描"
        }
    }
    
    func connectorConnectorStatusReturn(status: BluetoothConnectStatus) {
        switch status {
        case .unknow:
            statusLabel.text = "未知状态"
        case .connecting:
            statusLabel.text = "连接中"
        case .connected:
            statusLabel.text = "已连接"
            showToast(message: "连接成功")
        case .disConnect:
            statusLabel.text = "已断开连接"
        case .failure:
            statusLabel.text = "连接失败"
        }
    }
    
    func connectorCharacteristicNotifyReturn(peripheral: CBPeripheral, characteristic: CBCharacteristic, status: BluetoothCharacteristicNotifyStatus) {
        switch status {
        case .success:
            statusLabel.text = "特征值监听成功"
        case .failure:
            statusLabel.text = "特征值监听失败"
        }
    }
}

extension ViewController: BluetoothConnectorDataSourceDelegate {
    func centralManagerDidDiscoverPeripheral(central: CBCentralManager, peripheral: CBPeripheral, advertisementData: [String : Any], RSSI: NSNumber) {
        Logger.d(self, "扫描的结果：外设：\(peripheral), ad：\(advertisementData), rssi: \(RSSI)")
        if let pname = peripheral.name, pname != "", !peripheralList.contains(peripheral) {
            peripheralList.append(peripheral)
            tableView.reloadData()
        }
    }
    
    func centralManagerConnectionEventDidOccur(central: CBCentralManager, event: CBConnectionEvent, peripheral: CBPeripheral) {
        Logger.d(self, "注册的结果：外设：\(peripheral), ad：\(event)")
        if let pname = peripheral.name, pname != "", !peripheralList.contains(peripheral) {
            peripheralList.append(peripheral)
            tableView.reloadData()
        }
    }
    
    func peripheralCharacteristicDidUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        _ = processData(data)
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "customCell", for: indexPath) as! CustomTableViewCell
        cell.customLabel.text = peripheralList[indexPath.row].name
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let peripheral = peripheralList[indexPath.row]
        if matchMetaLaneChatDevice(deviceName: peripheral.name ?? "") {
            metachatConnectPeripheral = peripheral
            BluetoothConnector.shared.connectToPeripheral(peripheral: peripheral, bluetoothConfig: metalanechatConfig)
        }
        if matchBrandSoundDevice(deviceName: peripheral.name ?? "") {
            connectPeripheral = peripheral
            BluetoothConnector.shared.connectToPeripheral(peripheral: peripheral, bluetoothConfig: bluetoothConfig)
        }
        showToast(message: "正在连接...")
    }
}
/// 指令集合
extension ViewController {
    @objc
    func sendMicOpen() {
        guard let connectPeripheral = connectPeripheral else { return }
        let data = BluetoothSendCommand.recordSwitch(isOn: true).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: bluetoothConfig)
    }
    
    @objc
    func sendMicClose() {
        guard let connectPeripheral = connectPeripheral else { return }
        let data = BluetoothSendCommand.recordSwitch(isOn: false).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: bluetoothConfig)
    }
    
    @objc
    func sendBeedClose() {
        guard let connectPeripheral = connectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 0).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: bluetoothConfig)
    }
    
    @objc
    func sendBeedOpen() {
        guard let connectPeripheral = connectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 1).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: bluetoothConfig)
    }
    
    @objc
    func sendBeedWait() {
        guard let connectPeripheral = connectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 2).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: bluetoothConfig)
    }
    
    @objc
    func sendChatBeedClose() {
        guard let metachatConnectPeripheral = metachatConnectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 0).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: metachatConnectPeripheral, config: metalanechatConfig)
    }
    
    @objc
    func sendChatBeedOpen() {
        guard let metachatConnectPeripheral = metachatConnectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 1).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: metachatConnectPeripheral, config: metalanechatConfig)
    }
    
    @objc
    func sendChatBeedWait() {
        guard let metachatConnectPeripheral = metachatConnectPeripheral else { return }
        let data = BluetoothSendCommand.playTone(type: 2).commandData
        BluetoothConnector.shared.sendData(data: data, peripheral: metachatConnectPeripheral, config: metalanechatConfig)
    }
    
    @objc
    func sendBrandsoundOtaMic() {
        if let connectPeripheral = connectPeripheral {
            let data = BluetoothSendCommand.otaDeviceInfo.commandData
            BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: brandsoundOTAConfig)
        } else {
            if let brandsoundP = peripheralList.filter({matchBrandSoundDevice(deviceName: $0.name ?? "")}).first {
                let data = BluetoothSendCommand.otaDeviceInfo.commandData
                BluetoothConnector.shared.sendData(data: data, peripheral: brandsoundP, config: brandsoundOTAConfig)
            }
        }
    }
    
    @objc func zhilingji() {
        let datas: [BluetoothSendCommand] = [.hand, .deviceInfoGet, .allGestureGet, .playTone(type: 0), .playTone(type: 1), .playTone(type: 2), .heart, .recordSwitch(isOn: false), .recordSwitch(isOn: true), .setVoiceHelper(type: 0), .setVoiceHelper(type: 1), .setGlassPair, .otaDeviceInfo]
        
        let alert = UIAlertController(title: "选择指令", message: nil, preferredStyle: .actionSheet)
        for type in datas {
            let option = UIAlertAction(title: type.alertName, style: .default) {[weak self] _ in
                guard let weakself = self else { return }
                if let connectPeripheral = weakself.connectPeripheral {
                    let data = type.commandData
                    BluetoothConnector.shared.sendData(data: data, peripheral: connectPeripheral, config: weakself.bluetoothConfig)
                } else {
                    if let brandsoundP = weakself.peripheralList.filter({matchBrandSoundDevice(deviceName: $0.name ?? "")}).first {
                        let data = type.commandData
                        BluetoothConnector.shared.sendData(data: data, peripheral: brandsoundP, config: weakself.bluetoothConfig)
                    }
                }
            }
            alert.addAction(option)
        }
        let cancle = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancle)
        present(alert, animated: true)
    }
    
    @objc func jumpAudioRecord() {
        let page = AudioRecordPage()
        navigationController?.pushViewController(page, animated: true)
    }
    
    /// 处理收到的指令
    public func processData(_ data: Data) -> Bool {
        guard data.count > 4 else {
            Logger.e(self, "Received data length is less than 5")
            return false
        }
        
        let cmd: [UInt8] = [0xAA, 0xC0]
        
        let bb = ByteBuffer.wrap(data)
        let cmdHead = bb.get()
        let cmdSecond = bb.get()
        
        if cmdHead == cmd[0] && cmdSecond == cmd[1] {
            Logger.d(self, "符合规范")
            if bb.get(index: 6) == STANDARD_BASE_CMD && bb.get(index: 7) == STANDARD_LONG_PRESS_CMD {
                /// 长按
                if bb.get(index: 9) == 0x00 {
                    /// 成功
                    let value = bb.get(index: 10)
                    if value == 0 {
                        sendBeedClose()
                        sendMicClose()
                        Logger.d(self, "调用声音关闭")
                    } else if value == 1 {
                        sendBeedOpen()
                        sendMicOpen()
                        Logger.d(self, "调用声音打开")
                    }
                } else {
                    /// 失败
                }
            }
            
        }
        return false
    }
}

extension ViewController {
    func createButton(title: String, action: Selector) -> UIButton {
        // 创建一个按钮
         let scanButton = UIButton(type: .system)

         // 设置按钮的标题
         scanButton.setTitle(title, for: .normal)

         // 设置按钮的背景颜色
         scanButton.backgroundColor = .blue

         // 设置按钮的标题颜色
         scanButton.setTitleColor(.white, for: .normal)

         // 添加按钮到视图中
         self.view.addSubview(scanButton)

         // 添加按钮点击事件
        scanButton.addTarget(self, action: action, for: .touchUpInside)
        
        return scanButton
    }
    
    func showToast(message: String) {
//        // 创建一个警告弹窗控制器
//        let alert = UIAlertController(title: "提示",
//                                      message: message,
//                                      preferredStyle: .alert)
//        // 添加一个按钮
//        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
//        self.present(alert, animated: true, completion: nil)
        
        
        // 1️⃣ 创建 Toast 样式的视图
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.backgroundColor = .black
        toastLabel.textAlignment = .center
        toastLabel.font = .systemFont(ofSize: 16)
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.layer.masksToBounds = true
        toastLabel.frame = CGRect(x: 50, y: self.view.frame.size.height - 100, width: self.view.frame.size.width - 100, height: 50)
        
        // 2️⃣ 将 Toast 加入视图
        self.view.addSubview(toastLabel)
        
        // 3️⃣ 动画显示弹窗并在2秒后消失
        UIView.animate(withDuration: 0.5, animations: {
            toastLabel.alpha = 1.0
        }) { (completed) in
            // 4️⃣ 在2秒后隐藏 Toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIView.animate(withDuration: 0.5, animations: {
                    toastLabel.alpha = 0.0
                }) { _ in
                    toastLabel.removeFromSuperview()  // 移除视图
                }
            }
        }
    }
    
    
    func matchDevice(deviceName : String) -> Bool {
        let name = deviceName.lowercased()
        if name.hasPrefix("BrandSound".lowercased()) || name.hasPrefix("LAWK City_Air".lowercased()) || name.hasPrefix("Meta Lens Chat".lowercased()) {
            return true
        } else {
            return false
        }
    }
}

class CustomTableViewCell: UITableViewCell {
    let customLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = UIColor.darkGray
        // 设置自定义 Label
        contentView.addSubview(customLabel)
        customLabel.textColor = UIColor.white
        customLabel.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.left.equalTo(10)
            make.right.equalToSuperview().offset(-10)
            make.height.equalTo(20)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
