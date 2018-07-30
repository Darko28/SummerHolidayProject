//
//  DJIMLViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/30.
//  Copyright © 2018 Darko. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import CoreMedia
import VideoToolbox
import DJISDK
import VideoPreviewer


class DJIMLViewController: UIViewController, DJISDKManagerDelegate, DJICameraDelegate, DJIVideoFeedListener, DJIBaseProductDelegate, VideoDataProcessDelegate {
    
    @IBOutlet weak var fpvPreviewerView: UIView!
    
    @IBOutlet weak var videoPreviewer: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var debugImageView: UIImageView!
    
    var videoDataProcessor: VideoFrameExtractor?
    
    
    let yolo = YOLO()
    
    var videoCapture: DJIVideoCapture!
    var request: VNCoreMLRequest!
    var startTimes: [CFTimeInterval] = []
    
    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    
    let ciContext = CIContext()
    var resizedPixelBuffer: CVPixelBuffer?
    
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    
    let semaphore = DispatchSemaphore(value: 2)

    
    func appRegisteredWithError(_ error: Error?) {
        
    }
    
    private func setupVideoPreviewer() {
        
        VideoPreviewer.instance()?.setView(self.fpvPreviewerView)
        
        if let product = DJISDKManager.product() {
            
            if (product.model! == DJIAircraftModelNameA3 || product.model! == DJIAircraftModelNameN3 || product.model! == DJIAircraftModelNameMatrice600 || product.model! == DJIAircraftModelNameMatrice600Pro) {
                DJISDKManager.videoFeeder()?.secondaryVideoFeed.add(self, with: nil)
            } else {
                DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
            }
            
            VideoPreviewer.instance()?.start()
        }
    }
    
    private func resetVideoPreviewer() {
        
        VideoPreviewer.instance()?.unSetView()
        
        if let product = DJISDKManager.product() {
            
            if (product.model! == DJIAircraftModelNameA3 || product.model! == DJIAircraftModelNameN3 || product.model! == DJIAircraftModelNameMatrice600 || product.model! == DJIAircraftModelNameMatrice600Pro) {
                DJISDKManager.videoFeeder()?.secondaryVideoFeed.remove(self)
            } else {
                DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
            }
        }
    }
    
    private func fetchCamera() -> DJICamera? {
        
        guard DJISDKManager.product() != nil else {
            return nil
        }
        
        if DJISDKManager.product()!.isKind(of: DJIAircraft.self) {
            return (DJISDKManager.product()! as! DJIAircraft).camera
        } else if DJISDKManager.product()!.isKind(of: DJIHandheld.self) {
            return (DJISDKManager.product()! as! DJIHandheld).camera
        }
        
        return nil
    }
    
    // MARK: - DJISDKManagerDelegate
    
    func productConnected(_ product: DJIBaseProduct?) {
        
        if let product = product {
            product.delegate = self
            if let camera = self.fetchCamera() {
                camera.delegate = self
                
                camera.setVideoResolutionAndFrameRate(DJICameraVideoResolutionAndFrameRate(resolution: DJICameraVideoResolution.resolution1920x1080, frameRate: DJICameraVideoFrameRate.rate60FPS), withCompletion: nil)
            }
            self.setupVideoPreviewer()
        }
    }
    
    func productDisconnected() {
        
        if let camera = self.fetchCamera(), camera.delegate === self {
            camera.delegate = nil
        }
        self.resetVideoPreviewer()
    }
    
    // MARK: - DJIVideoFeedListener
    
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
        
        var data = videoData.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UInt8 in
            return pointer.pointee
        }
        
        VideoPreviewer.instance()?.push(&data, length: Int32(videoData.count))
        
        
        let frameBuffer = videoDataProcessor?.getCVImage()
        let frameImage = UIImage(pixelBuffer: frameBuffer!.takeRetainedValue())
        print("\(Date())")
    }
    
    
    // MARK: - DJICameraDelegate
    
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        if videoDataProcessor != nil {
            videoDataProcessor!.delegate = self
        }
        
        
        timeLabel.text = ""
        
        setUpBoundingBoxes()
        setUpCoreImage()
        setUpVision()
        setUpCamera()
        
        frameCapturingStartTime = CACurrentMediaTime()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let camera = self.fetchCamera(), camera.delegate === self {
            camera.delegate = nil
        }
        self.resetVideoPreviewer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print(#function)
    }
    
    // MARK: - Initialization
    
    func setUpBoundingBoxes() {
        
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }
        
        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.3, 0.7] {
                for b: CGFloat in [ 0.4, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
    }
    
    func setUpCoreImage() {
        
        let status = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight, kCVPixelFormatType_32BGRA, nil, &resizedPixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: could not create resized pixel buffer", status)
        }
    }
    
    func setUpVision() {
        
        guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
            print("Error: could not create Vision Model")
            return
        }
        
        request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        
        // NOTE: If you choose another crop/scale option, then you must also
        // change how the BoundingBox objects get scaled when they are drawn.
        // Currently they assume the full input image is used.
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func setUpCamera() {
        
        videoCapture = DJIVideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 50
        videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.vga640x480) { success in
            
            if success {
                // Add the video preview into the UI.
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreviewer.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxes {
                    box.addToLayer(self.videoPreviewer.layer)
                }
                
                // Once everything is set up, we can start capturing live video.
                self.videoCapture.start()
            }
        }
    }
    
    // MARK: - UI stuff
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreviewer.bounds
    }
    
    // MARK: - Doing inference
    
    func predict(image: UIImage) {
        if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
            predict(pixelBuffer: pixelBuffer)
        }
    }
    
    func predict(pixelBuffer: CVPixelBuffer) {
        
        // Measure how long it takes to predict a single video frame.
        let startTime = CACurrentMediaTime()
        
        // Resize the input with Core Image to 416x416.
        guard let resizedPixelBuffer = resizedPixelBuffer else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
        let scaledImage = ciImage.transformed(by: scaleTransform)
        ciContext.render(scaledImage, to: resizedPixelBuffer)
        
        // This is an alternative way to resize the image (using vImage)
//        if let resizedPixelBuffer = resizedPixelBuffer(pixelBuffer, width: YOLO.inputWidth, height: YOLO.inputHeight)
        
        // Resize the input to 416x416 and give it to our model.
        if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
            let elapsed = CACurrentMediaTime() - startTime
            showOnMainThread(boundingBoxes, elapsed)
        }
    }
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        
        /*
         Measure how long it takes to predict a single video frame.
         Note that predict() can be called on the next frame while the previous ont
         is still being processed. Hence the need to queue up the start times.
         */
        startTimes.append(CACurrentMediaTime())
        
        // Vision will automatically resize the input image
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
            showOnMainThread(boundingBoxes, elapsed)
        }
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
        
        DispatchQueue.main.async {
            
            // For debugging, to make sure that resized CVPixelBuffer is correct.
//            var debugImage: CGImage?
//            VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
//            self.debugImageView.image = UIImage(cgImage: debugImage!)
            
            self.show(predictions: boundingBoxes)
            
            let fps = self.measureFPS()
            self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
            
            self.semaphore.signal()
        }
    }
    
    func measureFPS() -> Double {
        
        // Measure how many frames were actually delivered per second.
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
            framesDone = 0
            frameCapturingStartTime = CACurrentMediaTime()
        }
        
        return currentFPSDelivered
    }

    func show(predictions: [YOLO.Prediction]) {
        
        for i in 0..<boundingBoxes.count {
            
            if i < predictions.count {
                
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in the coordinate space of the input image,
                 which is a square image of 416x416 pixels. We want to show it on the video preview,
                 which is as wide as the scrrena and has a 4:3 aspect ratio.
                 The video preview also may be letterboxed at the top and bottom.
                 */
                let width = view.bounds.width
                let height = width * 4 / 3
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}


extension DJIMLViewController: DJIVideoCaptureDelegate {
    
    func videoCapture(_ capture: DJIVideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        // For debugging.
//        predict(image: UIImage(named: "dog")!); return
        
        semaphore.wait()
        
        if let pixelBuffer = pixelBuffer {
            
            /*
             For better throughput, perform the prediction on a background queue
             instead of on the VideoCapture queue. We use the semaphore to block
             the capture queue and drop frames when CoreML can't keep up.
             */
            DispatchQueue.global().async {
//                self.predict(pixelBuffer: pixelBuffer)
                self.predictUsingVision(pixelBuffer: pixelBuffer)
            }
        }
    }
}
