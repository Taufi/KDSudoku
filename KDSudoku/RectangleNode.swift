//
//  RectangleNode.swift
//  ARKitRectangleDetection
//
//  Created by Klaus Dresbach on 10.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//
//  Many thanks to Melissa Ludowise: https://github.com/mludowise/ARKitRectangleDetection
//

import UIKit
import SceneKit
import ARKit
import Vision

private let meters2inches = CGFloat(39.3701)

class RectangleNode: SCNNode {
    
    convenience init(_ planeRectangle: PlaneRectangle) {
        self.init(center: planeRectangle.position,
        width: planeRectangle.size.width,
        height: planeRectangle.size.height,
        orientation: planeRectangle.orientation)
    }
    
    init(center position: SCNVector3, width: CGFloat, height: CGFloat, orientation: Float) {
        super.init()
      
        // Create the 3D plane geometry with the dimensions calculated from corners
        //KD 190615 die Sudoku-Überdeckungen waren etwas schmal. Daher hier um 30% vergrößert
        let planeGeometry = SCNPlane(width: width * 1.3, height: height)
        let rectNode = SCNNode(geometry: planeGeometry)

        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        // Set rotation to the corner of the rectangle
        transform = SCNMatrix4Rotate(transform, orientation, 0, 1, 0)
        
        rectNode.transform = transform
        
        // We add the new node to ourself since we inherited from SCNNode
        self.addChildNode(rectNode)
        
        // Set position to the center of rectangle
        self.position = position
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

  
}


