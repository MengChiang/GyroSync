//
//  ContentView.swift
//  GyroSync
//
//  Created by Morris on 2023/11/13.
//

import SwiftUI
import WatchConnectivity
import AVFoundation

class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

struct CameraPreview: UIViewRepresentable {
    let captureSession: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // No-op
    }
}

struct ContentView: View {
    @StateObject private var sessionDelegate = SessionDelegate()
    let captureSession = AVCaptureSession()
    var body: some View {
        VStack {
            List(sessionDelegate.fileNames, id: \.self) { fileName in
                Text(fileName)
            }
            CameraPreview(captureSession: sessionDelegate.captureSession)
                .frame(height: 300)
                .onAppear {
                    sessionDelegate.startCaptureSession()
                }
        }
        Button(action: {
            if sessionDelegate.isRecording {
                sessionDelegate.stopRecording()
            } else {
                sessionDelegate.startRecordingFromPhone()
            }
        }) {
            Text(sessionDelegate.isRecording ? "Stop Recording" : "Start Recording")
        }
        .padding()
        .onAppear {
            if WCSession.isSupported() {
                let session = WCSession.default
                session.delegate = sessionDelegate
                session.activate()
            }
        }
        .alert(isPresented: $sessionDelegate.showAlert) {
            Alert(title: Text("Message Received"), message: Text("Received a startRecording message."), dismissButton: .default(Text("OK")) {
                sessionDelegate.showAlert = false
            })
        }
    }
}

class SessionDelegate: NSObject, WCSessionDelegate, ObservableObject {
    @Published var fileNames: [String] = ["Default Value"]
    @Published var showAlert: Bool = false
    @Published var isRecording: Bool = false
    
    let captureSession = AVCaptureSession()
    var movieFileOutput: AVCaptureMovieFileOutput?
    var lastReceivedFileURL: URL?
    
    
    func startRecordingFromPhone() {
        self.startRecording()
        
    }
    
    func startRecording() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timeFormat = DateFormatter()
        timeFormat.dateFormat = "yyyyMMddHHmmss"
        let currentDateTime = timeFormat.string(from: Date())
        let videoFileURL = documentsURL.appendingPathComponent("\(currentDateTime).mp4")
        
        movieFileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieFileOutput!) {
            captureSession.addOutput(movieFileOutput!)
            if captureSession.isRunning && movieFileOutput!.connection(with: .video) != nil {
                movieFileOutput!.startRecording(to: videoFileURL, recordingDelegate: self)
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } else {
                print("Capture session is not running or movie file output has no connections")
            }
        }
    }
    
    func stopRecording() {
        movieFileOutput?.stopRecording()
        movieFileOutput = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    
    
    func startCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Failed to get camera device")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                } else {
                    print("Cannot add input to capture session")
                    return
                }
            } catch {
                print("Failed to create AVCaptureDeviceInput: \(error)")
                return
            }
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle session activation completion if needed
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let startRecording = message["startRecording"] as? Bool {
            if startRecording {
                self.startRecording()
                DispatchQueue.main.async {
                    self.showAlert = true
                }
            } else {
                self.stopRecording()
            }
        }
        if let stopRecording = message["stopRecording"] as? Bool {
            if stopRecording {
                self.stopRecording()
            }
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent(file.fileURL.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)
            DispatchQueue.main.async {
                self.fileNames.append(destinationURL.lastPathComponent)
                print("Received a file: \(destinationURL.lastPathComponent)")
                self.objectWillChange.send()
            }
            lastReceivedFileURL = destinationURL
        } catch {
            print("Failed to move file: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive if needed
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Handle session deactivation if needed
        //        session.activate() // You should reactivate the session here
    }
}

extension SessionDelegate: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            print("Failed to record video: \(error)")
        } else {
            print("Video recorded at: \(outputFileURL)")
        }
    }
}

#Preview {
    ContentView()
}
