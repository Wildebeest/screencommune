//
//  ViewController.swift
//  ScreenCommune
//
//  Created by Matt Wilde on 11/25/17.
//  Copyright © 2017 Matthew Wilde. All rights reserved.
//

import Cocoa
import Starscream

class ViewController: NSViewController, WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket is connected")
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("got some text: \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("got some data: \(data.count)")
    }
    
    required init?(coder: NSCoder) {
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        let config = RTCConfiguration()
        config.bundlePolicy = .balanced
        constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        connection = factory.peerConnection(with: config, constraints: constraints, delegate: nil)
        
        socket = WebSocket(url: URL(string: "ws://localhost:8080/")!)
        super.init(coder: coder)
    }
    
    let factory: RTCPeerConnectionFactory
    let connection: RTCPeerConnection
    let constraints: RTCMediaConstraints
    let socket: WebSocket

    override func viewDidLoad() {
        super.viewDidLoad()
        
        socket.delegate = self
        socket.connect()
        
        connection.offer(for: constraints) { (sessionDescription, error) in
            if let error = error {
                print(error)
            }
            if let description = sessionDescription {
                self.connection.setLocalDescription(description, completionHandler: { (error) in
                    print(error)
                })
            }
        }
        

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

