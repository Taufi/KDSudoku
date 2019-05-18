//
//  AppDelegate.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 18.03.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//
//KD 190508 mlmodel von hier: https://github.com/patrykscheffler/sudoku-solver
//KD 190428 - Video-Capturing abgekupfert aus CatsAndDogs
//          - dies wiederum aus Wenderlich - Machine Learning by Tutorials - Abschnitt
//            „Classifying on live video“
//KD 190502 Group Queue eingeführt, damit ich die 81 Bilderkennungstasks parallel starten kann und
//          erst nach Abschluss aller Tasks die Anzeige aktualisiert wird.
// Lösung von hier (Post von Imanou Petit): https://stackoverflow.com/questions/11909629/waiting-until-two-async-blocks-are-executed-before-starting-another-block
//
//KD 190513 nun zeichne ich das Rechteck. Dies kupfere ich ab aus VisionBasics, was wiederum die
//          Beispiel-App von hier ist: https://developer.apple.com/documentation/vision/detecting_objects_in_still_images
//
//KD 190514 to do
//  - benötige ich die Klassenvariablen imageWidth und imageHeight wirklich - erledigt (rausgeschmissen)
//  - eigentlich reicht es, nur ein Rechteck zu drawen (gehe noch mit dem Array rein, das kann
//    irreführend sein, wenn ich zwei Suokus anzeige aber nur eines löse) - erledigt
//  - Capture-Frequenz erhöhen (auch mal richtig hoch ;-)) - erledigt
//
//KD 190517 Anzeige des erkannten Sudoku im resultsTextView


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?


  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    return true
  }

}

