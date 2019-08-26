//
//  Array+ShiftRight.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 10.08.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import Foundation

//KD 190807 leicht abgewandelt von hier: https://stackoverflow.com/questions/33264959/shift-elements-in-array-by-index
extension Array {
  func shiftRight(amount: Int = 1) -> [Element] {
    assert(-count...count ~= amount, "Shift amount out of bounds")
    let am = amount < 0 ? amount + count : amount // this needs to be >= 0
    return Array(self[am ..< count] + self[0 ..< am])
  }
  
  mutating func shiftRightInPlace(amount: Int = 1) {
    self = shiftRight(amount: amount)
  }
}
