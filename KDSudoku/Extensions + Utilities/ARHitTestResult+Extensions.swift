//
//  ARHitTestResult+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Klaus Dresbach on 10.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//
//  Many thanks to Melissa Ludowise: https://github.com/mludowise/ARKitRectangleDetection
//

import Foundation
import ARKit

extension ARHitTestResult {
    var worldVector: SCNVector3 {
        get {
            return SCNVector3Make(worldTransform.columns.3.x,
                                  worldTransform.columns.3.y,
                                  worldTransform.columns.3.z)
        }
    }
}

extension Array where Element:ARHitTestResult {
    var closest: ARHitTestResult? {
        get {
            return sorted { (result1, result2) -> Bool in
                return result1.distance < result2.distance
            }.first
        }
    }
    
}
