//
//  AppDelegate.swift
//  ScreenCommune
//
//  Created by Matt Wilde on 11/25/17.
//  Copyright © 2017 Matthew Wilde. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //RTCInitializeSSL()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        RTCCleanupSSL()
    }


}

