//
//  DataModels.swift
//  GyroSync
//
//  Created by Morris on 2023/11/13.
//

import Foundation

struct GPS: Codable {
    let time: String
    let latitude: Double
    let longitude: Double
    
    static let csvHeader = "Time,Latitude,Longitude"
    var csvString: String {
        return "\(time),\(latitude),\(longitude)"
    }
}

struct GravityAndAttitude: Codable {
    let time: Double
    let gravityX: Double
    let gravityY: Double
    let gyavityZ: Double
    
    static let csvHeader = "Time,GravityX,GravityY,GyavityZ"
    var csvString: String {
        return "\(time),\(gravityX),\(gravityY),\(gyavityZ)"
    }
}

struct Motion: Codable {
    let time: Double
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    
    static let csvHeader = "Time,AccelerationX,AccelerationY,AccelerationZ"
    var csvString: String {
        return "\(time),\(accelerationX),\(accelerationY),\(accelerationZ)"
    }
}

struct GyroscopeData: Codable {
    let GPS: GPS
    let gravityAndAttitude: GravityAndAttitude
    let motion: Motion
}
