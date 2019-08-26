//
//  PrepareImage.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 10.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import Foundation
import UIKit

var scaleFactor = 1.0 //KD 190811 TODO als file-Variable: hmmmmm?!?!?!

fileprivate struct PixelData: Equatable {
  var a: UInt8
  var r: UInt8
  var g: UInt8
  var b: UInt8
  
  static func == (lhs: PixelData, rhs: PixelData) -> Bool {
    return lhs.a == rhs.a && lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b
  }
}

func prepareImage(image: UIImage) -> UIImage? {
  let imageWidth = 56.0
  let monoImage = createMonoImage(image: image)
  let resizedImage = resizeSquareImage(image: monoImage, targetSize: imageWidth)
  guard let centeredImage = getCenteredImage(from: resizedImage) else { return nil }
  let scaledImage = resizeSquareImage(image: centeredImage, targetSize: imageWidth * scaleFactor)
   return scaledImage

//KD 190814 das macht die Erkennung seltsamerweise schlechter
//  guard let cg = scaledImage.cgImage else {
//    print("----------> cgImage image error")
//    return nil
//
//  }
//  let offset = imageWidth * (scaleFactor - 1)
//  let width = Double(scaledImage.size.width) - offset*2
//  let crop = CGRect(x: offset, y: offset, width: width, height: width)
//  guard let cropImage = cg.cropping(to: crop) else {
//    print("----------> crop image error")
//    return nil
//  }
//  let reScaledImage = resizeSquareImage(image: UIImage(cgImage: cropImage), targetSize: 28.0)
//  return reScaledImage
//    return UIImage(cgImage: cropImage)
}

func getCenteredImage(from inputImage: UIImage) -> UIImage? {
  
  let ccLabel = CcLabel()
  let labeledData = ccLabel.labelImageFast(image: inputImage, calculateBoundingBoxes: false)
  var matrix = labeledData.labelMatrix
  let matrixSize = matrix.count
  if matrix[0].count != matrixSize {
    print("-----> Error: Matrix not square")
    return nil
  }
  
  let middle = matrixSize / 2
  let labelNr = getLabelNumber(fromCenter: middle, in: matrix)
  
  var binarMatrix = Array(repeating: Array(repeating: 0, count: matrixSize), count: matrixSize)
  
  if labelNr != -1 {
    for i in 0..<matrixSize {
      for j in 0..<matrixSize {
        binarMatrix[i][j] = matrix[i][j] == labelNr ? 1 : 0
      }
    }
  }
  
  let centeredMatrix =  labelNr != -1 ? centerMatrix(matrix: binarMatrix) : binarMatrix
  var pixels = [PixelData]()
  
  let black = PixelData(a: 255, r: 0, g: 0, b: 0)
  let white = PixelData(a: 255, r: 255, g: 255, b: 255)
  
  for i in 0..<matrixSize {
    for j in 0..<matrixSize {
      pixels.append( centeredMatrix[i][j] == 1 ? black : white)
    }
    
  }
  
  let outputImage = imageFromARGB32Bitmap(pixels: pixels, width: matrixSize, height: matrixSize)
  if outputImage == nil {
    print("-------> imageFromARGB32Bitmap error")
  }
  return outputImage  
}

func createMonoImage(image:UIImage) -> UIImage {
  let filter = CIFilter(name: "CIPhotoEffectMono")
  let ciCtx = CIContext(options: nil)
  filter!.setValue(CIImage(image: image), forKey: "inputImage")
  let outputImage = filter!.outputImage
  let cgimg = ciCtx.createCGImage(outputImage!, from: (outputImage?.extent)!)
  return UIImage(cgImage: cgimg!)
}

func resizeSquareImage(image: UIImage, targetSize: Double) -> UIImage{
  let newSize = CGSize(width: targetSize, height: targetSize)
  let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
  // Actually do the resizing to the rect using the ImageContext stuff
  UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
  image.draw(in: rect)
  let newImage = UIGraphicsGetImageFromCurrentImageContext()
  UIGraphicsEndImageContext()
  
  return newImage!
}

func getLabelNumber(fromCenter middle: Int, in matrix: [[Int]]) -> Int {
  let limit = matrix.count / 5
  for i in 0 ..< limit {
    if matrix[middle + i][middle + i] != -1 {
      return matrix[middle + i][middle + i]
    }
    if matrix[middle - i][middle - i] != -1 {
      return matrix[middle - i][middle - i]
    }
    if matrix[middle + i][middle - i] != -1 {
      return matrix[middle + i][middle - i]
    }
    if matrix[middle - i][middle + i] != -1 {
      return matrix[middle - i][middle + i]
    }
  }
  return -1
}

func centerMatrix(matrix: [[Int]]) -> [[Int]] {
  var leftMargin = 0
  var topMargin = 0
  var bottomMargin = 0
  var rightMargin = 0
  
  let matrixSize = matrix.count
  
  for i in 0..<matrixSize{
    for j in 0..<matrixSize {
      if matrix[i][j] == 1 {
        if topMargin == 0 { topMargin = i }
        bottomMargin = matrixSize-1 - i
        if leftMargin == 0 || j < leftMargin {
          leftMargin = j
        }
        if rightMargin == 0 || matrixSize-1 - j < rightMargin {
          rightMargin = matrixSize-1 - j
        }
      }
    }
  }
  
  let verticalShift = Int((Double(topMargin - bottomMargin)/2).rounded())
  let horizontalShift = Int((Double(leftMargin - rightMargin)/2).rounded())
  
  let verticalScale = (topMargin + bottomMargin) / 2
  let horizontalScale = (leftMargin + rightMargin) / 2
  let scale = min(verticalScale, horizontalScale)
  
  scaleFactor = 1.0 + (Double(scale) / Double(matrixSize))
  
  var centeredMatrix = matrix.shiftRight(amount: verticalShift)
  for i in 0..<matrixSize {
    centeredMatrix[i] = centeredMatrix[i].shiftRight(amount: horizontalShift)
  }
  
  return centeredMatrix
}


//KD 190721 von hier: https://stackoverflow.com/questions/30958427/pixel-array-to-uiimage-in-swift
fileprivate func imageFromARGB32Bitmap(pixels: [PixelData], width: Int, height: Int) -> UIImage? {
  guard width > 0 && height > 0 else { return nil }
  guard pixels.count == width * height else { return nil }
  
  let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
  let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
  let bitsPerComponent = 8
  let bitsPerPixel = 32
  
  var data = pixels // Copy to mutable []
  guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
                                                      length: data.count * MemoryLayout<PixelData>.size)
    )
    else { return nil }
  
  guard let cgim = CGImage(
    width: width,
    height: height,
    bitsPerComponent: bitsPerComponent,
    bitsPerPixel: bitsPerPixel,
    bytesPerRow: width * MemoryLayout<PixelData>.size,
    space: rgbColorSpace,
    bitmapInfo: bitmapInfo,
    provider: providerRef,
    decode: nil,
    shouldInterpolate: true,
    intent: .defaultIntent
    )
    else { return nil }
  
  return UIImage(cgImage: cgim)
}
