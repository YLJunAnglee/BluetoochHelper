//
//  MFiAccessoryManagerUsageExample.swift
//  MFi 配件管理器使用示例
//

import UIKit
import ExternalAccessory

// MARK: - 使用示例

/// 示例 ViewController，演示如何使用 MFiAccessoryManager
class MFiExampleViewController: UIViewController {

    // MARK: - 属性

    /// MFi 管理器实例
    /// 注意：协议字符串需要替换为你的配件实际协议
    private lazy var mfiManager: MFiAccessoryManager = {
        let manager = MFiAccessoryManager(protocolString: "com.youcompany.iap")
        manager.delegate = self
        manager.autoReconnectEnabled = true      // 启用自动重连
        manager.reconnectInterval = 3.0          // 重连间隔 3 秒
        manager.maxReconnectAttempts = 10        // 最大重连 10 次
        return manager
    }()

    /// 状态标签
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "未连接"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 接收数据文本框
    private let receivedTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    /// 发送数据输入框
    private let sendTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入要发送的数据"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        // 开始监听配件连接
        mfiManager.startMonitoring()
    }

    deinit {
        // 停止监听
        mfiManager.stopMonitoring()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendTextField.resignFirstResponder()
    }
    
    // MARK: - UI 设置

    private func setupUI() {
        view.backgroundColor = .white
        title = "MFi 配件测试"

        // 添加子视图
        view.addSubview(statusLabel)
        view.addSubview(receivedTextView)
        view.addSubview(sendTextField)

        // 创建按钮
        let scanButton = createButton(title: "扫描配件", action: #selector(scanAccessories))
        let connectButton = createButton(title: "连接", action: #selector(connectAccessory))
        let disconnectButton = createButton(title: "断开", action: #selector(disconnectAccessory))
        let sendButton = createButton(title: "发送", action: #selector(sendData))
        let sendHexButton = createButton(title: "发送HEX", action: #selector(sendHexData))
        let bluetoothButton = createButton(title: "蓝牙选择器", action: #selector(showBluetoothPicker))

        let buttonStack = UIStackView(arrangedSubviews: [
            scanButton, connectButton, disconnectButton
        ])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let sendStack = UIStackView(arrangedSubviews: [
            sendButton, sendHexButton, bluetoothButton
        ])
        sendStack.axis = .horizontal
        sendStack.spacing = 10
        sendStack.distribution = .fillEqually
        sendStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(buttonStack)
        view.addSubview(sendStack)

        // 布局约束
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),

            receivedTextView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 20),
            receivedTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            receivedTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            receivedTextView.heightAnchor.constraint(equalToConstant: 200),

            sendTextField.topAnchor.constraint(equalTo: receivedTextView.bottomAnchor, constant: 20),
            sendTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendTextField.heightAnchor.constraint(equalToConstant: 44),

            sendStack.topAnchor.constraint(equalTo: sendTextField.bottomAnchor, constant: 10),
            sendStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendStack.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }

    // MARK: - 按钮事件

    /// 扫描配件
    @objc private func scanAccessories() {
        let accessories = mfiManager.getSupportedAccessories()

        if accessories.isEmpty {
            showAlert(title: "扫描结果", message: "未发现支持的配件")
        } else {
            var message = "发现 \(accessories.count) 个配件:\n\n"
            for (index, accessory) in accessories.enumerated() {
                message += "\(index + 1). \(accessory.name)\n"
                message += "   序列号: \(accessory.serialNumber)\n\n"
            }
            showAlert(title: "扫描结果", message: message)
        }
    }

    /// 连接配件
    @objc private func connectAccessory() {
        let accessories = mfiManager.getSupportedAccessories()

        if accessories.isEmpty {
            showAlert(title: "错误", message: "没有可用的配件")
            return
        }

        if accessories.count == 1 {
            // 只有一个配件，直接连接
            mfiManager.connect(to: accessories[0])
        } else {
            // 多个配件，显示选择列表
            showAccessoryPicker(accessories)
        }
    }

    /// 断开连接
    @objc private func disconnectAccessory() {
        mfiManager.disconnect()
    }

    /// 发送数据
    @objc private func sendData() {
        guard let text = sendTextField.text, !text.isEmpty else {
            showAlert(title: "错误", message: "请输入要发送的数据")
            return
        }

        if mfiManager.send(text) {
            appendLog("发送: \(text)")
            sendTextField.text = ""
        }
    }

    /// 发送十六进制数据
    @objc private func sendHexData() {
        guard let text = sendTextField.text, !text.isEmpty else {
            showAlert(title: "错误", message: "请输入十六进制数据（如: FF 01 02）")
            return
        }

        if mfiManager.sendHex(text) {
            appendLog("发送HEX: \(text)")
            sendTextField.text = ""
        }
    }

    /// 显示蓝牙选择器
    @objc private func showBluetoothPicker() {
        mfiManager.showBluetoothPicker { [weak self] error in
            if let error = error {
                self?.showAlert(title: "错误", message: error.localizedDescription)
            }
        }
    }

    // MARK: - 辅助方法

    /// 显示配件选择器
    private func showAccessoryPicker(_ accessories: [EAAccessory]) {
        let alert = UIAlertController(title: "选择配件", message: nil, preferredStyle: .actionSheet)

        for accessory in accessories {
            let action = UIAlertAction(title: accessory.name, style: .default) { [weak self] _ in
                self?.mfiManager.connect(to: accessory)
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    /// 显示提示框
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    /// 添加日志
    private func appendLog(_ text: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        receivedTextView.text += "[\(timestamp)] \(text)\n"

        // 滚动到底部
        let bottom = NSRange(location: receivedTextView.text.count - 1, length: 1)
        receivedTextView.scrollRangeToVisible(bottom)
    }

    /// 更新状态
    private func updateStatus(_ state: MFiConnectionState) {
        switch state {
        case .disconnected:
            statusLabel.text = "未连接"
            statusLabel.textColor = .red
        case .connecting:
            statusLabel.text = "连接中..."
            statusLabel.textColor = .orange
        case .connected:
            if let accessory = mfiManager.connectedAccessory {
                statusLabel.text = "已连接: \(accessory.name)"
            } else {
                statusLabel.text = "已连接"
            }
            statusLabel.textColor = .green
        case .reconnecting:
            statusLabel.text = "重连中..."
            statusLabel.textColor = .orange
        }
    }
}

// MARK: - MFiAccessoryManagerDelegate

extension MFiExampleViewController: MFiAccessoryManagerDelegate {

    func accessoryManager(_ manager: MFiAccessoryManager, didConnect accessory: EAAccessory) {
        appendLog("配件已连接: \(accessory.name)")
        updateStatus(.connected)
    }

    func accessoryManager(_ manager: MFiAccessoryManager, didDisconnect accessory: EAAccessory) {
        appendLog("配件已断开: \(accessory.name)")
        updateStatus(.disconnected)
    }

    func accessoryManager(_ manager: MFiAccessoryManager, didReceiveData data: Data) {
        // 尝试转换为字符串
        if let string = String(data: data, encoding: .utf8) {
            appendLog("收到: \(string)")
        } else {
            // 显示十六进制
            appendLog("收到HEX: \(data.hexString)")
        }
    }

    func accessoryManager(_ manager: MFiAccessoryManager, didChangeState state: MFiConnectionState) {
        updateStatus(state)
    }

    func accessoryManager(_ manager: MFiAccessoryManager, didEncounterError error: MFiAccessoryError) {
        appendLog("错误: \(error.localizedDescription)")
        showAlert(title: "错误", message: error.localizedDescription)
    }
}
