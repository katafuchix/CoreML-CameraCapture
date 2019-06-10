//
//  ViewController.swift
//  CoreML+CameraCapture
//
//  Created by cano on 2019/06/10.
//  Copyright © 2019 deskplate. All rights reserved.
//

import UIKit
import AVKit
import Vision
import RxSwift
import RxCocoa
import NSObject_Rx
import PinLayout

class ViewController: UIViewController {

    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var resultLabel: UILabel!
    
    var captureSession : AVCaptureSession!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.setUpViews()
        self.setUpCapture()
    }

    // キャプチャ領域の整理
    func setUpViews() {
        self.captureView.pin
            .top(self.view.pin.safeArea.top + 120)
            .left(self.view.pin.safeArea.left + 20)
            .right(self.view.pin.safeArea.right + 20)
            .bottom(self.view.pin.safeArea.bottom + 120)
    }
    
    // カメラでのキャプチャ準備
    func setUpCapture() {
        // ビデオで撮影したものをセッションに出力するように設定
        self.captureSession = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        // 画面に表示
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer.frame = self.captureView.frame
        self.view.layer.addSublayer(previewLayer)
        
        // カメラでのキャプチャ開始 delegateで出力処理を行う
        let captureFrame = AVCaptureVideoDataOutput()
        captureFrame.setSampleBufferDelegate(self, queue: DispatchQueue(label: "captureFrame"))
        self.captureSession.addOutput(captureFrame)
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 出力時の処理
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 出力バッファから画像バッファを取得
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        
        // モデル取得
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else {return}
        
        // 画像処理リクエスト生成
        let request = VNCoreMLRequest(model: model) { [unowned self] (response, err) in
            // 処理結果
            let responseObject = response.results as? [VNClassificationObservation]
            guard let result = responseObject?.first else{ return }
            // 物体の識別と信頼度をRxでラベルに表示
            let resultText = result.identifier + " " + (result.confidence*100).description
            Observable.just(resultText).distinctUntilChanged()
                .map{$0.description}
                .bind(to: self.resultLabel.rx.text)
                .disposed(by: self.rx.disposeBag)
        }
        // ハンドラの生成と実行
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
        try? handler.perform([request])
    }
}
