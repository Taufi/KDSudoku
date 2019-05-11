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
import AVFoundation
//import CoreVideo

class ViewController: UIViewController {

  //  @IBOutlet var imageView: UIImageView!
  @IBOutlet var videoPreview: UIView!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsLabel: UILabel!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!
  
  var sudokuImage: UIImage?
  var firstTime = true
  var videoCapture: VideoCapture!
  
  var sudokuArray = Array(repeating: Array(repeating: 0, count: 9), count: 9)
  
  //KD 190502: siehe Erläuterung in AppDelegate
  let queue = DispatchQueue(label: "de.klausdresbach.digit-recognition-queue")
  let group = DispatchGroup()
  
  //KD 190505 zur Visionalisierung des Sudoku-Rechtecks
  var pathLayer: CALayer?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  
    resultsView.alpha = 0
    resultsLabel.text = "choose or take a sudoku photo"
    
    resultsLabel.text = ""
    setUpCamera()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // Show the "choose or take a photo" hint when the app is opened.
    if firstTime {
      showResultsView(delay: 0.5)
      firstTime = false
    }
  }
  
  func setUpCamera() {
    videoCapture = VideoCapture()
    videoCapture.delegate = self
    
    // Change this line to limit how often the video capture delegate gets
    // called. 1 means it is called 30 times per second, which gives realtime
    // results but also uses more battery power.
    videoCapture.frameInterval = 150
    
    videoCapture.setUp(sessionPreset: .high) { success in
      if success {
        // Add the video preview into the UI.
        if let previewLayer = self.videoCapture.previewLayer {
          self.videoPreview.layer.addSublayer(previewLayer)
          self.resizePreviewLayer()
        }
        self.videoCapture.start()
      }
    }
  }
  
  //KD 190503 brauche ich das???
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    resizePreviewLayer()
  }
  
  func resizePreviewLayer() {
    videoCapture.previewLayer?.frame = videoPreview.bounds
  }
  
  func initArray() {
    for i in 0..<9 {
      for j in 0..<9 {
        sudokuArray[i][j] = 0
      }
    }
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
  
  func classify(image: UIImage, completion: @escaping ((Int) -> Void)) {
    guard let ciImage = CIImage(image: image) else {
      print("Kann keine CIImage erzeugen")
      return
    }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    queue.async(group: group) { //KD 190502: siehe Erläuterung in AppDelegate
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        
        let model = numbers()
        let visionModel = try VNCoreMLModel(for: model.model)
        let request = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
          self?.processObservations(for: request, completion: completion, error: error)
        })
        request.imageCropAndScaleOption = .centerCrop
      
        try handler.perform([request])
      } catch {
        print("Fehler in der Klassifikation: \(error)")
      }
    }
  }
  
  func processObservations(for request: VNRequest, completion: @escaping ((Int) -> Void), error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNClassificationObservation] {
        if results.isEmpty {
          self.resultsLabel.text = "nichts gefunden"
        } else {
//          self.resultsLabel.text = String(format: "Zu %.1f%% eine %@", results[0].confidence * 100, results[0].identifier)

          if let resultValue = Int(results[0].identifier) {
            let value = resultValue > 9 ? 0 : resultValue
            completion(value)
          }

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
        DispatchQueue.main.async {
          self.resultsLabel.text = "Bääää"
          self.showResultsView()
          print("Bäääääää")
        }
        return }
    
    let imageWidth = image.size.width
    let imageHeight = image.size.height
    let originX = rect.topLeft.x * imageWidth
    let originY = (1 - rect.topLeft.y) * imageHeight
    let width = (rect.topRight.x - rect.topLeft.x) * imageWidth
    let height = (rect.topLeft.y - rect.bottomLeft.y) * imageHeight
    
    
    guard let cg = image.cgImage else { return }
    
     let factor = CGFloat(cg.width) / image.size.width
    
    let rectCrop = CGRect(x: originX * factor, y: originY * factor, width: width * factor * factor, height: height * factor)
    if let suIm = cg.cropping(to: rectCrop) {
      print("\(suIm.height)")
    }
    
    for i in 0..<9 {
      for j in 0..<9 {
        let summand = i < 4 ? 0 : 1
        let crop = CGRect(x: originX * factor  + ( CGFloat(j) * width / 9.2 ) * factor + 5, y: originY * factor + ( CGFloat(i) * height / 9 ) * factor - CGFloat(summand) * 10  , width: width / 8 * factor, height: height * factor / 8)
        if let cropImage = cg.cropping(to: crop) {
          
          let uiImage = UIImage(cgImage: cropImage)
        
          
          //KD 190430 - das hatte ich vorher auf "DispatchQueue.global(qos: . userInitiated).async"
          // muss aber nicht sein, da dies eine callback-Funktion von VNDetectRectanglesRequest ist
          self.classify(image: uiImage) { (value) in
            self.sudokuArray[i][j] = value
          }
    
          //KD 190430 - das hatte ich vorher auf dem Main Thread (ist Quatsch) -> App hing dann,
          // wenn ich sie auf dem Device laufen ließ. Simulator und Photo Library ging.
          // self.saveImage(image: uiImage, imageName: "number\(i)\(j).png")
        }
      }
    }
    
    group.notify(queue: queue) { //KD 190502: siehe Erläuterung in AppDelegate
      DispatchQueue.main.async {
               print(self.sudokuArray)
        var sudokuPrint = ""
        for i in 0..<9 {
          for j in 0..<9 {
            let printChar = self.sudokuArray[i][j] == 0 ? " _ " : " \(self.sudokuArray[i][j]) "
            sudokuPrint.append("\(printChar)")
          }
          sudokuPrint.append("\n\n")
        }
        
     //   self.textView.text = sudokuPrint
        self.resultsLabel.text = "\(self.sudokuArray[8][0])\(self.sudokuArray[8][1])\(self.sudokuArray[8][2])\(self.sudokuArray[8][3])\(self.sudokuArray[8][4])\(self.sudokuArray[8][5])\(self.sudokuArray[8][6])\(self.sudokuArray[8][7])\(self.sudokuArray[8][8])"
      }
    }
  }

  
  fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
    
    let imageWidth = bounds.width
    let imageHeight = bounds.height
    
    // Begin with input rect.
    var rect = forRegionOfInterest
    
    // Reposition origin.
    rect.origin.x *= imageWidth
    rect.origin.x += bounds.origin.x
    rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
    
    // Rescale normalized coordinates.
    rect.size.width *= imageWidth
    rect.size.height *= imageHeight
    
    return rect
  }
  
  fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
    // Create a new layer.
    let layer = CAShapeLayer()
    
    // Configure layer's appearance.
    layer.fillColor = nil // No fill to show boxed object
    layer.shadowOpacity = 0
    layer.shadowRadius = 0
    layer.borderWidth = 2
    
    // Vary the line color according to input.
    layer.borderColor = color.cgColor
    
    // Locate the layer.
    layer.anchorPoint = .zero
    layer.frame = frame
    layer.masksToBounds = true
    
    // Transform the layer to have same coordinate system as the imageView underneath it.
    layer.transform = CATransform3DMakeScale(1, -1, 1)
    
    return layer
  }
  
  fileprivate func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
    CATransaction.begin()
    for observation in rectangles {
      let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
      let rectLayer = shapeLayer(color: .blue, frame: rectBox)
      
      // Add to pathLayer on top of image.
      pathLayer?.addSublayer(rectLayer)
    }
    CATransaction.commit()
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
  
  func detectRectangles(uiImage: UIImage) {
    initArray()
    
    //KD 190511 hier muss ich keine scaleAndOrient-Methode aufrufen (vgl. App "KDSudoku - stehendes Bild").
    //          Liegt wohl daran, dass ich AVFoundation verwende?
    sudokuImage = uiImage

    //KD 190406 In den folgenden zwei statements könnte ich auch sudokuImage verwenden, da Vison die Koordinaten des entdeckten Rechtecks in relativen Werten (zwischen 0.0 und 1.0) zurückgibt
    let cgOrientation = CGImagePropertyOrientation(uiImage.imageOrientation)
    
    // Fire off request based on URL of chosen photo.
    guard let cgImage = uiImage.cgImage else {
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
  }
  
  func saveImage(image: UIImage, imageName: String){
    
    //create an instance of the FileManager
    let fileManager = FileManager.default
    //get the image path
    let imagePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent(imageName)
    //get the image we took with camera
//    let image = imageView.image!
    //get the PNG data for this image
    let data = image.pngData()
    //store it in the document directory
    fileManager.createFile(atPath: imagePath as String, contents: data, attributes: nil)
  }
  
}

extension ViewController: VideoCaptureDelegate {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame sampleBuffer: CMSampleBuffer) {
    
    func convert(cmage:CIImage) -> UIImage
    {
      let context:CIContext = CIContext.init(options: nil)
      let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
      let image:UIImage = UIImage.init(cgImage: cgImage)
      return image
    }
    
    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      //KD 190503: frei nach https://gist.github.com/johnnyclem/11015360
      let ciImage = CIImage.init(cvImageBuffer: imageBuffer)
      let uiImage : UIImage = convert(cmage: ciImage)
      detectRectangles(uiImage: uiImage)
      print("\(ciImage.debugDescription)")
      print(Date())
    }
//    classify(sampleBuffer: sampleBuffer)
  }
}


