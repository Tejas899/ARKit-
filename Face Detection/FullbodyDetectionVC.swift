//
//  Fullbody detection.swift
//  Face Detection
//
//  Created by Tejas Kashyap on 17/12/23.
//  Copyright © 2023 Tomasz Baranowicz. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Vision

class FullbodyDetectionVC: UIViewController {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var faceLayers: [CAShapeLayer] = []
    let sequenceHandler = VNSequenceRequestHandler()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        DispatchQueue.global().async{
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }
    
    private func setupCamera() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                    
                    setupPreview()
                }
            }
        }
    }
    
    private func setupPreview() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]

        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
    }
}

extension FullbodyDetectionVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let humanBodyRequest = VNDetectHumanBodyPoseRequest(completionHandler:  { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() })

                if let observations = request.results as? [VNHumanBodyPoseObservation] {
                    self.handleFaceDetectionObservations(observations: observations)
                }
            }
        })
        
        
        
//        let humanBodyRequest = VNDetectHumanRectanglesRequest(completionHandler:  { (request: VNRequest, error: Error?) in
//            DispatchQueue.main.async {
//                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() })
//
//                if let observations = request.results as? [VNHumanObservation] {
//                    self.handleFaceDetectionObservations(observations: observations)
//                }
//            }
//        })
//        humanBodyRequest.revision = VNDetectHumanRectanglesRequestRevision2
//        humanBodyRequest.upperBodyOnly = false
        
        
        humanBodyRequest.preferBackgroundProcessing = true

        do {
            try sequenceHandler.perform(
              [humanBodyRequest],
              on: sampleBuffer,
                orientation: .right)
        } catch {
          print(error.localizedDescription)
        }
    }
    
    private func handleFaceDetectionObservations(observations: [VNHumanBodyPoseObservation]) {
        
        let essentialJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .neck,
            .leftShoulder,
            .rightShoulder,
            .leftHip,
            .rightHip,
            .leftAnkle,
            .rightAnkle
        ]

        
        for bodyObservation in observations {
            guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
                print("No recognized points available.")
                return }
            let essentialJointsDetected = essentialJoints.allSatisfy { joint in
                return recognizedPoints[joint]?.confidence ?? 0 > 0.3
            }
            
            if essentialJointsDetected {
                print("OBSERVATION Joint: Full body detected!")
                var minX = CGFloat.greatestFiniteMagnitude
                var minY = CGFloat.greatestFiniteMagnitude
                var maxX: CGFloat = 0
                var maxY: CGFloat = 0
                 
                for joint in essentialJoints {
                    if let point = recognizedPoints[joint], point.confidence > 0 {
                        let position = point.location
                        minX = min(minX, position.x)
                        minY = min(minY, position.y)
                        maxX = max(maxX, position.x)
                        maxY = max(maxY, position.y)
                    }
                }
                
                let boundingBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                
                let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
                let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
                
                let faceLayer = CAShapeLayer()
                faceLayer.path = faceRectanglePath
                faceLayer.fillColor = UIColor.clear.cgColor
                faceLayer.strokeColor =  UIColor.yellow.cgColor
                faceLayer.lineWidth = 5
                
                self.faceLayers.append(faceLayer)
                self.view.layer.addSublayer(faceLayer)

            } else {
                print("OBSERVATION Joint: Partial body detected.")
            }
        }
        
        
        
//        for observation in observations {
//            let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
//            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
//            
//            let faceLayer = CAShapeLayer()
//            faceLayer.path = faceRectanglePath
//            faceLayer.fillColor = UIColor.clear.cgColor
//            faceLayer.strokeColor = observation.upperBodyOnly ?  UIColor.yellow.cgColor : UIColor.red.cgColor
//            faceLayer.lineWidth = 5
//            
//            
//            
//            self.faceLayers.append(faceLayer)
//            self.view.layer.addSublayer(faceLayer)
//            
//            //FACE LANDMARKS
////            if let landmarks = observation.landmarks {
////                if let leftEye = landmarks.leftEye {
////                    self.handleLandmark(leftEye, faceBoundingBox: faceRectConverted)
////                }
////                if let leftEyebrow = landmarks.leftEyebrow {
////                    self.handleLandmark(leftEyebrow, faceBoundingBox: faceRectConverted)
////                }
////                if let rightEye = landmarks.rightEye {
////                    self.handleLandmark(rightEye, faceBoundingBox: faceRectConverted)
////                }
////                if let rightEyebrow = landmarks.rightEyebrow {
////                    self.handleLandmark(rightEyebrow, faceBoundingBox: faceRectConverted)
////                }
////
////                if let nose = landmarks.nose {
////                    self.handleLandmark(nose, faceBoundingBox: faceRectConverted)
////                }
////
////                if let outerLips = landmarks.outerLips {
////                    self.handleLandmark(outerLips, faceBoundingBox: faceRectConverted)
////                }
////                if let innerLips = landmarks.innerLips {
////                    self.handleLandmark(innerLips, faceBoundingBox: faceRectConverted)
////                }
////            }
//        }
    }
    
    private func handleLandmark(_ eye: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect) {
        let landmarkPath = CGMutablePath()
        let landmarkPathPoints = eye.normalizedPoints
            .map({ eyePoint in
                CGPoint(
                    x: eyePoint.y * faceBoundingBox.height + faceBoundingBox.origin.x,
                    y: eyePoint.x * faceBoundingBox.width + faceBoundingBox.origin.y)
            })
        landmarkPath.addLines(between: landmarkPathPoints)
        landmarkPath.closeSubpath()
        let landmarkLayer = CAShapeLayer()
        landmarkLayer.path = landmarkPath
        landmarkLayer.fillColor = UIColor.clear.cgColor
        landmarkLayer.strokeColor = UIColor.green.cgColor

        self.faceLayers.append(landmarkLayer)
        self.view.layer.addSublayer(landmarkLayer)
    }
}
