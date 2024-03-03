//
//  ContentView.swift
//  GyroSync Watch App
//
//  Created by Morris on 2023/11/13.
//

import SwiftUI
import CoreMotion
import Foundation
import WatchConnectivity
import CoreLocation


struct ContentView: View {
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var seconds = 0.0
    @State private var isRunning = false
    @State private var isStopped = false
    @State private var gyroscopeData = [GyroscopeData]()
    @State private var currentLocation: CLLocation?
    
    let sessionDelegate = SessionDelegate()
    let motionManager = CMMotionManager()
    let locationManager = CLLocationManager()
    
    var body: some View {
        VStack {
            Text(String(format: "%.1f", seconds))
                .font(.title)
            
            Button(action: {
                guard !self.isRunning else {
                    print("Already running.")
                    return
                }
                
                self.isRunning = true
                self.isStopped = false
                
                if WCSession.isSupported() {
                    let session = WCSession.default
                    if session.isReachable {
                        if session.activationState == .activated {
                            session.sendMessage(["startRecording": true], replyHandler: nil) { (error) in
                                print("Failed to send message: \(error)")
                            }
                        }
                    }
                }
                
                if CLLocationManager.locationServicesEnabled() {
                    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                    locationManager.startUpdatingLocation()
                }
                
                if self.motionManager.isGyroAvailable {
                    self.motionManager.gyroUpdateInterval = 1.0 / 60.0
                    self.motionManager.startGyroUpdates(to: .main) { (data, error) in
                        if let validData = data {
                            if let error = error {
                                print("Failed to update gyro: \(error)")
                            }
                            let gravityAndAttitude = GravityAndAttitude(time: validData.timestamp, gravityX: validData.rotationRate.x, gravityY: validData.rotationRate.y, gyavityZ: validData.rotationRate.z)
                            
                            if self.motionManager.isAccelerometerAvailable {
                                
                                self.motionManager.accelerometerUpdateInterval = 1.0 / 60.0
                                self.motionManager.startAccelerometerUpdates(to: .main) { (data, error) in
                                    if let error = error {
                                        print("Failed to update accelerometer: \(error)")
                                    }
                                    if let validData = data {
                                        let motion = Motion(time: validData.timestamp, accelerationX: validData.acceleration.x, accelerationY: validData.acceleration.y, accelerationZ: validData.acceleration.z)
                                        
                                        if let location = self.currentLocation {
                                            let gps = GPS(time: "\(validData.timestamp)", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                                            
                                            let newGyroData = GyroscopeData(GPS: gps, gravityAndAttitude: gravityAndAttitude, motion: motion)
                                            self.gyroscopeData.append(newGyroData)
                                        }
                                        else {
                                            print("Current Location is not Available")
                                        }
                                    }
                                }
                            }
                            else {
                                print("Accelerometer is not Available")
                            }
                        }
                    }
                }
                else {
                    print("Gyro is not Available")
                }
                
            }) {
                Text("Start")
            }
            
            Button(action: {
//                guard self.isRunning else {
//                    print("Not running.")
////                    return
//                }
                
                if self.isStopped {
                    self.seconds = 0
                    self.isStopped = false
                } else if self.seconds != 0.0 {
                    self.isRunning = false
                    self.isStopped = true
                    self.motionManager.stopGyroUpdates()
                    self.motionManager.stopAccelerometerUpdates()
                    self.locationManager.stopUpdatingLocation()
                    
                    if WCSession.isSupported() {
                        let session = WCSession.default
                        if session.isReachable {
                            session.sendMessage(["stopRecording": true], replyHandler: nil) { (error) in
                                print("Failed to send message: \(error)")
                            }
                        }
                    }
                    
                    self.locationManager.stopUpdatingLocation()
                }
            }) {
                Text(self.isStopped ? "Clear" : "Stop")
            }
            
            Button(action: {
                guard !self.isRunning else {
                    print("Still running.")
                    return
                }
                
                guard !self.gyroscopeData.isEmpty else {
                    print("No data recorded.")
                    return
                }
                
                self.seconds = 0.0
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                
                let gpsFileString = GPS.csvHeader + "\n" + self.gyroscopeData.map { $0.GPS.csvString }.joined(separator: "\n")
                let gpsFileURL = documentsDirectory.appendingPathComponent("GPS.csv")
                do{
                    try gpsFileString.write(to: gpsFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to write GPS file: \(error)")
                }
                
                let gravityAndAttitudeFileString = GravityAndAttitude.csvHeader + "\n" + self.gyroscopeData.map { $0.gravityAndAttitude.csvString }.joined(separator: "\n")
                let gravityAndAttitudeFileURL = documentsDirectory.appendingPathComponent("GravityAndAttitude.csv")
                do{
                    try gravityAndAttitudeFileString.write(to: gravityAndAttitudeFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to write GravityAndAttitude file: \(error)")
                }
                
                let motionFileString = Motion.csvHeader + "\n" + self.gyroscopeData.map { $0.motion.csvString }.joined(separator: "\n")
                let motionFileURL = documentsDirectory.appendingPathComponent("Motion.csv")
                do{
                    try motionFileString.write(to: motionFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to write Motion file: \(error)")
                }
                
                self.gyroscopeData.removeAll()
                
                if WCSession.isSupported() {
                    let session = WCSession.default
                    
                    if session.activationState == .activated && session.isReachable {
                        let gpsFileTransfer = session.transferFile(gpsFileURL, metadata: nil)
                        let gravityAndAttitudeFileTransfer = session.transferFile(gravityAndAttitudeFileURL, metadata: nil)
                        let motionFileTransfer = session.transferFile(motionFileURL, metadata: nil)
                        
                        if gpsFileTransfer.isTransferring || gravityAndAttitudeFileTransfer.isTransferring || motionFileTransfer.isTransferring {
                            print("Files are being transferred.")
                        } else {
                            print("Files are not being transferred.")
                        }
                    } else {
                        print("Session is not activated or reachable.")
                    }
                }
            }) {
                Text("Save")
            }
        }
        .padding()
        .onReceive(timer) { _ in
            if self.isRunning {
                self.seconds += 0.1
            }
        }
        .onAppear() {
            if WCSession.isSupported() {
                let session = WCSession.default
                session.delegate = sessionDelegate
                session.activate()
            }
            self.sessionDelegate.onLocationUpdate = { location in
                self.currentLocation = location
            }
            self.locationManager.delegate = self.sessionDelegate
        }
    }
}


class SessionDelegate: NSObject, WCSessionDelegate, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            onLocationUpdate?(location)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined, .restricted, .denied:
            print("Location services not authorized")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location services authorized")
        @unknown default:
            break
        }
    }
}


#Preview {
    ContentView()
}
