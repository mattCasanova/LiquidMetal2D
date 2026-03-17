//
//  InputReader.swift
//  
//
//  Created by Matt Casanova on 3/6/20.
//

@MainActor
public protocol InputReader: AnyObject {
    func getWorldTouch(forZ z: Float) -> Vec3?
    func getScreenTouch() -> Vec2?
}
