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
  
  var firstTime = true
  
  lazy var classificationRequest: VNCoreMLRequest = {
    do {
      //    let healthySnacks = HealthySnacks()
      //    let multiSnacks = MultiSnacks()
      let model = numbers()
      let visionModel = try VNCoreMLModel(for: model.model)
      let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
//        print("Request beendet", request.results)
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
    resultsLabel.text = "choose or take a photo"
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
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    // Local variable inserted by Swift 4.2 migrator.
    let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
    
    picker.dismiss(animated: true)
    
    let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as! UIImage
    imageView.image = image
    
    classify(image: image)
  }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
  return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
  return input.rawValue
}

