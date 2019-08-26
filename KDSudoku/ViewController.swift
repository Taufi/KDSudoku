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

  fileprivate struct SudokuDigit {
    var digit: Int
    var wasSet: Bool = false
  }
  
  var sudokuImage: UIImage?
  var detectingRectangles = false
  
  fileprivate var sudokuArray = [SudokuDigit]()
  
  //KD 190502: siehe Erläuterung in AppDelegate
  let queue = DispatchQueue(label: "de.klausdresbach.digit-recognition-queue")
  let group = DispatchGroup()
  
  //KD 190505 zur Visionalisierung des Sudoku-Rechtecks
  var pathLayer: CALayer?
  
  // Used to lookup SurfaceNodes by planeAnchor and update them
  private var surfaceNodes = [ARPlaneAnchor:SurfaceNode]()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    sceneView.delegate = self
    sceneView.showsStatistics = true
    sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = .horizontal
    sceneView.session.run(configuration)
    sceneView.session.delegate = self
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    sceneView.session.pause()
  }
  

  func initArray() {
    let initDigit = SudokuDigit(digit: 0, wasSet: false)
    sudokuArray = Array(repeating: initDigit, count: rows * columns)
  }
  
  
  @IBAction func screenTapped(_ sender: Any) {
    detectingRectangles = false
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
          print("Fehler: nichts gefunden")
        } else {
          if let resultValue = Int(results[0].identifier) {
            let value = resultValue > 9 ? 0 : resultValue
            completion(value)
          }
          // leeres Feld -> hier muss ich nichts machen, da der Sudoku-Array standardmäßig die digit 0 enthält
        }
      } else if let error = error {
        print("Fehler: \(error.localizedDescription)")
      } else {
        print("???")
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
        detectingRectangles = false
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
    
    //KD 190610 zerlegt das Sudoku-Rechteck in die einzelnen Ziffernfelder und versucht die Ziffern zu
    //          entschlüsseln
    for i in 0..<9 {
      for j in 0..<9 {
        let summand = i < 4 ? 0 : 1
        let crop = CGRect(x: originX * factor  + ( CGFloat(j) * width / 9.2 ) * factor + 5, y: originY * factor + ( CGFloat(i) * height / 9 ) * factor - CGFloat(summand) * 30  , width: width / 8 * factor, height: height * factor / 8)
        

        guard let cropImage = cg.cropping(to: crop) else {
          print("----------> crop image error")
          detectingRectangles = false
          return
        }
        
//KD 190826 Debug
//        self.saveImage(image: UIImage(cgImage: cropImage), imageName: "kd_number\(i)\(j).png")
        
        guard let preparedImage = prepareImage(image: UIImage(cgImage: cropImage)) else {
          print("----------> prepared image error")
          detectingRectangles = false
          return
        }
        
        //KD 190430 - das hatte ich vorher auf "DispatchQueue.global(qos: . userInitiated).async"
        // muss aber nicht sein, da dies eine callback-Funktion von VNDetectRectanglesRequest ist
        //KD 190610 Entschlüsseln der Ziffern
        self.classify(image: preparedImage) { (value) in
          self.sudokuArray[i * columns + j].digit = value
          self.sudokuArray[i * columns + j].wasSet = value > 0
        }
  
//KD 190826 Debug
//        self.saveImage(image: preparedImage, imageName: "number\(i)\(j).png")
        
      }
    }
    
    //KD 190610 Wenn die Extrahierung aller 81 Ziffern abgeschlossen ist (daher die group-queue),
    //          interpretiere ich das Ergebnis
    group.notify(queue: queue) { //KD 190502: siehe Erläuterung in AppDelegate
      DispatchQueue.main.async {
       
        var sudokuCheck = [Int]()
        
        sudokuCheck += self.sudokuArray.map { $0.digit } .filter { $0 > 0}
        
        //KD 190611 Oft werden "falsche" Sudokus entdeckt, die aus einer großen Zahl identischer Ziffern
        //          bestehen. Die filtere ich hier raus. Und Sudokus, die weniger als 16 Ziffern haben.
        var solutionCorrect = true
        if sudokuCheck.count < 16 {
        //  print("----------> less than 16 error")
          solutionCorrect = false
        } else {
          for i in 1..<9 {
            if (sudokuCheck.filter{ $0 == i }.count > 9) {
//              print("----------> too much doubles error: \(i)")
//              print(self.sudokuArray)
              solutionCorrect = false
              continue
            }
          }
        }
        
        if solutionCorrect  {
          let grid = self.sudokuArray.map { $0.digit }.reduce ("", { String($0) + String($1) })
          for s in 0..<(rows * columns) {
            units.append(squareUnits(s))
            peers.append(squarePeers(s).allObjects as! [Int])
          }
          let res = solve(grid)
          if res.values.count < 81 {
            self.detectingRectangles = false
            return
          }
          let values = res.values.map { NSString(string: "\($0)") }
          for i in 0..<rows * columns {
            if let valuesEntry = Int(String(values[i])) {
               self.sudokuArray[i].digit = valuesEntry
            }
          }
          self.pathLayer?.removeFromSuperlayer()
          self.pathLayer = nil
          self.addSolution(for: rect)
        } else {
          self.detectingRectangles = false
        }
      }
    }
  }
  
  //KD 190610 hier soll nun die Lösung der AR "auf das ungelöste Sudoku gelegt werden"
  private func addSolution(for observedRect: VNRectangleObservation) {
    
    // Convert to 3D coordinates
    guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView) else {
       print("----------> no plane error")
      print("No plane for this rectangle")
      return
    }
    
    let rectangleNode = RectangleNode(planeRectangle)
    
    if let rectNode = rectangleNode.childNodes.first {
      rectNode.geometry?.firstMaterial?.diffuse.contents = drawSudoku()
    } else {
       print("----------> rect node error")
    }
    sceneView.scene.rootNode.addChildNode(rectangleNode)
    
  }


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
    
    sudokuImage = uiImage
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
  
//KD 190610 Debug-Hilfsfunktion, die Bilder abspeichert
//  func saveImage(image: UIImage, imageName: String){
//    let fileManager = FileManager.default
//    let imagePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent(imageName)
//    let data = image.pngData()
//    fileManager.createFile(atPath: imagePath as String, contents: data, attributes: nil)
//  }
  
  // MARK: - ARSCNViewDelegate
  
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    guard let anchor = anchor as? ARPlaneAnchor else {
      return
    }
    
    let surface = SurfaceNode(anchor: anchor)
    surfaceNodes[anchor] = surface
    node.addChildNode(surface)
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    // See if this is a plane we are currently rendering
    guard let anchor = anchor as? ARPlaneAnchor,
      let surface = surfaceNodes[anchor] else {
        return
    }
    
    surface.update(anchor)
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard let anchor = anchor as? ARPlaneAnchor,
      let surface = surfaceNodes[anchor] else {
        return
    }
    
    surface.removeFromParentNode()
    surfaceNodes.removeValue(forKey: anchor)
  }
  
  func drawSudoku() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 513, height: 513))
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    var attrs: [NSAttributedString.Key: Any] = [
      .font: UIFont(name: "Arial-BoldMT", size: 32)!,
      .paragraphStyle: paragraphStyle,
    ]
    
    
    let img = renderer.image { ctx in
      ctx.cgContext.setFillColor(UIColor.white.cgColor)
      ctx.cgContext.fill(CGRect(x: CGFloat(0), y: CGFloat(0), width: 513, height: 513).insetBy(dx: 3, dy: 3))
      ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
      ctx.cgContext.setLineWidth(6)
      ctx.cgContext.stroke(CGRect(x: CGFloat(0), y: CGFloat(0), width: 513, height: 513).insetBy(dx: 3, dy: 3))
      for row in 0..<9 {
        for col in 0..<9{
          if (row % 3 == 0) && (col % 3 == 0) {
            ctx.cgContext.setLineWidth(6)
            ctx.cgContext.stroke(CGRect(x: CGFloat(row * 57), y: CGFloat(col * 57), width: 171, height: 171))
          }
          ctx.cgContext.setLineWidth(2)
          ctx.cgContext.stroke(CGRect(x: CGFloat(row * 57), y: CGFloat(col * 57), width: 57, height: 57))
        
          let entry = sudokuArray[col * columns + row]
          let string = entry.digit == 0 ? "" : String(entry.digit)
         
          attrs[NSAttributedString.Key.foregroundColor] = entry.wasSet ? UIColor.black : UIColor.red
          
          let attributedString = NSAttributedString(string: string, attributes: attrs)
          attributedString.draw(with: CGRect(x: CGFloat(row * 57), y: CGFloat(col * 57 + 10), width: 57, height: 57), options: .usesLineFragmentOrigin, context: nil)
           ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
        }
      }
    }
    return img
  }
  
}

// MARK: - ARSessionDelegate

extension ViewController: ARSessionDelegate{
  
  //KD 190610 hier greife ich die Bilder ab
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    if !detectingRectangles {
      detectingRectangles = true
      let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
      let uiImage = convert(cmage: ciImage)
      let rotatedImage = uiImage.rotate(radians: .pi / 2)
      DispatchQueue.main.async {
        self.preparePathLayer(originalImage: rotatedImage  )
      }
      detectRectangles(uiImage: rotatedImage)
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


