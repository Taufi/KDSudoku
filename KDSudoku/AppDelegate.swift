//
//  AppDelegate.swift
//  KDSudoku
//
//  Created by Klaus Dresbach on 18.03.19.
//  Copyright © 2019 Klaus Dresbach. All rights reserved.
//
//KD 190508 mlmodel von hier: https://github.com/patrykscheffler/sudoku-solver
//KD 190428 - Video-Capturing abgekupfert aus CatsAndDogs
// - dies wiederum aus Wenderlich - Machine Learning by Tutorials - Abschnitt „Classifying on live video“
//KD 190502 Group Queue eingeführt, damit ich die 81 Bilderkennungstasks parallel starten kann und
//          nach Abschluss aller Tasks Die Anzeige aktualisiert wird.
// Lösung von hier (Post von Imanou Petit): https://stackoverflow.com/questions/11909629/waiting-until-two-async-blocks-are-executed-before-starting-another-block


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?


  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    return true
  }

}

