//
//  ARVC.swift
//  Face Detection
//
//  Created by Tejas Kashyap on 17/12/23.
//  Copyright © 2023 Tomasz Baranowicz. All rights reserved.
//

import Foundation
import UIKit
import SceneKit
import ARKit
import AVFoundation
import Vision

//  Make sure you conform to the ARSCNView Delegate.
class ARBasicObjectViewController:UIViewController, ARSessionDelegate {
    var arView: ARSCNView!
    let visionQueue = DispatchQueue(label: "com.example.ARKitVision")
    let sequenceHandler = VNSequenceRequestHandler()
    private var faceLayers: [CAShapeLayer] = []
    var faceNodes: [SCNNode] = []
    private var imageOrientation: CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .right
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        case .unknown: fallthrough
        case .faceUp: fallthrough
        case .faceDown: fallthrough
        case .landscapeLeft: return .up
        @unknown default:
            return .up
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize ARSCNView
        arView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(arView)
        arView.session.delegate = self

        // Start AR session with body tracking
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Perform Vision request on a background thread
        visionQueue.async {
            self.detectBodies(in: frame)
        }
    }

    func detectBodies(in frame: ARFrame) {
        let request = VNDetectHumanBodyPoseRequest(completionHandler: { (request, error) in
            guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
                return
            }
            DispatchQueue.main.async{
                self.handleFaceDetectionObservations(frame: frame, observations: observations)
            }
                

            // Process body pose observations
            // For simplicity, this example assumes you have a method to convert 2D points to 3D using ARKit's raycasting
            // ...
        })
        try? sequenceHandler.perform([request], on: frame.capturedImage,orientation: imageOrientation)
    }
    
    private func handleFaceDetectionObservations( frame: ARFrame,observations: [VNHumanBodyPoseObservation]) {
        removeall()
        
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
                print("OBSERVATION Joint: No recognized points available.")
                return }
            let essentialJointsDetected = essentialJoints.allSatisfy { joint in
                return recognizedPoints[joint]?.confidence ?? 0 > 0.3
            }
            
            if essentialJointsDetected {
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
                print("OBSERVATION Joint: Full body detected! ",boundingBox)
                let faceRectanglePath = CGPath(rect: transformBoundingBox(boundingBox), transform: nil)
                
                let faceLayer = CAShapeLayer()
                faceLayer.path = faceRectanglePath
                faceLayer.fillColor = UIColor.clear.cgColor
                faceLayer.strokeColor =  UIColor.yellow.cgColor
                faceLayer.lineWidth = 5
                
                self.faceLayers.append(faceLayer)
                self.arView.layer.addSublayer(faceLayer)
                
                
                if let query = arView.raycastQuery(from:  CGPoint(x: transformBoundingBox(boundingBox).midX, y: transformBoundingBox(boundingBox).midY),
                                                      allowing: .estimatedPlane,
                                                      alignment: .any),
                   let result = arView.session.raycast(query).first {
                    let person3DPosition = result.worldTransform.columns.3
                    let cameraPosition = frame.camera.transform.columns.3

                    // Calculate distance
                    let distance = sqrt(
                        pow(cameraPosition.x - person3DPosition.x, 2) +
                        pow(cameraPosition.y - person3DPosition.y, 2) +
                        pow(cameraPosition.z - person3DPosition.z, 2)
                    )

                    print("OBSERVATION Joint: Distance to person: \(distance) meters of  \(observations.firstIndex(of: bodyObservation))")
                }
                
            } else {
                print("OBSERVATION Joint: Partial body detected.")
            }
        }
    }
    
    
    func transformBoundingBox(_ boundingBox: CGRect) -> CGRect {
        var size: CGSize
        var origin: CGPoint
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            size = CGSize(width: boundingBox.width * arView.bounds.height,
                          height: boundingBox.height * arView.bounds.width)
        default:
            size = CGSize(width: boundingBox.width * arView.bounds.width,
                          height: boundingBox.height * arView.bounds.height)
        }
        
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            origin = CGPoint(x: boundingBox.minY * arView.bounds.width,
                             y: boundingBox.minX * arView.bounds.height)
        case .landscapeRight:
            origin = CGPoint(x: (1 - boundingBox.maxY) * arView.bounds.width,
                             y: (1 - boundingBox.maxX) * arView.bounds.height)
        case .portraitUpsideDown:
            origin = CGPoint(x: (1 - boundingBox.maxX) * arView.bounds.width,
                             y: boundingBox.minY * arView.bounds.height)
        default:
            origin = CGPoint(x: boundingBox.minX * arView.bounds.width,
                             y: (1 - boundingBox.maxY) * arView.bounds.height)
        }
        
        return CGRect(origin: origin, size: size)
    }
    
    func removeall(){
        faceLayers.forEach { obj in
            obj.removeFromSuperlayer()
        }
        faceLayers.removeAll()
    }
}
//class ARBasicObjectViewController: UIViewController {
//    
//    //  Declare an ARSCNView
//    var sceneView: ARSCNView!
//    let sequenceHandler = VNSequenceRequestHandler()
//    private let dispatchQueue = DispatchQueue(label: "com.example.ARObjectDetection")
//    private var faceLayers: [CAShapeLayer] = []
//    var faceNodes: [SCNNode] = []
//    private var imageOrientation: CGImagePropertyOrientation {
//        switch UIDevice.current.orientation {
//        case .portrait: return .right
//        case .landscapeRight: return .down
//        case .portraitUpsideDown: return .left
//        case .unknown: fallthrough
//        case .faceUp: fallthrough
//        case .faceDown: fallthrough
//        case .landscapeLeft: return .up
//        @unknown default:
//            return .up
//        }
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        self.sceneView = ARSCNView(frame: self.view.frame)
//        sceneView.delegate = self
//        sceneView.session.delegate = self
//        sceneView.showsStatistics = true
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = .horizontal
//        sceneView.session.run(configuration)
//        //        let configuration1 = ARFaceTrackingConfiguration()
//        //        sceneView.session.run(configuration1)
//        
//        self.view.addSubview(self.sceneView)
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//    }
//    
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        sceneView.session.pause()
//    }
//    
//    private func handleFaceDetectionObservations( frame: ARFrame,observations: [VNHumanObservation]) {
//        removeall()
//        for observation in observations {
//            
//            
//            let faceRectanglePath = CGPath(rect: transformBoundingBox( observation.boundingBox), transform: nil)
//            let faceLayer = CAShapeLayer()
//            faceLayer.path = faceRectanglePath
//            faceLayer.fillColor = UIColor.clear.cgColor
//            faceLayer.strokeColor =  UIColor.yellow.cgColor
//            faceLayer.lineWidth = 5
//            
//            self.faceLayers.append(faceLayer)
//            self.sceneView.layer.addSublayer(faceLayer)
//        }
//    }
//    
//    private func handleFaceDetectionObservations( frame: ARFrame,observations: [VNFaceObservation]) {
//        removeall()
//        for observation in observations {
//            let faceRectanglePath = CGPath(rect: transformBoundingBox( observation.boundingBox), transform: nil)
//            let faceLayer = CAShapeLayer()
//            faceLayer.path = faceRectanglePath
//            faceLayer.fillColor = UIColor.clear.cgColor
//            faceLayer.strokeColor =  UIColor.yellow.cgColor
//            faceLayer.lineWidth = 5
//            
//            self.faceLayers.append(faceLayer)
//            self.sceneView.layer.addSublayer(faceLayer)
//            
//            if let worldCoord = self.normalizeWorldCoord(transformBoundingBox(observation.boundingBox)) {
//                let node = SCNNode.init(withText: "\(String(describing: "TEJAS".randomElement()))", position: worldCoord)
//                faceNodes.append(node)
//                DispatchQueue.main.async {
//                    self.sceneView.scene.rootNode.addChildNode(node)
//                    node.show()
//                }
//            }
//        }
//    }
//    
//    private func handleFaceDetectionObservations( frame: ARFrame,observations: [VNHumanBodyPoseObservation]) {
//        removeall()
//        
//        let essentialJoints: [VNHumanBodyPoseObservation.JointName] = [
//            .nose,
//            .neck,
//            .leftShoulder,
//            .rightShoulder,
//            .leftHip,
//            .rightHip,
//            .leftAnkle,
//            .rightAnkle
//        ]
//        
//        var hasFull =  false
//        for bodyObservation in observations {
//            
//            guard let recognizedPoints = try? bodyObservation.recognizedPoints(.all) else {
//                print("OBSERVATION Joint: No recognized points available.")
//                return }
//            let essentialJointsDetected = essentialJoints.allSatisfy { joint in
//                return recognizedPoints[joint]?.confidence ?? 0 > 0.3
//            }
//            
//            if essentialJointsDetected {
//                var minX = CGFloat.greatestFiniteMagnitude
//                var minY = CGFloat.greatestFiniteMagnitude
//                var maxX: CGFloat = 0
//                var maxY: CGFloat = 0
//                for joint in essentialJoints {
//                    if let point = recognizedPoints[joint], point.confidence > 0 {
//                        let position = point.location
//                        minX = min(minX, position.x)
//                        minY = min(minY, position.y)
//                        maxX = max(maxX, position.x)
//                        maxY = max(maxY, position.y)
//                    }
//                }
//                
//                let boundingBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
//                print("OBSERVATION Joint: Full body detected! ",boundingBox)
//                hasFull = true
//                
//                //                let transform = visionTransform(frame: frame, viewport:  self.view.frame)
//                //                let rect = boundingBox.applying(transform)
//                //                let nrect = CGRect(x: rect.minX, y: rect.minY, width: rect.height * 1.9, height: rect.width * 2)
//                //
//                //                let viewPort = sceneView.frame.size
//                //                let transformScale = CGAffineTransform(scaleX: viewPort.width, y: viewPort.height)
//                //                let nrect1 = CGRect(x: boundingBox.minX, y: boundingBox.minY, width: boundingBox.height * 1.9, height: boundingBox.width * 1.5)
//                //                let newBox = boundingBox.applying(transformScale)
//                
//                //                let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
//                let faceRectanglePath = CGPath(rect: transformBoundingBox(boundingBox), transform: nil)
//                
//                let faceLayer = CAShapeLayer()
//                faceLayer.path = faceRectanglePath
//                faceLayer.fillColor = UIColor.clear.cgColor
//                faceLayer.strokeColor =  UIColor.yellow.cgColor
//                faceLayer.lineWidth = 5
//                
//                self.faceLayers.append(faceLayer)
//                self.sceneView.layer.addSublayer(faceLayer)
//                                self.view.layer.addSublayer(faceLayer)
//                
//                
////                if let worldCoord = self.normalizeWorldCoord(transformBoundingBox(boundingBox)) {
////                    let node = SCNNode.init(withText: "\(String(describing: "TEJAS".randomElement()))", position: worldCoord)
////                    faceNodes.append(node)
////                    DispatchQueue.main.async {
////                        self.sceneView.scene.rootNode.addChildNode(node)
////                        node.show()
////                    }
////                }
//                
//            } else {
//                print("OBSERVATION Joint: Partial body detected.")
//            }
//        }
//        
////        if hasFull{
////            let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request: VNRequest, error: Error?) in
////                DispatchQueue.main.async {
////                    if let observations = request.results as? [VNFaceObservation] {
////                        self.handleFaceDetectionObservations(frame: frame, observations: observations)
////                    }
////                }
////            })
////            faceDetectionRequest.preferBackgroundProcessing = true
////            do {
////                
////                try sequenceHandler.perform([faceDetectionRequest], on: frame.capturedImage,orientation: imageOrientation)
////            } catch {
////                print("ARKIT didUpdate Error = ",error.localizedDescription)
////            }
////        }
//    }
//    func transformBoundingBox(_ boundingBox: CGRect) -> CGRect {
//        var size: CGSize
//        var origin: CGPoint
//        switch UIDevice.current.orientation {
//        case .landscapeLeft, .landscapeRight:
//            size = CGSize(width: boundingBox.width * sceneView.bounds.height,
//                          height: boundingBox.height * sceneView.bounds.width)
//        default:
//            size = CGSize(width: boundingBox.width * sceneView.bounds.width,
//                          height: boundingBox.height * sceneView.bounds.height)
//        }
//        
//        switch UIDevice.current.orientation {
//        case .landscapeLeft:
//            origin = CGPoint(x: boundingBox.minY * sceneView.bounds.width,
//                             y: boundingBox.minX * sceneView.bounds.height)
//        case .landscapeRight:
//            origin = CGPoint(x: (1 - boundingBox.maxY) * sceneView.bounds.width,
//                             y: (1 - boundingBox.maxX) * sceneView.bounds.height)
//        case .portraitUpsideDown:
//            origin = CGPoint(x: (1 - boundingBox.maxX) * sceneView.bounds.width,
//                             y: boundingBox.minY * sceneView.bounds.height)
//        default:
//            origin = CGPoint(x: boundingBox.minX * sceneView.bounds.width,
//                             y: (1 - boundingBox.maxY) * sceneView.bounds.height)
//        }
//        
//        return CGRect(origin: origin, size: size)
//    }
//    
//    func visionTransform(frame: ARFrame, viewport: CGRect) -> CGAffineTransform {
//        var orientation = UIApplication.shared.statusBarOrientation
//        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//            orientation = windowScene.interfaceOrientation
//            // Use `orientation` as needed
//        }
//        
//        let transform = frame.displayTransform(for: orientation,
//                                               viewportSize: viewport.size)
//        let scale = CGAffineTransform(scaleX: viewport.width,
//                                      y: viewport.height)
//        
//        var t = CGAffineTransform()
//        if orientation.isPortrait {
//            t = CGAffineTransform(scaleX: -1, y: 1)
//            t = t.translatedBy(x: -viewport.width, y: 0)
//            
//        } else if orientation.isLandscape {
//            t = CGAffineTransform(scaleX: 1, y: -1)
//            t = t.translatedBy(x: 0, y: -viewport.height)
//        }
//        
//        return transform.concatenating(scale).concatenating(t)
//    }
//    
//    
//    private func determineWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
//        let arHitTestResults = sceneView.hitTest(CGPoint(x: boundingBox.midX, y: boundingBox.midY), types: [.featurePoint])
//        
//        // Filter results that are to close
//        if let closestResult = arHitTestResults.filter({ $0.distance > 0.10 }).first {
//            //            print("vector distance: \(closestResult.distance)")
//            return SCNVector3.positionFromTransform(closestResult.worldTransform)
//        }
//        return nil
//    }
//    
//    private func normalizeWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
//        
//        var array: [SCNVector3] = []
//        Array(0...2).forEach{_ in
//            if let position = determineWorldCoord(boundingBox) {
//                array.append(position)
//            }
//            usleep(12000) // .012 seconds
//        }
//        
//        if array.isEmpty {
//            return nil
//        }
//        
//        return SCNVector3.center(array)
//    }
//}

//extension ARBasicObjectViewController: ARSCNViewDelegate,ARSessionDelegate {
//    
//    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
//            return
//        }
//        print("ARKIT faceAnchor = ",faceAnchor)
//    }
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        // Perform Vision requests on each frame
//        print("ARKIT didUpdate = ",frame)
//        removeall()
////        let humanBodyRequest = VNDetectHumanBodyPoseRequest(completionHandler:  { (request: VNRequest, error: Error?) in
////            DispatchQueue.main.async {
////                if let observations = request.results as? [VNHumanBodyPoseObservation] {
////                    self.handleFaceDetectionObservations(frame: frame, observations: observations)
////                }
////            }
////        })
//        
//        let humanBodyRequest = VNDetectHumanRectanglesRequest(completionHandler: { (request: VNRequest, error: Error?) in
//            DispatchQueue.main.async {
//                if let observations = request.results as? [VNHumanObservation] {
//                    self.handleFaceDetectionObservations(frame: frame, observations: observations)
//                }
//            }
//        })
//        humanBodyRequest.preferBackgroundProcessing = true
//        
//        do {
//            
//            try sequenceHandler.perform([humanBodyRequest], on: frame.capturedImage,orientation: imageOrientation)
//        } catch {
//            print("ARKIT didUpdate Error = ",error.localizedDescription)
//        }
//        
//        
//    }
//    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
//        print("ARKIT didChange = ",geoTrackingStatus)
//    }
//    
//    func sessionWasInterrupted(_ session: ARSession) {
//        print("ARKIT sessionWasInterrupted = ")
//    }
//    func sessionInterruptionEnded(_ session: ARSession) {
//        print("ARKIT sessionInterruptionEnded = ")
//    }
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        print("ARKIT didFailWithError = ",error)
//    }
//    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
//        return true
//        
//    }
//    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
//        print("ARKIT didOutputCollaborationData = ",data)
//    }
//    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
//        print("ARKIT didOutputAudioSampleBuffer = ",audioSampleBuffer)
//    }
//    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
//        print("ARKIT cameraDidChangeTrackingState = ",camera)
//    }
//    
//    // Add your method to convert observation data to AR content
//    // func addARObject(at position: CGRect) { ... }
//    func removeall(){
//        faceLayers.forEach { obj in
//            obj.removeFromSuperlayer()
//        }
//        faceLayers.removeAll()
//        
//        faceNodes.forEach { node in
//            node.hide()
//            node.removeFromParentNode()
//        }
//        self.sceneView.scene.removeAllParticleSystems()
//        faceNodes.removeAll()
//    }
//}



extension matrix_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension SIMD3 where Scalar == Float {
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
}
