//
//  CVPixelBuffer+Helpers.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/3.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation
import Accelerate
import CoreImage

/**
 Creates a RGB pixel buffer of the specified width and height.
 */
public func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    if status != kCVReturnSuccess {
        print("Error: Cound not create resized pixel buffer", status)
        return nil
    }
    return pixelBuffer
}

/**
 First crops the pixel buffer, then resizes it.
 */
public func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                              cropX: Int,
                              cropY: Int,
                              cropWidth: Int,
                              cropHeight: Int,
                              scaleWidth: Int,
                              scaleHeight: Int) -> CVPixelBuffer? {
    CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
        print("Error: Cound not get pixel buffer base address")
        return nil
    }
    
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
    let offset = cropY*srcBytesPerRow + cropX*4
    var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset), height: vImagePixelCount(cropHeight), width: vImagePixelCount(cropWidth), rowBytes: srcBytesPerRow)
    let destBytesPerRow = scaleWidth * 4
    guard let destData = malloc(scaleHeight * destBytesPerRow) else {
        print("Error: Out of memory")
        return nil
    }
    var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(scaleHeight), width: vImagePixelCount(scaleWidth), rowBytes: destBytesPerRow)
    
    let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
    CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    if error != kvImageNoError {
        print("Error:", error)
        free(destData)
        return nil
    }
    
    let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
        if let ptr = ptr {
            free(UnsafeMutableRawPointer(mutating: ptr))
        }
    }
    
    let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
    var dstPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreateWithBytes(nil, scaleWidth, scaleHeight, pixelFormat, destData, destBytesPerRow, releaseCallback, nil, nil, &dstPixelBuffer)
    if status != kCVReturnSuccess {
        print("Error: Could not create new pixel buffer")
        free(destData)
        return nil
    }
    
    return dstPixelBuffer
}

/**
 Resizes a CVPixelBuffer to a new width and height.
 */
public func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                              width: Int, height: Int) -> CVPixelBuffer? {
    return resizePixelBuffer(pixelBuffer, cropX: 0, cropY: 0, cropWidth: CVPixelBufferGetWidth(pixelBuffer), cropHeight: CVPixelBufferGetHeight(pixelBuffer), scaleWidth: width, scaleHeight: height)
}

/**
 Resizes a CVPixelBuffer to a new width and height.
 */
public func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                              width: Int, height: Int,
                              output: CVPixelBuffer, context: CIContext) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let sx = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let sy = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
    let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    let scaledImage = ciImage.transformed(by: scaleTransform)
    context.render(scaledImage, to: output)
}
