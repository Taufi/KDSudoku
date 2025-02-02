//
//  SCNVector3+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Klaus Dresbach on 10.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//
//  Many thanks to Melissa Ludowise: https://github.com/mludowise/ARKitRectangleDetection
//

import ARKit

extension SCNVector3 {
    func distance(from vector: SCNVector3) -> CGFloat {
        let deltaX = self.x - vector.x
        let deltaY = self.y - vector.y
        let deltaZ = self.z - vector.z
        
        return CGFloat(sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ))
    }
    
    func midpoint(from vector: SCNVector3) -> SCNVector3 {
        let midX = (self.x + vector.x) / 2
        let midY = (self.y + vector.y) / 2
        let midZ = (self.z + vector.z) / 2
        return SCNVector3Make(midX, midY, midZ)
    }
    
    // from Apples demo APP
    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}
