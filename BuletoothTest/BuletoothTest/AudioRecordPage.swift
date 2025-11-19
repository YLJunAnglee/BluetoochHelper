//
//  AudioRecordPage.swift
//  BuletoothTest
//
//  Created by xiandao on 2025/11/3.
//

import UIKit
import AVFoundation

class IMMessageBody {
    var content: String = ""
    var duration: Int = 0
}

enum IMError: Int {
    case noError = 0
    case recordTimeTooShort = 1
    case recordTimeOut = 2
}

class AudioRecordPage: UIViewController {
    private var spaceing: CGFloat = 15.0
    private var statusLabel: UILabel?
    private var startCount: Int = 0
    private var timerCount: Int = 0
    
    private var currentCompletion: ((_ error: IMError?, _ messageBody: IMMessageBody) -> Void)?
    private var currentVocieBody = IMMessageBody()
    private var playcompletion: ((_ error: IMError?) -> Void)?
    
    lazy var audioSession: AVAudioSession = {
        let audioSession = AVAudioSession.sharedInstance()
        return audioSession
    }()
    
    lazy var recordTimer: Timer = {
        var timer: Timer!
        if #available(iOS 10.0, *) {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self](timer) in
                self?.audioPowerChange()
            })
        } else {
           timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(audioPowerChange), userInfo: nil, repeats: true)
        }
        
        return timer
    }()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    
    lazy var amplitudeView: StoreIMAmplitudeView = {
        let view = StoreIMAmplitudeView()
        view.amplitudeImageView.image = UIImage(named: "icon_store_im_record1")
        view.isHidden = true
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
        let buttonW = (Screen_width - spaceing * 4) / 3
        let buttonH = 40
        
        let label = UILabel()
        label.text = "状态显示："
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.black
        self.view.addSubview(label)
        statusLabel = label
        label.snp.makeConstraints { make in
            make.top.equalTo(NavigationHeight + spaceing)
            make.left.equalTo(spaceing)
            make.height.equalTo(25)
            make.right.equalToSuperview().offset(-spaceing)
        }
        
        let startRecordBtn = createButton(title: "开始录制", action: #selector(startRecordAction))
        startRecordBtn.snp.makeConstraints { make in
            make.top.equalTo(label.snp_bottomMargin).offset(spaceing)
            make.left.equalTo(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        
        let stopRecordBtn = createButton(title: "停止录制", action: #selector(stopRecordAction))
        stopRecordBtn.snp.makeConstraints { make in
            make.top.equalTo(label.snp_bottomMargin).offset(spaceing)
            make.left.equalTo(startRecordBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        
        let startPlayBtn = createButton(title: "开始播放", action: #selector(startPlayAction))
        startPlayBtn.snp.makeConstraints { make in
            make.top.equalTo(startRecordBtn.snp_bottomMargin).offset(spaceing)
            make.left.equalTo(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        
        let stopPlayBtn = createButton(title: "停止播放", action: #selector(stopPlayAction))
        stopPlayBtn.snp.makeConstraints { make in
            make.top.equalTo(startRecordBtn.snp_bottomMargin).offset(spaceing)
            make.left.equalTo(startPlayBtn.snp_rightMargin).offset(spaceing)
            make.width.equalTo(buttonW)
            make.height.equalTo(buttonH)
        }
        
        view.addSubview(amplitudeView)
        amplitudeView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.height.equalTo(113)
        }
    }
    
    @objc func startRecordAction() {
        statusLabel?.text = "状态显示：正在录制..."
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let currentDateStr = dateFormatter.string(from: Date())
        let md5File = "\(currentDateStr)"
        let fileName = "\(md5String(str: md5File)).wav"
        let body = IMMessageBody()
        body.content = fileName
        
        startVoiceRecording(body) {[weak self] error, messageBody in
            guard let weakSelf = self else {return}
            weakSelf.amplitudeView.isHidden = true
            if error == .noError {
                weakSelf.handleVoiceMsg(messageBody)
            }
        }
    }
    
    @objc func stopRecordAction() {
        statusLabel?.text = "状态显示：录制已结束..."
        
        stopVoiceRecording {[weak self] error, messageBody in
            guard let weakSelf = self else {return}
            weakSelf.amplitudeView.isHidden = true
            if error == .noError {
                weakSelf.handleVoiceMsg(messageBody)
            } else if error == .recordTimeTooShort {
                weakSelf.showToast(message: "录音时间过短")
            }
        }
    }
    
    @objc func startPlayAction() {
        playVoiceMessage(currentVocieBody) { error in
            
        }
    }
    @objc func stopPlayAction() {
        stopPlayingVoiceMessage()
    }
    
    //上传语音消息
    func handleVoiceMsg(_ messageBody: IMMessageBody) {
        print("上传语音消息")
        let urlStr = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]).appendingPathComponent(messageBody.content)
        if FileManager.default.fileExists(atPath: urlStr.path) {
            // 读取音频文件为 Data
            do {
                let audioData = try Data(contentsOf: urlStr)
                print("成功读取音频文件，大小: \(audioData.count) 字节")
                
                // 发送数据到后端
            } catch {
                print("读取音频文件失败: \(error.localizedDescription)")
            }
        }
    }
    
    //录音定时器事件
    @objc func audioPowerChange() {
        if audioRecorder != nil {
            audioRecorder!.updateMeters()//更新测量值
            let power: CGFloat = CGFloat(pow(10, abs((0.05 * audioRecorder!.peakPower(forChannel: 0)))))
            recordingAmplitude(power)
            timerCount += 1
            if timerCount%2 == 0 {
                timerCount = 0
                startCount += 1
                let count = startCount >= 10 ? "0:\(startCount)" : "0:0\(startCount)"
                amplitudeView.recordTimeLabel.text = count
            }
        }
    }
    
    //音量波动
    func recordingAmplitude(_ amplitude: CGFloat) {
        if amplitude < 0.14 {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record1")
        } else if (0.14 <= amplitude) && (amplitude < 0.28) {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record2")
        } else if (0.28 <= amplitude) && (amplitude < 0.42) {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record3")
        } else if (0.42 <= amplitude) && (amplitude < 0.57) {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record4")
        } else if (0.57 <= amplitude) && (amplitude < 0.71) {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record5")
        } else if (0.71 <= amplitude) && (amplitude < 0.85) {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record6")
        } else if 0.85 <= amplitude {
            amplitudeView.amplitudeImageView.image = UIImage(named: "icon_store_im_record7")
        }
    }
}

extension AudioRecordPage {
    //录制语音
    func startVoiceRecording(_ msg: IMMessageBody, completion: @escaping (_ error: IMError?, _ messageBody: IMMessageBody) -> Void) {
        do {
            let category = AVAudioSession.Category.playAndRecord
            let mode = AVAudioSession.Mode.default
            let policy = AVAudioSession.RouteSharingPolicy.default
            let options = AVAudioSession.CategoryOptions.defaultToSpeaker
            if #available(iOS 11.0, *) {
                try audioSession.setCategory(category, mode: mode, policy: policy, options: options)
            } else {
                // Fallback on earlier versions
            }
        } catch {
            print("audioSession 设置失败")
        }
        
        //创建录音文件保存路径
        let url = getSavePath(msg)
        print("音频路径：\(url)")
        //创建录音格式设置
        let setting = getAudioSetting()
        //创建录音机
        let errorR: Error? = nil
        do {
            try audioSession.setActive(true)
            try audioRecorder = AVAudioRecorder(url: url, settings: setting)
        } catch {
            print("初始化失败")
        }
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true //如果要监控声波则必须设置为YES
        
        if errorR != nil {
            print("创建录音机对象时发生错误，错误信息：\(errorR?.localizedDescription ?? "")")
        }
        
        if audioRecorder != nil, !audioRecorder!.isRecording {
            //准备记录录音
            startCount = 0
            audioRecorder!.prepareToRecord()
            audioRecorder!.record(forDuration: 60)
            audioRecorder!.record() //首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
            recordTimer.fireDate = Date.distantPast
        }
        
        currentCompletion = completion
        currentVocieBody = msg
    }
    
    //完成语音录制
    func stopVoiceRecording(_ completion: @escaping (_ error: IMError?, _ messageBody: IMMessageBody) -> Void) {
        audioRecorder?.stop()
        recordTimer.fireDate = Date.distantFuture
        do {
            try audioSession.setActive(false)
            print("stop!!")
        } catch {
        }
        
        currentCompletion = completion
    }
    
    //语音、图片文件保存路径
    func getSavePath(_ messageBody: IMMessageBody) -> URL {
        let urlStr = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]).appendingPathComponent(messageBody.content).path
        let url = URL(fileURLWithPath: urlStr)
        return url
    }
    
    //设置音频参数
    func getAudioSetting() -> [String : Any] {
        //AVFormatIDKey 录音数据格式
        //AVSampleRateKey 采样率
        //AVNumberOfChannelsKey 声道数
        //AVEncoderBitDepthHintKey 位宽
        //AVEncoderAudioQualityKey 录音质量
        return [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVEncoderBitDepthHintKey: 8, AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue]
    }
    
    //获取语音消息时长
    func getAccFileDurtion(_ body: IMMessageBody) -> Int {
        let opts = [AVURLAssetPreferPreciseDurationAndTimingKey : false]
        let localPath = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]).appendingPathComponent(body.content).path
        let urlAsset = AVURLAsset(url: URL(fileURLWithPath: localPath), options: opts) // 初始化视频媒体文件
        var second: Int = 0
        second = Int(urlAsset.duration.value) / Int(urlAsset.duration.timescale) // 获取视频总时长,单位秒
        return second
    }
    
    //语音播放
    func playVoiceMessage(_ body: IMMessageBody, completion: @escaping (_ error: IMError?) -> Void) {
        ///播放判断是否是网络音乐
        let urlStr = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]).appendingPathComponent(body.content).path
        if FileManager.default.fileExists(atPath: urlStr) {
            do {
                let category = AVAudioSession.Category.playback
                let mode = AVAudioSession.Mode.default
                let policy = AVAudioSession.RouteSharingPolicy.default
                let options = AVAudioSession.CategoryOptions.duckOthers
                if #available(iOS 11.0, *) {
                    try audioSession.setCategory(category, mode: mode, policy: policy, options: options)
                } else {
                    // Fallback on earlier versions
                }
            } catch {
                print("audioSession 设置失败")
            }
            //把音频文件转换成url格式
            let url = getSavePath(body)
            audioPlayer =  try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = 0
            //预播放
            if let player = audioPlayer, player.prepareToPlay() {
                audioPlayer?.play()
            }
            playcompletion = completion
        }
    }
    
    //语音结束播放
    func stopPlayingVoiceMessage() {
        audioPlayer?.stop()
    }
}

extension AudioRecordPage: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        currentVocieBody.duration = getAccFileDurtion(currentVocieBody)
        
        if currentVocieBody.duration < 1 {
            currentCompletion?(.recordTimeTooShort, currentVocieBody)
        } else if currentVocieBody.duration >= 60 {
            currentCompletion?(.recordTimeOut, currentVocieBody)
        } else {
            currentCompletion?(.noError, currentVocieBody)
        }
        print("录音完成!")
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        currentCompletion?(.recordTimeOut, currentVocieBody)
        print("录音错误!")
    }
}

extension AudioRecordPage: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playcompletion?(nil)
    }
}

extension AudioRecordPage {
    func md5String(str:String) -> String {
        let cStr = str.cString(using: .utf8)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        CC_MD5(cStr,(CC_LONG)(strlen(cStr!)), buffer)
        var md5String = ""
        for idx in 0 ... 15 {
            let obcStrl = String(format: "%02x", buffer[idx])
            md5String.append(obcStrl)
        }
        free(buffer)
        return md5String
    }
    
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
}

class StoreIMAmplitudeView: UIView {
    var amplitudeImageView: UIImageView!
    var recordInfoLabel: UILabel!
    var recordTimeLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        amplitudeImageView = UIImageView()
        addSubview(amplitudeImageView)
        amplitudeImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        recordInfoLabel = UILabel()
        recordInfoLabel.textAlignment = .center
        recordInfoLabel.textColor = .white
        recordInfoLabel.font = UIFont.systemFont(ofSize: 10)
        addSubview(recordInfoLabel)
        recordInfoLabel.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset(-12)
            make.centerX.equalToSuperview()
        }
        
        recordTimeLabel = UILabel()
        recordTimeLabel.textAlignment = .center
        recordTimeLabel.textColor = .white
        recordTimeLabel.font = UIFont.systemFont(ofSize: 12)
        addSubview(recordTimeLabel)
        recordTimeLabel.snp.makeConstraints { (make) in
            make.bottom.equalTo(recordInfoLabel.snp.top).offset(-2)
            make.centerX.equalToSuperview()
        }
    }
}
