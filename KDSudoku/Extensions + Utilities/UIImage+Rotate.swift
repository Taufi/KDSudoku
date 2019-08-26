//
//  UIImage+Rotate.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 26.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import Foundation
import UIKit

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
