//
//  utilities.swift
//  Sudoku Solver
//
//  Created by Klaus Dresbach on 10.08.19.
//  Many thanks to Bernd Beuster and Peter Norvig: https://github.com/pbing/Sudoku-Solver
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//

import Foundation
import CoreServices

/* A unit are the columns 1-9, the rows A-I and
a collection of nine squares. */
func squareUnits(_ s: Int) -> [[Int]] {
    
    /* same row */
    var row = s / columns
    var rowUnits = [Int](repeating: 0, count: columns)
    var i = 0
    for column in 0..<columns {
        rowUnits[i] = row * columns + column
        i += 1
    }
    
    /* same column */
    var column = s % rows
    var columnUnits = [Int](repeating: 0, count: rows)
    i = 0
    for row in 0..<rows {
        columnUnits[i] = row * columns + column
        i += 1
    }
    
    /* 3x3 box */
    row = 3 * (s / (3 * columns))
    column = 3 * ((s % rows) / 3)
    var boxUnits = [Int](repeating: 0, count: 3 * 3)
    for r in 0..<3 {
        for c in 0..<3 {
            let i = r * 3 + c
            boxUnits[i] = (row + r) * columns + (column + c)
        }
    }
    return [rowUnits, columnUnits, boxUnits]
}

/* The peers are the squares that share a unit. */
func squarePeers(_ s: Int) -> NSMutableSet {
    let peers = NSMutableSet(capacity: 20)
    
    /* same row */
    var row = s / columns
    for column in 0..<columns {
        let i = row * columns + column
        if i != s { peers.add(i) }
    }
    
    /* same column */
    var column = s % rows
    for row in 0..<rows {
        let i = row * columns + column
        if i != s { peers.add(i) }
    }
    
    /* 3x3 box */
    row = 3 * (s / (3 * columns))
    column = 3 * ((s % rows) / 3)
    for r in 0..<3 {
        for c in 0..<3 {
            let i = (row + r) * columns + (column + c)
            if i != s { peers.add(i) }
        }
    }
    return peers
}

/* Solve one grid */
func solve(_ grid: String) -> Grid {
    let g = Grid(grid)
    _ = g.search()
    return g
}
