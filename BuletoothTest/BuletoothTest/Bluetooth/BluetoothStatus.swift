//
//  BluetoothStatus.swift
//  BuletoothTest
//
//  Created by 连俊杨 on 2025/7/12.
//

import Foundation

enum BluetoothScanStatus {
    case unknow
    case scaning
    case stop
}

enum BluetoothConnectStatus {
    case unknow
    case connecting
    case connected
    case disConnect
    case failure
}

enum BluetoothCharacteristicNotifyStatus {
    case success
    case failure
}

enum BluetoothSendCommand {
    /// 指令从上到下
    case hand                       //6000
    case deviceInfoGet              //6001
    case allGestureGet              //6002
    case playTone(type: UInt8)      //600C
    case heart                      //600D
    case recordSwitch(isOn: Bool)   //600E 录音开关
    case setVoiceHelper(type: UInt8)//6013 设置语音助手 0-手机自带语音助手，1-客户语音助手
    case setGlassPair               //6014 设置眼镜配对
    
    case otaDeviceInfo              //OTA设备信息
    
    /// 发送的指令
    var commandData: Data {
        switch self {
        case .hand:
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x15, 0x05, 0x00, 0x60, 0x00, 0xFF, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .deviceInfoGet:
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x05, 0x05, 0x00, 0x60, 0x01, 0xFF, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .allGestureGet:
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x05, 0x05, 0x00, 0x60, 0x02, 0xFF, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .playTone(let type):
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x06, 0x05, 0x00, 0x60, 0x0C, 0xFF, type, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .heart:
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x05, 0x05, 0x00, 0x60, 0x0D, 0xFF, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .recordSwitch(let isOn):
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x06, 0x05, 0x00, 0x60, 0x0E, 0xFF, isOn ? 1 : 0, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .setVoiceHelper(let type):
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x06, 0x05, 0x00, 0x60, 0x13, 0xFF, type, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .setGlassPair:
            let bytes: [UInt8] = [0xAA, 0xC0, 0x00, 0x05, 0x05, 0x00, 0x60, 0x14, 0xFF, 0xCC, 0xCC]
            let data = Data(bytes)
            return data
        case .otaDeviceInfo:
            let bytes: [UInt8] = [0xcc, 0xaa, 0x55, 0xee, 0x12, 0x19, 0xe4]
            let data = Data(bytes)
            return data
        }
    }
    
    /// 显示名称
    var alertName: String {
        switch self {
        case .hand:
            return "握手"
        case .deviceInfoGet:
            return "设备信息获取"
        case .allGestureGet:
            return "所有手势获取"
        case .playTone(let type):
            if type == 0 {
                return "播放提示音: 闭麦"
            } else if type == 1 {
                return "播放提示音: 开麦"
            } else if type == 2 {
                return "播放提示音: 等待"
            }
            return "播放提示音"
        case .heart:
            return "心跳"
        case .recordSwitch(let isOn):
            if isOn {
                return "录音开"
            } else {
                return "录音关"
            }
        case .setVoiceHelper(let type):
            if type == 0 {
                return "设置手机自带语音助手"
            } else if type == 1 {
                return "设置客户语音助手"
            }
            return "设置手机自带语音助手"
        case .setGlassPair:
            return "设置眼镜进入配对"
        case .otaDeviceInfo:
            return "ota设备信息"
        }
    }
}

let STANDARD_BASE_CMD: UInt8 = 0x60
let STANDARD_LONG_PRESS_CMD: UInt8 = 0x0b
let STANDARD_RECORD_DATA_CMD: UInt8 = 0x0f
