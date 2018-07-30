//
//  DJIMLViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/30.
//  Copyright © 2018 Darko. All rights reserved.
//

import UIKit
import DJISDK
import VideoPreviewer


class DJIMLViewController: UIViewController, DJISDKManagerDelegate, DJICameraDelegate, DJIVideoFeedListener, DJIBaseProductDelegate, VideoDataProcessDelegate {
    
    @IBOutlet weak var fpvPreviewerView: UIView!
    
    var videoDataProcessor: VideoFrameExtractor?
    
    
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let camera = self.fetchCamera(), camera.delegate === self {
            camera.delegate = nil
        }
        self.resetVideoPreviewer()
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
