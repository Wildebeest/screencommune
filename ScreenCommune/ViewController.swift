//
//  ViewController.swift
//  ScreenCommune
//
//  Created by Matt Wilde on 11/25/17.
//  Copyright © 2017 Matthew Wilde. All rights reserved.
//

import Cocoa
import Starscream
import AVKit

class Socket: WebSocketDelegate {
    let socket: WebSocket
    let label: String
    
    init(label: String) {
        self.label = label
        socket = WebSocket(url: URL(string: "ws://localhost:8080/")!)
        socket.delegate = self
    }
    
    func connect() {
        socket.connect()
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("\(label) websocket is connected")
        socket.write(string: label)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("\(label) websocket is disconnected: \(String(describing: error))")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("\(label) got some text: \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("\(label) got some data: \(data.count)")
    }
}

class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    var otherConnection: RTCPeerConnection?
    var dataChannel: RTCDataChannel?
    let dataChannelDelegate = DataChannelDelegate()
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print(stateChanged)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("audioTracks: \(stream.audioTracks.count)")
        print("videoTracks: \(stream.videoTracks.count)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print(stream)
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("ready")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print(newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print(newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // Pretend we sent it over the network
        let remoteCandidate = RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
        otherConnection?.add(remoteCandidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
        dataChannel.delegate = dataChannelDelegate
    }
}

class DataChannelDelegate: NSObject, RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        if dataChannel.readyState == .open {
            let buffer = RTCDataBuffer(data: "hi".data(using: .ascii)!, isBinary: false)
            dataChannel.sendData(buffer)
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        print(buffer)
    }
}

class RTCScreenVideoCapturer: RTCVideoCapturer, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    let output = AVCaptureVideoDataOutput()
    let frameQueue = DispatchQueue(label: "frameQueue")
    
    let nanosecondsPerSecond = 1000000000.0;
    
    override init(delegate: RTCVideoCapturerDelegate) {
        super.init(delegate: delegate)
        
        captureSession.addInput(AVCaptureScreenInput())
        captureSession.addOutput(output)
        
        output.setSampleBufferDelegate(self, queue: frameQueue)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let buffer = RTCCVPixelBuffer(pixelBuffer: imageBuffer)
            let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * nanosecondsPerSecond
            let frame = RTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
            delegate?.capturer(self, didCapture: frame)
        }
    }
}

class ViewController: NSViewController {
    required init?(coder: NSCoder) {
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        let config = RTCConfiguration()
        config.bundlePolicy = .balanced
        constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        connectionA = factory.peerConnection(with: config, constraints: constraints, delegate: connectionADelegate)
        connectionB = factory.peerConnection(with: config, constraints: constraints, delegate: connectionBDelegate)
        
        connectionADelegate.otherConnection = connectionB
        connectionBDelegate.otherConnection = connectionA
        
//        let dataConfig = RTCDataChannelConfiguration()
//        dataChannel = connectionA.dataChannel(forLabel: "channelA", configuration: dataConfig)
//        dataChannel.delegate = dataChannelDelegate
        
        screenStream = self.factory.mediaStream(withStreamId: "screenStream")
        let audioSource = self.factory.audioSource(with: nil)
        
        let videoSource = self.factory.videoSource()
        screenCapturer = RTCScreenVideoCapturer(delegate: videoSource)
        let screenTrack = self.factory.videoTrack(with: videoSource, trackId: "screenTrack")
        screenStream.addVideoTrack(screenTrack)
        
        let voiceTrack = self.factory.audioTrack(with: audioSource, trackId: "voiceTrack")
        screenStream.addAudioTrack(voiceTrack)
        connectionA.add(screenStream)
        
        super.init(coder: coder)
    }
    
    let factory: RTCPeerConnectionFactory
    
    let connectionADelegate = PeerConnectionDelegate()
    let connectionA: RTCPeerConnection
    
    let connectionBDelegate = PeerConnectionDelegate()
    let connectionB: RTCPeerConnection
    
    let screenStream: RTCMediaStream
    let screenCapturer: RTCScreenVideoCapturer
    
//    let dataChannel: RTCDataChannel
//    let dataChannelDelegate = DataChannelDelegate()
    
    let constraints: RTCMediaConstraints
    
    override func viewDidLoad() {
        super.viewDidLoad()

        startCall()
    }
    
    func startCall() {
        connectionA.offer(for: constraints) { (sessionDescription, error) in
            guard error == nil else { return }
            if let description = sessionDescription {
                self.connectionA.setLocalDescription(description, completionHandler: { (error) in
                    guard error == nil else { return }
                    self.sendOfferToB(type: description.type, sdp: description.sdp)
                })
            }
        }
    }
    
    func sendOfferToB(type: RTCSdpType, sdp: String) {
        // Pretend it went over the network
        // self.socket.write(string: description.sdp)
        let remoteDescription = RTCSessionDescription(type: type, sdp: sdp)
        self.connectionB.setRemoteDescription(remoteDescription, completionHandler: { (error) in
            guard error == nil else { return }
            self.connectionB.answer(for: self.constraints, completionHandler: { (sessionDescription, error) in
                guard error == nil else { return }
                if let description = sessionDescription {
                    self.connectionB.setLocalDescription(description, completionHandler: { (error) in
                        guard error == nil else { return }
                        self.sendAnswerToA(type: description.type, sdp: description.sdp)
                    })
                }
            })
        })
    }
    
    func sendAnswerToA(type: RTCSdpType, sdp: String) {
        // Pretend it went over the network
        // self.socket.write(string: description.sdp)
        let description = RTCSessionDescription(type: type, sdp: sdp)
        self.connectionA.setRemoteDescription(description) { (error) in
            guard error == nil else { return }
        }
    }
}

