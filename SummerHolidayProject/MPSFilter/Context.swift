//
//  Context.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/11.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation
import Metal
import CoreVideo

class Context {
    
    // MARK: - Elements
    
    let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue
    let textureCache: CVMetalTextureCache
    
    init() {
        guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to create MTLDevice instance.")
        }
        self.device = device
        
        guard let library: MTLLibrary = device.makeDefaultLibrary() else {
            fatalError("Failed to create MTLLibrary instance.")
        }
        self.library = library
        
        guard let commandQueue: MTLCommandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create MTLCommandQueue instance.")
        }
        self.commandQueue = commandQueue
        
        var textureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) != kCVReturnSuccess {
            fatalError("Failed to create texture cache.")
        }
        guard let _textureCache: CVMetalTextureCache = textureCache else {
            fatalError("Failed to get texture cache.")
        }
        self.textureCache = _textureCache
    }
}
