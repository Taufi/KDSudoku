//
//  ViewController.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 18.03.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {

  @IBOutlet var imageView: UIImageView!
  @IBOutlet var cameraButton: UIButton!
  @IBOutlet var photoLibraryButton: UIButton!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!
  
  var sudokuImage: UIImage?
  var firstTime = true
  
  lazy var classificationRequest: VNCoreMLRequest = {
    do {
      let model = numbers()
      let visionModel = try VNCoreMLModel(for: model.model)
      let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
        self?.processObservations(for: request, error: error)
      })
      request.imageCropAndScaleOption = .centerCrop
      return request
    } catch {
      fatalError("Fehler beim Erzeugen des VNCoreMLModel: \(error) ")
    }
  }()

  
  override func viewDidLoad() {
    super.viewDidLoad()
    cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a sudoku photo"
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // Show the "choose or take a photo" hint when the app is opened.
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }
  
  @IBAction func takePicture() {
    presentPhotoPicker(sourceType: .camera)
  }
  
  @IBAction func choosePhoto() {
    presentPhotoPicker(sourceType: .photoLibrary)
  }
  
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
    hideResultsView()
  }
  
  func showResultsView(delay: TimeInterval = 0.1) {
    resultsConstraint.constant = 100
    view.layoutIfNeeded()
    
    UIView.animate(withDuration: 0.5,
                   delay: delay,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.6,
                   options: .beginFromCurrentState,
                   animations: {
                    self.resultsView.alpha = 1
                    self.resultsConstraint.constant = -10
                    self.view.layoutIfNeeded()
    },
                   completion: nil)
  }
  
  func hideResultsView() {
    UIView.animate(withDuration: 0.3) {
      self.resultsView.alpha = 0
    }
  }
  
  func classify(image: UIImage) {
    guard let ciImage = CIImage(image: image) else {
      print("Kann keine CIImage erzeugen")
      return
    }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.classificationRequest])
      } catch {
        print("Fehler in der Klassifikation: \(error)")
      }
    }
  }
  
  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNClassificationObservation] {
        if results.isEmpty {
          self.resultsLabel.text = "nichts gefunden"
          //        } else if results[0].confidence < 0.8 {
          //          print(results[0].confidence)
          //          self.resultsLabel.text = "nicht sicher"
        } else {
          //          let top3 = results.prefix(3).map { observation in
          //            String(format: "%@ %.1f%%", observation.identifier, observation.confidence * 100)
          //          }
          //          let result = results[0].identifier == "healthy" ? "gesund" : "ungesund"
          ////          self.resultsLabel.text = String(format: "%@ %.1f%%", result, results[0].confidence * 100)
          self.resultsLabel.text = String(format: "Zu %.1f%% eine %@", results[0].confidence * 100, results[0].identifier)
//           self.resultsLabel.text = String(format: "%@", results[0].identifier)
          //          self.resultsLabel.text = top3.joined(separator: "\n")
        }
      } else if let error = error {
        self.resultsLabel.text = "Fehler: \(error.localizedDescription)"
      } else {
        self.resultsLabel.text = "???"
      }
      self.showResultsView()
    }
  }
  
  func handleDetectedRectangles(request: VNRequest?, error: Error?) {
    if let nsError = error as NSError? {
      self.presentAlert("Rectangle Detection Error", error: nsError)
      return
    }
    
    guard
      let results = request?.results as? [VNRectangleObservation],
      let rect = results.first,
      let image = self.sudokuImage
      else {
        print("Bäääääää")
        return }
    
    let imageWidth = image.size.width
    let imageHeight = image.size.height
    let originX = rect.topLeft.x * imageWidth
    let originY = (1 - rect.topLeft.y) * imageHeight
    let width = (rect.topRight.x - rect.topLeft.x) * imageWidth
    let height = (rect.topLeft.y - rect.bottomLeft.y) * imageHeight
    
    
    guard let cg = image.cgImage else { return }
    let factor = CGFloat(cg.width) / image.size.width
    let crop = CGRect(x: originX * factor, y: originY * factor, width: width * factor, height: height * factor)
    if let cropImage = cg.cropping(to: crop) {
      
      // Since handlers are executing on a background thread, explicitly draw image on the main thread.
      DispatchQueue.main.async {
        self.imageView.image = nil
        self.imageView.image = UIImage(cgImage: cropImage)
      }
    }
  }
  
  /// - Tag: PreprocessImage
  func scaleAndOrient(image: UIImage) -> UIImage {
    
    // Set a default value for limiting image size.
    let maxResolution: CGFloat = 640
    //    let maxResolution: CGFloat = 1280
    
    guard let cgImage = image.cgImage else {
      print("UIImage has no CGImage backing it!")
      return image
    }
    
    // Compute parameters for transform.
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    var transform = CGAffineTransform.identity
    
    var bounds = CGRect(x: 0, y: 0, width: width, height: height)
    
    if width > maxResolution ||
      height > maxResolution {
      let ratio = width / height
      if width > height {
        bounds.size.width = maxResolution
        bounds.size.height = round(maxResolution / ratio)
      } else {
        bounds.size.width = round(maxResolution * ratio)
        bounds.size.height = maxResolution
      }
    }
    
    let scaleRatio = bounds.size.width / width
    let orientation = image.imageOrientation
    switch orientation {
    case .up:
      transform = .identity
    case .down:
      transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
    case .left:
      let boundsHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundsHeight
      transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
    case .right:
      //          transform = .identity
      let boundsHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundsHeight
      transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
    case .upMirrored:
      transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
    case .downMirrored:
      transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
    case .leftMirrored:
      let boundsHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundsHeight
      transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
    case .rightMirrored:
      let boundsHeight = bounds.size.height
      bounds.size.height = bounds.size.width
      bounds.size.width = boundsHeight
      transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
    @unknown default:
      fatalError("Unknown Value in Image Orientation")
    }
    
    return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
      let context = rendererContext.cgContext
      
      if orientation == .right || orientation == .left {
        context.scaleBy(x: -scaleRatio, y: scaleRatio)
        context.translateBy(x: -height, y: 0)
      } else {
        context.scaleBy(x: scaleRatio, y: -scaleRatio)
        context.translateBy(x: 0, y: -height)
      }
      context.concatenate(transform)
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
  }
  
  func presentAlert(_ title: String, error: NSError) {
    // Always present alert on main thread.
    DispatchQueue.main.async {
      let alertController = UIAlertController(title: title,
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
      let okAction = UIAlertAction(title: "OK",
                                   style: .default) { _ in
                                    // Do nothing -- simply dismiss alert.
      }
      alertController.addAction(okAction)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
    
    sudokuImage = scaleAndOrient(image: originalImage)
    
    //KD 190406 In den folgenden zwei statements könnte ich auch sudokuImage verwenden, da Vison die Koordinaten des entdeckten Rechtecks in relativen Werten (zwischen 0.0 und 1.0) zurückgibt
    let cgOrientation = CGImagePropertyOrientation(originalImage.imageOrientation)
    
    // Fire off request based on URL of chosen photo.
    guard let cgImage = originalImage.cgImage else {
      return
    }
    
    let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
    
    // Customize & configure the request to detect only certain rectangles.
    rectDetectRequest.maximumObservations = 8 // Vision currently supports up to 16.
    rectDetectRequest.minimumConfidence = 0.6 // Be confident.
    rectDetectRequest.minimumAspectRatio = 0.3 // height / width
    
    let requests = [rectDetectRequest]
    
    let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                    orientation: cgOrientation,
                                                    options: [:])
    
    // Send the requests to the request handler.
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try imageRequestHandler.perform(requests)
      } catch let error as NSError {
        print("Failed to perform image request: \(error)")
        self.presentAlert("Image Request Failed", error: error)
        return
      }
    }
    
    dismiss(animated: true, completion: nil)
  }
  
}


