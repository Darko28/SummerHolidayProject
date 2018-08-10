//
//  ARAMapViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/27.
//  Copyright © 2018 Darko. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision


/*
 AR contains:   1. Tracking (World Tracking - ARAnchor)
 2. Scene Understanding [a. Plane Detection (ARPlaneAnchor) b. Hit Testing (placing object) c. Light Estimation]
 3. Rendering (SCNNode -> ARAnchor)
 */

@available(iOS 11.0, *)
class ARAMapViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var amapVC = AMapViewController()
    
//    var sectionCoordinates: [[(Double, Double)]]? = GPXFile.nuistPathSectionCoordinates
    var sectionCoordinates: [[(Double, Double)]]? = AMapViewController.sharedInstance.maPaths
//    var carLocation: (Double, Double)? = GPXFile.nuistLocation
    var carLocation: (Double, Double)? = AMapViewController.sharedInstance.maDestination
    var worldTrackingFactor: Float = 100000 // experimental factor
    
    private var worldSectionsPositions: [[(Float, Float, Float)]]?  // (0, 0, 0) is the center of coordinates
    private var carCoordinate = SCNVector3Zero
    
    private var overlayView: UIView!
    private var nodeNumber: Int = 1
    private var tappedNode: SCNNode?
    
    private var isNewPlaneDetected: Bool = false
    private var nodeName: String = "New Node"
    private var timer: Timer?
    
    private var tapGesture: UITapGestureRecognizer?
    
    
    // MARK: - ML properties
    
    let yolo = YOLO()
    var mpsYOLO: MPSYOLO!

    var request: VNCoreMLRequest!
    var startTimes: [CFTimeInterval] = []
    
    var boundingBoxes = [BoundingBox]()
    var boundingBox: [YOLO.Prediction]?

    var colors: [UIColor] = []
    
    let ciContext = CIContext()
    var resizedPixelBuffer: CVPixelBuffer?
    
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    
    let semaphore = DispatchSemaphore(value: 2)
    var lastTimestamp = CACurrentMediaTime()
//    var lastTimestamp = CMTime()
    var fps = 30
    static var deltaTime = 0
    
    var isPredicting = false
    var previousBuffer: CVPixelBuffer?
    
    var delegate: DJIFrameCaptureDelegate?
    
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureCache: CVMetalTextureCache?
    
    var useCoreML: Bool = false

    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        sceneView.delegate = self   // ARSCNViewDelegate
        sceneView.session.delegate = self   // ARSessionDelegate
        sceneView.showsStatistics = true
        
        tapGesture = UITapGestureRecognizer()
        tapGesture?.delegate = self
        
        sceneView.addGestureRecognizer(tapGesture!)
        
//        sectionCoordinates = amapVC.maPaths
//        carLocation = amapVC.maDestination
        print("ARSection: \(sectionCoordinates!)")
        mapper()
        
        self.device = MTLCreateSystemDefaultDevice()
        if device == nil {
            print("Error: this device does not support Metal")
            return
        }
        self.commandQueue = device.makeCommandQueue()
        
        mpsYOLO = MPSYOLO(commandQueue: commandQueue)

        
        setUpBoundingBoxes()
        setUpCoreImage()
        setUpVision()
        setUpCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        //        configuration.planeDetection = .horizontal  // Plane Detection
        //        configuration.isLightEstimationEnabled = true   // Light estimation
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sceneView.scene = getScene()    // SceneNodeCreator.sceneSetUp()
//        sceneView.scene = SceneNodeCreator.sceneSetUp()
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false
        addTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        timer?.invalidate()
    }
    
    // MARK: - Dismiss
    
    @IBAction func dismiss(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(location, options: nil)
        if let firstResult = hitTestResults.first {
            handleTouchEvent(node: firstResult.node)
        }
    }
    
    @objc private func handleTouchEvent(node: SCNNode) {
        print("handle touch event")
        addAnimation(node: node)
        addAudioFile(node: node)
        self.tappedNode = node
    }
    
    // Add Core Animation
    private func addAnimation(node: SCNNode) {
        
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.delegate = self
        rotation.fromValue = SCNVector4Make(0, 1, 0, 0)
        rotation.toValue = SCNVector4Make(0, 1, 0, -Float(Double.pi/2)) // clockwise 90 degree around y-axis
        rotation.duration = 5.0
        node.addAnimation(rotation, forKey: "Rotate Me")
        
        let basicAnimation = CABasicAnimation(keyPath: "opacity")
        basicAnimation.duration = 1.0
        basicAnimation.fromValue = 1.0
        basicAnimation.toValue = 0.0
        //        node.addAnimation(basicAnimation, forKey: "Change Visibility")
        
        print("add animation")
    }
    
    // Add audio player
    private func addAudioFile(node: SCNNode) {
        
        print("about to add audio file")
        
        if let path = Bundle.main.path(forResource: "beep", ofType: "wav") {
            if let scnAudioSource = SCNAudioSource(fileNamed: path) {
                
                scnAudioSource.volume = 0.3
                scnAudioSource.isPositional = true
                scnAudioSource.shouldStream = false
                scnAudioSource.load()
                let audioPlayer = SCNAudioPlayer(source: scnAudioSource)
                node.addAudioPlayer(audioPlayer)
                
                audioPlayer.willStartPlayback = { () -> Void in
                    print("willStartPlayback")
                }
                audioPlayer.didFinishPlayback = { () -> Void in
                    print("didFinishPlayback")
                }
            }
        }
    }
}


extension ARAMapViewController: CAAnimationDelegate {
    
    func animationDidStart(_ anim: CAAnimation) {
        
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let node = tappedNode {
            print("Tapped Node: \(node)")
            //            node.geometry?.firstMaterial?.diffuse.contents = UIColor.getRandomColor()
        }
    }
}


// MARK: - Tracking

extension ARAMapViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - ARSessionDelegate
    
    // Tracking - Called when a new plane was detected
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("Plane Detected")
        addPlaneGeometry(for: anchors)
    }
    
    func addPlaneGeometry(for anchors: [ARAnchor]) {
        
    }
    
    // Called when a plane's transform or extent is updated
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updatePlaneGeometry(forAnchors: anchors)
    }
    
    func updatePlaneGeometry(forAnchors: [ARAnchor]) {
        
    }
    
    // When a plane is removed
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        removePlaneGeometry(for: anchors)
    }
    
    func removePlaneGeometry(for anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
//        self.updateARContent()
        
        if let frameBuffer = self.sceneView.session.currentFrame?.capturedImage {
            
//            self.updateARContent()
            
            let timestamp = CACurrentMediaTime()
            let deltaTime = timestamp - lastTimestamp
            lastTimestamp = timestamp
            
            if deltaTime > measureFPS() {

//            let timestamp = CMSampleBufferGetPresentationTimeStamp(frameBuffer as! CMSampleBuffer)
//            let deltaTime = timestamp - lastTimestamp
//            if deltaTime >= CMTimeMake(1, Int32(fps)) {
//                lastTimestamp = timestamp
//                self.predictUsingVision(pixelBuffer: frameBuffer)
//                self.predict(pixelBuffer: frameBuffer)
                let frameTexture = convertToMTLTexture(sampleBuffer: frameBuffer)
                self.predict(texture: frameTexture!)
            }

        }
        
        if !isNewPlaneDetected {
            // doHitTesting(frame: frame)
        }
    }
    
    private func updateARContent() {
 
        self.amapVC.transmitValue()

        if amapVC.maPaths.count > 0 {
            print("actual updateARContent")            
        }
    }
    
    private func addTimer() {
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(self.performAction), userInfo: nil, repeats: true)
        timer?.tolerance = 1.0
    }
    
    @objc private func performAction() {
        if let image = self.sceneView.session.currentFrame?.capturedImage {
            self.detectCapturedImage(image: image)
        }
    }
    
    // MARK: - Detect Captured Image
    
    private func detectCapturedImage(image: CVPixelBuffer) {
        
        if let image = convertImage(input: image) {
            DispatchQueue.main.async { [weak self] in
                let classVal = ImageClassification.classify(image: image)
                self?.title = classVal == .CAR ? "CAR Present" : "Finding CAR"
            }
        }
    }
    
    private func convertImage(input: CVPixelBuffer) -> UIImage? {
        
        let ciImage = CIImage(cvPixelBuffer: input)
        let ciContext = CIContext(options: nil)
        if let videoImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(input), height: CVPixelBufferGetHeight(input))) {
            return UIImage(cgImage: videoImage)
        }
        return nil
    }
    
    //    private func recognizeUsingVision(input: UIImage) {
    //
    //        let coreMLModel = Resnet50()
    //        let model = try? VNCoreMLModel(for: coreMLModel.model)
    //        let request = VNCoreMLRequest(model: model!, completionHandler: myResultsMethod)
    //        if let cgImage = input.cgImage {
    //            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    //            try? handler.perform([request])
    //        }
    //    }
    
    //    private func myResultsMethod(request: VNRequest, error: Error?) {
    //
    //        guard let results = request.results as? [VNClassificationObservation] else { fatalError("Error in Results") }
    //        for classification in results {
    //            if classification.confidence > 0.25 {
    //                title = classification.identifier
    //            }
    //        }
    //    }
    
    // MARK: - Hit Test (Scene Understanding)
    
    func doHitTesting(frame: ARFrame) {
        
        let point = CGPoint(x: 0.5, y: 0.5)
        let results = frame.hitTest(point, types: [ARHitTestResult.ResultType.existingPlane, .estimatedHorizontalPlane])
        if let closestPoint = results.first {
            isNewPlaneDetected = true
            let anchor = ARAnchor(transform: closestPoint.worldTransform)
            sceneView.session.add(anchor: anchor)
        }
    }
    
    // MARK: - ARSCNViewDelegate (Rendering)
    
    // Add
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SceneNodeCreator.getGeometryNode(type: .Cone, position: SCNVector3Make(0, 0, 0), text: "Hello")
        node.name = "\(anchor.identifier)"
        print("New Node is added: Name \(node.name ?? nodeName)")
        return node // SCNNode()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    // Update
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    // Remove
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("Node is removed: Name \(node.name ?? nodeName)")
    }
}


// MARK: - Error Handing (ARSessionObserver)

extension ARAMapViewController {
    
    // While tracking state changes (Not running -> Normal <-> Limited) ARSessionDelegate
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .limited(let reason):
            if reason == .excessiveMotion {
                showAlert(header: "Tracking State Failure", message: "Excessive Motion")
            } else if reason == .insufficientFeatures {
                showAlert(header: "Tracking State Failure", message: "Insufficient Features")
            } else if reason == .initializing {
                showAlert(header: "Tracking State Failure", message: "Initializing")
            } else if reason == .relocalizing {
                showAlert(header: "Tracking State Failure", message: "Relocalizing")
            }
//        case .normal, .notAvailable:
//            break
        case .normal:
            print("updateARContent")
            updateARContent()
        case .notAvailable:
            break
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        showAlert(header: "Session Failure", message: "\(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("sessionWasInterrupted")
        addOverlay()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("sessionInterruptionEnded")
        removeOverlay()
    }
    
    private func addOverlay() {
        overlayView = UIView(frame: sceneView.bounds)
        overlayView.backgroundColor = UIColor.brown
        self.sceneView.addSubview(overlayView)
    }
    
    private func removeOverlay() {
        if let overlayView = overlayView {
            overlayView.removeFromSuperview()
        }
    }
    
    func showAlert(header: String? = "Header", message: String? = "Message") {
        let alertController = UIAlertController(title: header, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (alert) in
            alertController.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}


extension ARAMapViewController {
    
    // MARK: - Scene set up
    
    private func getScene() -> SCNScene {
        
        let scene = SCNScene()
        
        if let worldSectionsPositions = worldSectionsPositions {
            
            var lastPosition = SCNVector3Zero
            
            for eachSection in worldSectionsPositions {
                for eachCoordinate in eachSection {
                    
                    let arrowPosition = SCNVector3Make(eachCoordinate.0, eachCoordinate.1, eachCoordinate.2)
                    scene.rootNode.addChildNode(SceneNodeCreator.drawArrow(position1: lastPosition, position2: arrowPosition))
                    scene.rootNode.addChildNode(SceneNodeCreator.drawPath(position1: lastPosition, position2: arrowPosition))
                    
                    // Add advertisement/banner at the beginning & mid point except at the begining
                    if !samePosition(position1: lastPosition, position2: SCNVector3Zero) && !samePosition(position1: arrowPosition, position2: SCNVector3Zero) {
                        
                        let bannerNodes = SceneNodeCreator.drawBanner(position1: lastPosition, position2: arrowPosition)
                        for node in bannerNodes {
                            scene.rootNode.addChildNode(node)
                        }
                    }
                    
                    nodeNumber = nodeNumber + 1
                    lastPosition = arrowPosition
                }
            }
            
            // Add car location
            if let carLocation = carLocation, let sectionCoordinates = sectionCoordinates, let firstSection = sectionCoordinates.first, firstSection.count > 0 {
                if let referencePoint = firstSection.first {
                    let carRealCoordinate = calculateRealCoordinate(mapCoordinate: carLocation, referencePoint: referencePoint)
                    let position = SCNVector3Make(carRealCoordinate.0, carRealCoordinate.1, carRealCoordinate.2)
                    let node = SceneNodeCreator.createNodeWithImage(image: UIImage(named: "destination")!, position: position, width: 10, height: 10)
                    node.scale = SCNVector3Make(1, 1, 1)
                    scene.rootNode.addChildNode(node)
                }
            }
        }
        
        return scene
    }
    
    private func samePosition(position1: SCNVector3, position2: SCNVector3) -> Bool {
        return position1.x == position2.x && position1.y == position2.y && position1.z == position2.z
    }
    
    private func getDirection(fromPoint: SCNVector3, toPoint: SCNVector3) -> ArrowDirection {   // based on 2 consecutive points
        
        var direction = ArrowDirection.towards
        let xDelta = toPoint.x - fromPoint.x
        let zDelta = toPoint.z - fromPoint.z
        if xDelta != 0 || zDelta != 0 {
            if fabs(xDelta) > fabs(zDelta) {
                direction = xDelta > 0 ? ArrowDirection.right : ArrowDirection.left
            } else {
                direction = zDelta > 0 ? ArrowDirection.backwards : ArrowDirection.towards  // -ve Z axis
            }
        }
        
        return direction
    }
    
    // MARK: - Coordinate Mapper
    
    private func mapper() {
        
        if let sectionCoordinates = sectionCoordinates, let firstSection = sectionCoordinates.first, firstSection.count > 0 {
            let referencePoint = firstSection[0]
            mapToWorldCoordinateMapper(referencePoint: referencePoint, sectionCoordinates: sectionCoordinates)
        }
    }
    
    private func mapToWorldCoordinateMapper(referencePoint: (Double, Double), sectionCoordinates: [[(Double, Double)]]) {
        
        worldSectionsPositions = []
        for eachSection in sectionCoordinates { // Each Edge
            
            var worldTrackSection = [(Float, Float, Float)]()
            for eachCoordinate in eachSection { // Each Point
                
                worldTrackSection.append(calculateRealCoordinate(mapCoordinate: eachCoordinate, referencePoint: referencePoint))
            }
            
            worldSectionsPositions?.append(worldTrackSection)
        }
    }
    
    private func calculateRealCoordinate(mapCoordinate: (Double, Double), referencePoint: (Double, Double)) -> (Float, Float, Float) {
        
        var realCoordinate: (x: Float, y: Float, z: Float) = (Float(), Float(), Float())
        let latDelta = Float(mapCoordinate.0 - referencePoint.0) * worldTrackingFactor
        let lngDelta = Float(mapCoordinate.1 - referencePoint.1) * worldTrackingFactor
        realCoordinate.x = lngDelta // based on longitude
        realCoordinate.y = 0.0  // should be calculated based on altitude
        realCoordinate.z = -1.0 * latDelta  // -ve Z axis
        
        return realCoordinate
    }
}


extension ARAMapViewController {
    
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
        
        if !useCoreML {
            guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess else {
                print("Error: could not create a texture cache")
                return
            }
        }
        
        // Add the bounding box layers to the UI, on top of the video preview.
        for box in self.boundingBoxes {
            //            box.addToLayer(self.videoPreviewer.layer)
            box.addToLayer(self.sceneView.layer)
        }
        
        //        // Once everything is set up, we can start capturing live video.
        //        self.videoCapture.start()
    }

    // MARK: - Doing inference
    
    func predict(texture: MTLTexture) {
        
        mpsYOLO.predict(texture: texture) { result in
            
            DispatchQueue.main.async {
                
                self.show(predictions: result.predictions)
                
                //                if let texture = result.debugTexture {
                //                    self.debugImageView.image = UIImage.image(texture: texture)
                //                }
                
                let fps = self.measureFPS()
                
                self.semaphore.signal()
            }
        }
    }
    
    func predict(image: UIImage) {
        if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
            predict(pixelBuffer: pixelBuffer)
        }
    }
    
    func predict(pixelBuffer: CVPixelBuffer) {
        
        print("Predicting...")
        
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
        //        if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
        //            self.boundingBox = boundingBoxes
        //            print("boundingBox: \(boundingBoxes.count)")
        //            let elapsed = CACurrentMediaTime() - startTime
        //            showOnMainThread(boundingBoxes, elapsed)
        //        }
        if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
            self.boundingBox = boundingBoxes
            print("boundingBox: \(boundingBoxes.count)")
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
        
        print("Predicting using Vision")
        startTimes.append(CACurrentMediaTime())
        
        // Vision will automatically resize the input image
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            print("Computing bounding box")
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            print("visionBoungingBox: \(boundingBoxes.count)")
            self.boundingBox = boundingBoxes
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
        //        frameCapturingStartTime = CACurrentMediaTime()
        
        return frameCapturingElapsed
    }
    
    func show(predictions: [YOLO.Prediction]) {
        
        print("First `show` bounding box")
        
        for i in 0..<boundingBoxes.count {
            
            if i < predictions.count {
                
                print("about to show")
                
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in the coordinate space of the input image,
                 which is a square image of 416x416 pixels. We want to show it on the video preview,
                 which is as wide as the screen and has a 4:3 aspect ratio.
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
                self.isPredicting = false
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
    func show(predictions: [MPSYOLO.Prediction]) {
        
        print("MPSYOLO: First `show` bounding box")
        
        for i in 0..<boundingBoxes.count {
            
            if i < predictions.count {
                
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in the coordinate space of the input image,
                 which is a square image of 416x416 pixels. We want to show it on the video preview,
                 which is as wide as the screen and has a 4:3 aspect ratio.
                 The video preview also may be letterboxed at the top and bottom.
                 */
                let width = view.bounds.width
                let height = width * 4 / 3
                let scaleX = width / CGFloat(MPSYOLO.inputWidth)
                let scaleY = height / CGFloat(MPSYOLO.inputHeight)
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
                self.isPredicting = false
            } else {
                boundingBoxes[i].hide()
            }
        }
    }

    func convertToMTLTexture(sampleBuffer: CVPixelBuffer?) -> MTLTexture? {
        if let textureCache = textureCache,
            let imageBuffer = sampleBuffer {
            
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            
            var texture: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache,
                                                      imageBuffer, nil, .bgra8Unorm, width, height, 0, &texture)
            
            if let texture = texture {
                return CVMetalTextureGetTexture(texture)
            }
        }
        return nil
    }

}
