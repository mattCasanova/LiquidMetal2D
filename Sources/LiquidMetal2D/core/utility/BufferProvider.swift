//
//  BufferProvider.swift
//  LiquidMetal
//
//  Created by Matt Casanova on 2/9/20.
//  Copyright © 2020 Matt Casanova. All rights reserved.
//

import Metal

class BufferProvider{
    private let buffersCount: Int;
    private let semaphore: DispatchSemaphore
    
    private var buffers: [MTLBuffer]
    private var availableIndex = 0;
    
    init(device: MTLDevice, size: Int, buffersCount: Int = 3) {
        self.semaphore    = DispatchSemaphore(value: buffersCount)
        self.buffersCount = buffersCount
        self.buffers      = [MTLBuffer]()
        
        for _ in 0...buffersCount - 1 {
            guard let buffer = device.makeBuffer(length: size, options: []) else  {continue}
            buffers.append(buffer)
        }
    }
    
    func wait() {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    func signal() {
        semaphore.signal()
    }
    
    func nextBuffer() -> MTLBuffer {
        let buffer = buffers[availableIndex]
        availableIndex = (availableIndex + 1) % buffersCount
        return buffer
    }
    
    deinit {
        for _ in 0...buffersCount - 1 {
            semaphore.signal()
        }
    }
}
