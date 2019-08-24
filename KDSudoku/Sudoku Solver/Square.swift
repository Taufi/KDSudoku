//
//  Square.swift
//  Sudoku Solver
//
//  Created by Klaus Dresbach on 10.08.19.
//  Many thanks to Bernd Beuster and Peter Norvig: https://github.com/pbing/Sudoku-Solver
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import Foundation

struct Square: CustomStringConvertible {
    var value = UInt16(0)
    
    init(_ value: UInt16 = 0) {
        self.value = value
    }
    
    /* Return description for protocol Printable. */
  //KD 190818 gibt einen String zurück, der die Stellen enthält, an der der Binärwert von Value ein bit hat.
  //          Beispiel: 6 -> 23 (wg 6 enspricht binär 00000110, also ein bit an Stelle 2 und 3
    var description: String {
        if value == 0 {
            return "-"
        } else {
            var str = String()
            for i in 1...9 {
                if (value & (toMask(i)) != 0) {
                    str += String(i)
                }
            }
            return str
        }
    }
    
    /* Return the number of set digits in value. */
    var count: Int {
        var val = value
        var count = 0
        
        while val != 0 {
            val &= val - 1 // clear the least significant bit set
            count += 1
        }
        return count
    }
    
    func toMask(_ digit: Int) -> UInt16 {
        assert(digit >= 1 && digit <= 9, "Index out of range.")
        return UInt16(1 << (digit - 1))
    }
    
    func hasDigit(_ digit: Int) -> Bool {
        return (value & toMask(digit)) != 0
    }
    
    mutating func addDigit(_ digit: Int) {
        value |= toMask(digit)
    }
    
    mutating func removeDigit(_ digit: Int) {
        value &= ~toMask(digit)
    }
    
    var digits: [Int] {
        var res = [Int]()
        for i in 1...9 {
            if hasDigit(i) {
                res.append(i)
            }
        }
        return res
    }
}
