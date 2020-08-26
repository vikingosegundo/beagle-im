//
// VideoCallController.swift
//
// BeagleIM
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see https://www.gnu.org/licenses/.
//

import AppKit
import WebRTC
import TigaseSwift
import Metal
import UserNotifications
import os

class RTCVideoView: RTCMTLNSVideoView {
    
    override func renderFrame(_ frame: RTCVideoFrame?) {
        super.renderFrame(frame);
    }

}

class VideoCallController: NSViewController, RTCVideoViewDelegate, CallDelegate {
    
    public static let peerConnectionFactory: RTCPeerConnectionFactory = {
        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory());
    }();
    
    public static var hasAudioSupport: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized;
    }
    
    public static var hasVideoSupport: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized;
    }
    
    public static func open(completionHandler: @escaping (VideoCallController)->Void) {
        DispatchQueue.main.async {
            let windowController = NSStoryboard(name: "VoIP", bundle: nil).instantiateController(withIdentifier: "VideoCallWindowController") as! NSWindowController;
            completionHandler(windowController.contentViewController as! VideoCallController);
            windowController.showWindow(nil);
            DispatchQueue.main.async {
                windowController.window?.makeKey();
                NSApp.activate(ignoringOtherApps: true);
            }
        }
    }
    
    private var call: Call?;
    
    func callDidStart(_ call: Call) {
        self.call = call;
        self.updateAvatarView();
        self.updateStateLabel();
    }
    
    func callDidEnd(_ sender: Call) {
        self.call = nil;
        if sender.direction == .incoming {
            self.closeWindow();
        } else {
            self.hideAlert();
            var title = "Call ended";
            switch sender.state {
            case .ringing:
                title = "Call declined";
            case .connecting:
                title = "Call failed";
            default:
                break;
            }
            self.showAlert(title: title, buttons: ["OK"], completionHandler: { response in
                DispatchQueue.main.async {
                    self.closeWindow();
                }
            });
        }
    }
    
    func callStateChanged(_ sender: Call) {
        updateStateLabel();
    }
    
    func call(_ call: Call, didReceiveLocalVideoTrack localTrack: RTCVideoTrack) {
        self.localVideoTrack = localTrack;
    }
    
    func call(_ call: Call, didReceiveRemoteVideoTrack remoteTrack: RTCVideoTrack) {
        self.remoteVideoTrack = remoteTrack;
    }
    
    @IBOutlet var remoteVideoView: RTCMTLNSVideoView!
    @IBOutlet var localVideoView: RTCMTLNSVideoView!;
    
    @IBOutlet var remoteAvatarView: AvatarView!;
    
    var remoteVideoViewAspect: NSLayoutConstraint?
    var localVideoViewAspect: NSLayoutConstraint?
                
    fileprivate var localVideoTrack: RTCVideoTrack? {
        willSet {
            if localVideoTrack != nil && localVideoView != nil {
                localVideoTrack!.remove(localVideoView!);
            }
        }
        didSet {
            if localVideoTrack != nil && localVideoView != nil {
                localVideoTrack!.add(localVideoView!);
            }
        }
    }
    fileprivate var remoteVideoTrack: RTCVideoTrack? {
        willSet {
            if remoteVideoTrack != nil && remoteVideoView != nil {
                remoteVideoTrack!.remove(remoteVideoView);
            }
        }
        didSet {
            if remoteVideoTrack != nil && remoteVideoView != nil {
                remoteVideoTrack!.add(remoteVideoView);
            }
        }
    }
    
    @IBOutlet var stateLabel: NSTextField!;
    
    override func viewDidLoad() {
        super.viewDidLoad();

        localVideoViewAspect = localVideoView.widthAnchor.constraint(equalTo: localVideoView.heightAnchor, multiplier: 1.0);
        localVideoViewAspect?.isActive = true;
        
        remoteVideoViewAspect = remoteVideoView.widthAnchor.constraint(equalTo: remoteVideoView.heightAnchor, multiplier: 1.0);
        remoteVideoViewAspect?.isActive = true;
        
        localVideoView.delegate = self;
        remoteVideoView.delegate = self;
    }
    
    override func viewWillAppear() {
        super.viewWillAppear();
        
        if let call = self.call, call.state == .ringing {
            switch call.direction {
            case .incoming:
                self.askForAcceptance(for: call);
            case .outgoing:
                break;
            }
        }
        self.updateAvatarView();
        self.updateStateLabel();
    }
    
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        DispatchQueue.main.async {
            if videoView === self.localVideoView! {
                self.localVideoViewAspect?.isActive = false;
                self.localVideoView.removeConstraint(self.localVideoViewAspect!);
                self.localVideoViewAspect = self.localVideoView.widthAnchor.constraint(equalTo: self.localVideoView.heightAnchor, multiplier: size.width / size.height);
                self.localVideoViewAspect?.isActive = true;
            } else if videoView === self.remoteVideoView! {
                let currSize = self.remoteVideoView.frame.size;
                
                let newHeight = sqrt((currSize.width * currSize.height)/(size.width/size.height));
                let newWidth = newHeight * (size.width/size.height);
                
                self.remoteVideoViewAspect?.isActive = false;
                self.remoteVideoView.removeConstraint(self.remoteVideoViewAspect!);
                self.view.window?.setContentSize(NSSize(width: newWidth, height: newHeight));
                self.remoteVideoViewAspect = self.remoteVideoView.widthAnchor.constraint(equalTo: self.remoteVideoView.heightAnchor, multiplier: size.width / size.height);
                self.remoteVideoViewAspect?.isActive = true;
            }
        }
    }
    
    private func updateAvatarView() {
        if let call = self.call {
            self.remoteAvatarView?.image = AvatarManager.instance.avatar(for: call.jid, on: call.account);
            self.remoteAvatarView?.name = XmppService.instance.getClient(for: call.account)?.rosterStore?.get(for: JID(call.jid))?.name ?? call.jid.stringValue;
        } else {
            self.remoteAvatarView?.image = nil;
            self.remoteAvatarView?.name = nil;
        }
    }
    
    private func updateStateLabel() {
        DispatchQueue.main.async {
            switch self.call?.state ?? .new {
            case .new:
                self.stateLabel.stringValue = "New call";
            case .ringing:
                self.stateLabel.stringValue = "Ringing...";
                if self.call?.direction == .outgoing {
                    self.avplayer = AVPlayer(url: Bundle.main.url(forResource: "outgoingCall", withExtension: "mp3")!);
                }
            case .connecting:
                self.stateLabel.stringValue = "Connecting...";
            case .connected:
                self.stateLabel.stringValue = "";
                self.remoteAvatarView?.isHidden = self.remoteVideoTrack != nil;
                self.avplayer = nil;
            case .ended:
                self.stateLabel.stringValue = "Call ended";
                self.avplayer = nil;
            }
        }
    }
    
    private var avplayer: AVPlayer? = nil {
        didSet {
            if let value = oldValue {
                os_log(OSLogType.debug, log: .jingle, "deregistering av player item: %s", value.currentItem?.description ?? "nil");
                value.pause();
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: value.currentItem);
            }
            if let value = avplayer {
                value.actionAtItemEnd = .none;
                os_log(OSLogType.debug, log: .jingle, "registering av player item: %s", value.currentItem?.description ?? "nil");
                NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: value.currentItem);
                value.play();
            }
        }
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: CMTime.zero, completionHandler: nil)
        }
    }
    
    var logger: RTCFileLogger?;
    var loggerFile: URL?;
        
    func askForAcceptance(for call: Call) {
        DispatchQueue.main.async {
            self.avplayer = AVPlayer(url: Bundle.main.url(forResource: "incomingCall", withExtension: "mp3")!);
            let buttons = [ "Accept", "Reject" ];
            
            let name = XmppService.instance.getClient(for: call.account)?.rosterStore?.get(for: JID(call.jid))?.name ?? call.jid.stringValue;
            
            self.showAlert(title: "Incoming \(call.media.contains(.video) ? "video" : "audio") call from \(name)", message: "Do you want to accept this call?", buttons: buttons, completionHandler: { (response) in
                self.avplayer = nil;
                switch response {
                case .alertFirstButtonReturn:
                    DispatchQueue.global().async {
                        call.accept()
                    }
                default:
                    call.reject();
                }
            });
        }
    }
    
    var muted: Bool = false;
    
    @IBAction func muteClicked(_ sender: RoundButton) {
        muted = !muted;
        sender.backgroundColor = muted ? NSColor.red : NSColor.white;
        sender.contentTintColor = muted ? NSColor.white : NSColor.black;
        
        self.call?.muted(value: muted);
    }
            
    static let defaultCallConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]);
    
    static func initiatePeerConnection(withDelegate delegate: RTCPeerConnectionDelegate) -> RTCPeerConnection? {
        let configuration = RTCConfiguration();
        configuration.sdpSemantics = .unifiedPlan;
        
        let iceServers: [RTCIceServer] = [ RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302","stun:stun1.l.google.com:19302","stun:stun2.l.google.com:19302","stun:stun3.l.google.com:19302","stun:stun4.l.google.com:19302"]), RTCIceServer(urlStrings: ["stun:stunserver.org:3478" ]) ];
        
//        if var urlComponents = URLComponents(string: Settings.turnServer.string() ?? "") {
//            let username = urlComponents.user;
//            let password = urlComponents.password;
//            urlComponents.user = nil;
//            urlComponents.password = nil;
//            let server = urlComponents.string!.replacingOccurrences(of: "/", with: "");
//            print("turn server:", server, "user:", username as Any, "pass:", password as Any);
//            iceServers.append(RTCIceServer(urlStrings: [server], username: username, credential: password, tlsCertPolicy: .insecureNoCheck));
//            let forceRelay = urlComponents.queryItems?.filter({ item in
//                item.name == "forceRelay" && item.value == "true"
//            }) != nil;
//            if forceRelay {
//                configuration.iceTransportPolicy = .relay;
//            }
//        }
        
        configuration.iceServers = iceServers;
        configuration.bundlePolicy = .maxCompat;
        configuration.rtcpMuxPolicy = .require;
        configuration.iceCandidatePoolSize = 3;
        
        return peerConnectionFactory.peerConnection(with: configuration, constraints: defaultCallConstraints, delegate: delegate);
    }
    
    @IBAction func closeClicked(_ sender: Any) {
        call?.reset();
//        self.localVideoCapturer?.stopCapture();
//        self.localVideoCapturer = nil;
//        if let session = self.session {
//            session.delegate = nil;
//            _ = session.terminate();
//        }
//        self.sessionsInProgress.forEach { sess in
//            sess.delegate = nil;
//            _ = sess.terminate();
//        }
        self.closeWindow();
    }

    fileprivate var alertWindow: NSWindow?;
    
    fileprivate func hideAlert() {
        DispatchQueue.main.async {
            if let window = self.alertWindow {
                self.alertWindow = nil;
                self.view.window?.endSheet(window);
            }
        }
    }
    
    fileprivate func showAlert(title: String, message: String = "", icon: NSImage? = nil, buttons: [String], completionHandler: @escaping (NSApplication.ModalResponse)->Void) {
        hideAlert();
        DispatchQueue.main.async {
            guard let window = self.view.window else {
                self.closeWindow();
                return;
            }
            let alert = NSAlert();
            alert.messageText = title;
            alert.informativeText = message;
            if icon != nil {
                alert.icon = icon!;
            }
            buttons.forEach { (button) in
                alert.addButton(withTitle: button);
            }
            // window for some reason is nil already!!
            alert.beginSheetModal(for: window, completionHandler: { (result) in
                self.alertWindow = nil;
                completionHandler(result);
            });
            self.alertWindow = alert.window;
        }
    }
    
    func closeWindow() {
        logger?.stop();
        
        DispatchQueue.main.async {
            self.avplayer = nil;
            self.localVideoTrack = nil;
            self.remoteVideoTrack = nil;
            self.view.window?.orderOut(self);
        }
    }
}
