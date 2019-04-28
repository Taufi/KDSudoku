//
//  VideoCapture.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 28.04.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import AVFoundation
import UIKit

public protocol VideoCaptureDelegate: class {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CMSampleBuffer)
}

public class VideoCapture: NSObject {
  public var previewLayer: AVCaptureVideoPreviewLayer?
  public weak var delegate: VideoCaptureDelegate?
  
  public var frameInterval = 1
  var seenFrames = 0
  
  let captureSession = AVCaptureSession()
  let videoOutput = AVCaptureVideoDataOutput()
  let queue = DispatchQueue(label: "de.klausdresbach.camera-queue")
  
  var lastTimestamp = CMTime()
  
//  public func setUp(sessionPreset: AVCaptureSession.Preset = .medium, completion: @escaping (Bool)-> Void) {
//    queue.async {
//      let success = self.setUpCamera(sessionPreset: sessionPreset)
//      DispatchQueue.main.async {
//        completion(success)
//      }
//    }
//  }
}
