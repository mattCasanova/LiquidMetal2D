//
//  TextureDescriptor.swift
//  LiquidMetal2D
//
//  Created by Matt Casanova on 3/20/26.
//

public struct TextureDescriptor {
    public let name: String
    public let ext: String
    public let isMipmapped: Bool

    public init(name: String, ext: String = "png", isMipmapped: Bool = false) {
        self.name = name
        self.ext = ext
        self.isMipmapped = isMipmapped
    }
}
