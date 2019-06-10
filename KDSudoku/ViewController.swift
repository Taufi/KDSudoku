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
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var resultsView: UIView!
  @IBOutlet var resultsTextView: UITextView!
  @IBOutlet var resultsConstraint: NSLayoutConstraint!
  
  var sudokuImage: UIImage?
  var firstTime = true
  var count = 0
  var isReady = false
  
  var sudokuMatrix = Array(repeating: Array(repeating: 0, count: 9), count: 9)
  
  //KD 190502: siehe Erläuterung in AppDelegate
  let queue = DispatchQueue(label: "de.klausdresbach.digit-recognition-queue")
  let group = DispatchGroup()
  
  //KD 190505 zur Visionalisierung des Sudoku-Rechtecks
  var pathLayer: CALayer?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  
    resultsView.alpha = 0
    
    sceneView.delegate = self
    sceneView.showsStatistics = true
    sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let configuration = ARWorldTrackingConfiguration()
    sceneView.session.run(configuration)
    sceneView.session.delegate = self
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    sceneView.session.pause()
  }
  

  func initArray() {
    for i in 0..<9 {
      for j in 0..<9 {
        sudokuMatrix[i][j] = 0
      }
    }
  }
  
  
  @IBAction func screenTapped(_ sender: Any) {
    hideResultsView()
    isReady = false
    count = 0
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
  
  //KD 190610 Extrahiert die Ziffern aus dem Sudoku
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
  
  //KD 190610 Verarbeitet das Ergebnis der gesuchten Ziffer: füllt in "completion" den Lösungsarray
  func processObservations(for request: VNRequest, completion: @escaping ((Int) -> Void), error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNClassificationObservation] {
        if results.isEmpty {
          self.resultsTextView.text = "nichts gefunden"
        } else {
          if let resultValue = Int(results[0].identifier) {
            let value = resultValue > 9 ? 0 : resultValue
            completion(value)
          }

        }
      } else if let error = error {
        self.resultsTextView.text = "Fehler: \(error.localizedDescription)"
      } else {
        self.resultsTextView.text = "???"
      }
    }
  }
  
  //KD 190610 Verarbeitet das gesuchte Rechteck
  func handleDetectedRectangles(request: VNRequest?, error: Error?) {
    if let nsError = error as NSError? {
      self.presentAlert("Rectangle Detection Error", error: nsError)
      return
    }
    
    //KD 190610 stellt fest, ob ein Rechteck gefunden wurde
    guard
      let results = request?.results as? [VNRectangleObservation],
      let rect = results.first,
      let image = self.sudokuImage
      else {
        print("Bäääääää")
        return
    }
    
    DispatchQueue.main.async {
      guard let drawLayer = self.pathLayer else {
          return
      }
      self.draw(rectangle: rect, onImageWithBounds: drawLayer.bounds)
      drawLayer.setNeedsDisplay()
    }
    
    //KD 190602 Die Koordinaten hier beziehen sich auf das Bild
    let imageWidth = image.size.width
    let imageHeight = image.size.height
    let originX = rect.topLeft.x * imageWidth
    let originY = (1 - rect.topLeft.y) * imageHeight
    let width = (rect.topRight.x - rect.topLeft.x) * imageWidth
    let height = (rect.topLeft.y - rect.bottomLeft.y) * imageHeight
    
    
    guard let cg = image.cgImage else { return }
    
    let factor = CGFloat(cg.width) / image.size.width
    
//    let rectCrop = CGRect(x: originX * factor, y: originY * factor, width: width * factor * factor, height: height * factor)
//    if let suIm = cg.cropping(to: rectCrop) {
//      let uiImage:UIImage = UIImage.init(cgImage: suIm)
//      print("(\(uiImage.size.height),\(uiImage.size.width))")
//    }
    
    //KD 190610 zerlegt das Sudoku-Rechteck in die einzelnen Ziffernfelder und versucht die Ziffern zu
    //          entschlüsseln
    for i in 0..<9 {
      for j in 0..<9 {
        let summand = i < 4 ? 0 : 1
        let crop = CGRect(x: originX * factor  + ( CGFloat(j) * width / 9.2 ) * factor + 5, y: originY * factor + ( CGFloat(i) * height / 9 ) * factor - CGFloat(summand) * 10  , width: width / 8 * factor, height: height * factor / 8)
        if let cropImage = cg.cropping(to: crop) {
          
          let uiImage = UIImage(cgImage: cropImage)
        
          
          //KD 190430 - das hatte ich vorher auf "DispatchQueue.global(qos: . userInitiated).async"
          // muss aber nicht sein, da dies eine callback-Funktion von VNDetectRectanglesRequest ist
          //KD 190610 Entschlüsseln der Ziffern
          self.classify(image: uiImage) { (value) in
            self.sudokuMatrix[i][j] = value
          }
    
          //KD 190430 - das hatte ich vorher auf dem Main Thread (ist Quatsch) -> App hing dann,
          // wenn ich sie auf dem Device laufen ließ. Simulator und Photo Library ging.
//           self.saveImage(image: uiImage, imageName: "number\(i)\(j).png")
        }
      }
    }
    
    //KD 190610 Wenn die Extrahierung aller 81 Ziffern abgeschlossen ist (daher die group-queue),
    //          interpretiere ich das Ergebnis
    group.notify(queue: queue) { //KD 190502: siehe Erläuterung in AppDelegate
      DispatchQueue.main.async {
       
        var sudokoArray = [Int]()
        for i in 0..<9 {
          sudokoArray += self.sudokuMatrix[i].filter { $0 > 0}
        }
        
        //KD 190610 Liegt ein vernünftiges Ergebnis vor? Falls weniger als 15 Ziffern, dann nicht.
        if sudokoArray.count > 15 {
          self.isReady = true
          print(self.sudokuMatrix)
          var sudokuPrint = ""
          for i in 0..<9 {
            for j in 0..<9 {
              let printChar = self.sudokuMatrix[i][j] == 0 ? " _ " : " \(self.sudokuMatrix[i][j]) "
              sudokuPrint.append("\(printChar)")
            }
            sudokuPrint.append("\n\n")
          }
          self.resultsTextView.text = sudokuPrint
          self.pathLayer?.removeFromSuperlayer()
          self.pathLayer = nil
//          self.showResultsView()
          self.addSolution(for: rect)
        }
      }
    }
  }
  
  //KD 190610 hier soll nun die Lösung der AR "auf das ungelöste Sudoku gelegt werden"
  //KD 190610 funktioniert noch nicht
  private func addSolution(for observedRect: VNRectangleObservation) {
    
    // Convert to 3D coordinates
    guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView) else {
      print("No plane for this rectangle")
      return
    }
    
    let rectangleNode = RectangleNode(planeRectangle)
    sceneView.scene.rootNode.addChildNode(rectangleNode)
  }
  
//  func addBox(x: Float = 0, y: Float = 0, z: Float = -0.2) {
//    let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
//    let boxNode = SCNNode()
//    boxNode.geometry = box
//    boxNode.position = SCNVector3(x, y, z)
//
//    sceneView.scene.rootNode.addChildNode(boxNode)
//  }


  //KD 190610 gebe das Rect des auf dem Bildschirm sichtbaren Teil des Sudoku-Images zurück
  fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
    
    let imageWidth = bounds.width
    let imageHeight = bounds.height
    
    // Begin with input rect.
    var rect = forRegionOfInterest
    
    // Reposition origin.
    rect.origin.x *= imageWidth
    //KD 190531 Die Koordinaten des Rechtecks beziehen sich auf den Bildausschnitt des SceneView.
    //          Da das Bild aber nicht deckungsgleich mit dem SceneView ist, sondern nach links rausragt
    //          muss ich die Verschiebung noch durchführen:
    rect.origin.x += bounds.origin.x
    rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
    
    // Rescale normalized coordinates.
    rect.size.width *= imageWidth
    rect.size.height *= imageHeight
    
    return rect
  }
  
  //KD 190610 definiere den Layer des blauen Rahmens
  fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
    // Create a new layer.
    let layer = CAShapeLayer()
    
    // Configure layer's appearance.
    layer.fillColor = nil // No fill to show boxed object
    layer.shadowOpacity = 0
    layer.shadowRadius = 0
    layer.borderWidth = 3
    
    // Vary the line color according to input.
    layer.borderColor = color.cgColor
    
    // Locate the layer.
    layer.anchorPoint = .zero
    layer.frame = frame
    layer.masksToBounds = true
    
    // Transform the layer to have same coordinate system as the imageView underneath it.
    //KD 190602 dreht den layer einmal um die x-Achse
    layer.transform = CATransform3DMakeScale(1, -1, 1)
    
    return layer
  }
  
  //KD 190610 Zeichnet das blaue Rechteck un das gefundene Sudoku
  fileprivate func draw(rectangle: VNRectangleObservation, onImageWithBounds bounds: CGRect) {
    CATransaction.begin()
    
    let rectBox = boundingBox(forRegionOfInterest: rectangle.boundingBox, withinImageBounds: bounds)
    let rectLayer = shapeLayer(color: .blue, frame: rectBox)
      
      // Add to pathLayer on top of image.
    pathLayer?.addSublayer(rectLayer)
    
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
  
  //KD 190610 sucht die Rechtecke auf dem übergebendem Foto
  func detectRectangles(uiImage: UIImage) {
    initArray()
    
    //KD 190511 hier muss ich keine scaleAndOrient-Methode aufrufen
    // (vgl. App "KDSudoku - stehendes Bild"). Liegt wohl daran, dass ich das Bild von Hand drehe?
    
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
  
  //KD 190610 Debug-Hilfsfunktion, die Bilder abspeicher t
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

extension ViewController: ARSessionDelegate{
  
  //KD 190610 hier greife ich die Bilder ab
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    if count == 240 && !isReady {
      count = 0
      let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
      let uiImage = convert(cmage: ciImage)
      let rotatedImage = uiImage.rotate(radians: .pi / 2)
      DispatchQueue.main.async {
        self.preparePathLayer(originalImage: rotatedImage  )
      }
      detectRectangles(uiImage: rotatedImage)
    } else {
      count += 1
    }
  }
  
  func convert(cmage:CIImage) -> UIImage
  {
    let context:CIContext = CIContext.init(options: nil)
    let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
    let image:UIImage = UIImage.init(cgImage: cgImage)
    return image
  }

  //KD 190610 bestimmt den Layer, der das Bild "Aspect Fill" darstellt. Heisst, es ragt links und rechts
  //          heraus
  func preparePathLayer(originalImage: UIImage) {
    pathLayer?.removeFromSuperlayer()
    pathLayer = nil

    // Transform image to fit screen.
    guard let cgImage = originalImage.cgImage else {
      print("Trying to show an image not backed by CGImage!")
      return
    }

    let fullImageWidth = CGFloat(cgImage.width)
    let fullImageHeight = CGFloat(cgImage.height)

    let imageFrame = sceneView.frame
    let widthRatio = fullImageWidth / imageFrame.width
    let heightRatio = fullImageHeight / imageFrame.height

    // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
    //KD 190530 der entscheidende Unterschied: iOS stellt das Photo auf dem Bildschirn im Format AspectFILL
    //          dar (vorher stand hier max(widthRatio, heightRatio))
    let scaleDownRatio = min(widthRatio, heightRatio)

    let imageWidth = fullImageWidth / scaleDownRatio
    let imageHeight = fullImageHeight / scaleDownRatio

    // Prepare pathLayer to hold Vision results.
    let xLayer = (imageFrame.width - imageWidth) / 2
    let yLayer = sceneView.frame.minY + (imageFrame.height - imageHeight) / 2
    let drawingLayer = CALayer()
    drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
    drawingLayer.anchorPoint = CGPoint.zero
    drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
    drawingLayer.opacity = 0.5
    pathLayer = drawingLayer
    self.view.layer.addSublayer(pathLayer!)
  }

}

//KD 190525 von hier: https://stackoverflow.com/questions/40882487/how-to-rotate-image-in-swift
//KD 190610 dreht das Bild um 90°, da es in landscape-Format ankommt
extension UIImage {
  func rotate(radians: CGFloat) -> UIImage {
    let rotatedSize = CGRect(origin: .zero, size: size)
      .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
      .integral.size
    UIGraphicsBeginImageContext(rotatedSize)
    if let context = UIGraphicsGetCurrentContext() {
      let origin = CGPoint(x: rotatedSize.width / 2.0,
                           y: rotatedSize.height / 2.0)
      context.translateBy(x: origin.x, y: origin.y)
      context.rotate(by: radians)
      draw(in: CGRect(x: -origin.y, y: -origin.x,
                      width: size.width, height: size.height))
      let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      
      return rotatedImage ?? self
    }
    return self
  }
}
