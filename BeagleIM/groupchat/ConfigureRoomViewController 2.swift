//
// ConfigureRoomViewController.swift
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
import TigaseSwift
import Quartz

class ConfigureRoomViewController: NSViewController {
 
    @IBOutlet var progressIndicator: NSProgressIndicator!;
    
    var account: BareJID!;
    var mucComponent: BareJID!;
    var roomJid: BareJID!;
    var nickname: String?;
    
    private var room: DBChatStore.DBRoom?;
    
    @IBOutlet var avatarView: AvatarChangeButton!;
    @IBOutlet var roomNameField: NSTextField!;
    @IBOutlet var subjectField: NSTextField!;
    
    @IBOutlet var formView: JabberDataFormView!;
    @IBOutlet var scrollView: NSScrollView!;

    var form: JabberDataElement? {
        didSet {
            if let roomJid = self.roomJid, let account = self.account {
                avatarView.image = AvatarManager.instance.avatar(for: roomJid, on: account)
                roomNameField.stringValue = (form?.getField(named: "muc#roomconfig_roomname") as? TextSingleField)?.value ?? "";
                subjectField.stringValue = room?.subject ?? "";
            }
            formView.form = form;
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear();
        
        room = DBChatStore.instance.getChat(for: account, with: roomJid) as? DBChatStore.DBRoom;
        
        self.avatarView.isEnabled = false;
        self.avatarView.changeLabel.isEnabled = false;
        self.avatarView.changeLabel.isHidden = true;
        
        formView.hideFields = ["muc#roomconfig_roomname"];
        formView.isHidden = true;
        
        guard let client = XmppService.instance.getClient(for: account), let mucModule: MucModule = client.modulesManager.getModule(MucModule.ID) else {
            return;
        }
        
        let dispatchGroup = DispatchGroup();
        progressIndicator.startAnimation(nil);
        dispatchGroup.enter();
        mucModule.getRoomConfiguration(roomJid: JID(roomJid == nil ? mucComponent : roomJid!), onSuccess: { [weak self] (form) in
            DispatchQueue.main.async {
                self?.form = form;
                dispatchGroup.leave();
            }
        }, onError: { [weak self] errorCondition in
            // need to show alert here!
            dispatchGroup.leave();
            DispatchQueue.main.async { [weak self] in
                guard let that = self else {
                    return;
                }
                let alert = NSAlert();
                alert.messageText = "Error occurred";
                alert.icon = NSImage(named: NSImage.cautionName);
                alert.informativeText = "Could not retrieve room configuration from the server. Got following error: \(errorCondition?.rawValue ?? "timeout")";
                alert.addButton(withTitle: "OK");
                alert.beginSheetModal(for: that.view.window!, completionHandler: { result in
                    that.close(result: .cancel);
                });
            }
        });
        if let vCardTempModule: VCardTempModule = client.modulesManager.getModule(VCardTempModule.ID), let discoModule: DiscoveryModule = client.modulesManager.getModule(DiscoveryModule.ID) {
            dispatchGroup.enter();
            self.checkVCardSupport(vCardTempModule: vCardTempModule) { [weak self] (result) in
                guard let that = self else {
                    dispatchGroup.leave();
                    return;
                }

                switch result {
                case .success(let val):
                    DispatchQueue.main.async {
                        that.avatarView.isEnabled = val;
                        dispatchGroup.leave();
                    }
                case .failure(let err):
                    guard err == .item_not_found else {
                        DispatchQueue.main.async {
                            that.avatarView.isEnabled = false;
                            dispatchGroup.leave();
                        }
                        return;
                    }
                    that.checkVCardSupport(discoModule: discoModule) { (result) in
                        DispatchQueue.main.async {
                            guard let that = self else {
                                dispatchGroup.leave();
                                return;
                            }

                            switch result {
                            case .success(let value):
                                that.avatarView.isEnabled = value;
                            case .failure(_):
                                that.avatarView.isEnabled = false;
                            }
                            dispatchGroup.leave();
                        }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            self?.progressIndicator.stopAnimation(nil)
        }
    }
    
    private func checkVCardSupport(vCardTempModule: VCardTempModule, completionHandler: @escaping (Result<Bool,ErrorCondition>)->Void) {
        vCardTempModule.retrieveVCard(from: JID(roomJid!), callback: { (stanza) in
            completionHandler(((stanza?.type ?? .error) == .error) ? .failure(stanza?.errorCondition ?? ErrorCondition.undefined_condition) : .success(true));
        });
    }
    
    private func checkVCardSupport(discoModule: DiscoveryModule, completionHandler: @escaping (Result<Bool,ErrorCondition>)->Void) {
        discoModule.getInfo(for: JID(self.mucComponent!), onInfoReceived: { (node, identities, features) in
            completionHandler(.success(features.contains(VCardTempModule.ID)));
        }) { (errorCondition) in
            completionHandler(.failure(errorCondition ?? ErrorCondition.undefined_condition));
        }
    }
    
    @IBAction func cancelClicked(_ sender: NSButton) {
        self.close(result: .cancel);
    }
    
    @IBAction func acceptClicked(_ sender: NSButton) {
        guard form != nil else {
            return;
        }
        
        formView.synchronize();
        
        let name = roomNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines);
        (form?.getField(named: "muc#roomconfig_roomname") as? TextSingleField)?.value = name.isEmpty ? nil : name;
        
        guard let client = XmppService.instance.getClient(for: account), let mucModule: MucModule = client.modulesManager.getModule(MucModule.ID) else {
            return;
        }
        
        let dispatchGroup = DispatchGroup();
        dispatchGroup.enter();
        progressIndicator.startAnimation(nil);
        
        let queue = OperationQueue();
        queue.maxConcurrentOperationCount = 1;
        queue.isSuspended = true;
        
        let roomJid = self.roomJid!;
        
        if avatarView.isEnabled && avatarView.image != AvatarManager.instance.avatar(for: roomJid, on: account) {
            if let vCardTempModule: VCardTempModule = client.modulesManager.getModule(VCardTempModule.ID) {
                let vcard = VCard();
                if let binval = avatarView.image?.scaled(maxWidthOrHeight: 512.0, format: .jpeg, properties: [.compressionFactor: 0.8])?.base64EncodedString(options: []) {
                    vcard.photos = [VCard.Photo(uri: nil, type: "image/jpeg", binval: binval, types: [.home])];
                }
                queue.addOperation {
                    vCardTempModule.publishVCard(vcard, to: roomJid);
                }
            }
        }
        
        if subjectField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) != room?.subject ?? "" {
            let newSubject = subjectField.stringValue.isEmpty ? nil : subjectField.stringValue;
            queue.addOperation {
                mucModule.setRoomSubject(roomJid: roomJid, newSubject: newSubject);
            }
        }
        
        let account = self.account!;
        let room = self.room;
        let nickname = self.nickname;
        let password = (form!.getField(named: "muc#roomconfig_roomsecret") as? SingleField)?.rawValue;
        
        setRoomConfiguration(mucModule: mucModule, configuration: form!) { [weak self] (result) in
            switch result {
            case .success(_):
                if room?.state == Room.State.joined {
                    queue.isSuspended = false;
                } else if nickname != nil {
                    _ = try! mucModule.join(roomName: roomJid.localPart!, mucServer: roomJid.domain, nickname: nickname!, password: password, onJoined: { room in
                        queue.isSuspended = false;
                    });
                    PEPBookmarksModule.updateOrAdd(for: account, bookmark: Bookmarks.Conference(name: roomJid.localPart!, jid: JID(roomJid), autojoin: true, nick: nickname!, password: password));
                }
                dispatchGroup.leave();
                break;
            case .failure(let errorCondition):
                DispatchQueue.main.async {
                    guard let window = self?.view.window else {
                        return;
                    }
                    let alert = NSAlert();
                    alert.messageText = "Error occurred";
                    alert.icon = NSImage(named: NSImage.cautionName);
                    alert.informativeText = "Could not apply room configuration on the server. Got following error: \(errorCondition.rawValue)";
                    alert.addButton(withTitle: "OK");
                    alert.beginSheetModal(for: window, completionHandler: { result in
                        dispatchGroup.leave();
                    });
                }
            }
        }
                
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            self?.progressIndicator.stopAnimation(nil);
            self?.close();
        }
    }
    
    private func setRoomConfiguration(mucModule: MucModule, configuration: JabberDataElement, completionHandler: @escaping (Result<Void,ErrorCondition>)->Void) {
        mucModule.setRoomConfiguration(roomJid: JID(self.roomJid), configuration: configuration, onSuccess: {
            completionHandler(.success(Void()));
        }, onError: { errorCondition in
            completionHandler(.failure(errorCondition ?? .undefined_condition));
        })
    }
    
    @IBAction func disclosureClicked(_ sender: NSButton) {
        formView.isHidden = sender.state == .off;
    }
    
    fileprivate func close(result: NSApplication.ModalResponse = .OK) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: result);
    }
    
    @IBAction func avatarClicked(_ sender: Any) {
        let taker = IKPictureTaker.pictureTaker();
        if let image = avatarView.image {
            taker?.setInputImage(image);
        }
        taker?.setValue(true, forKey: IKPictureTakerShowAddressBookPictureKey)
        taker?.setValue(true, forKey: IKPictureTakerShowEmptyPictureKey);
        taker?.beginSheet(for: self.view.window!, withDelegate: self, didEnd: #selector(avatarSelected), contextInfo: nil);
    }
    
    @objc func avatarSelected(_ pictureTaker: IKPictureTaker, code: Int, context: Any?) {
        guard code == NSApplication.ModalResponse.OK.rawValue  else {
            return;
        }
        avatarView.image = pictureTaker.outputImage();
    }
}

class AvatarChangeButton: AvatarView {
    
    @IBOutlet var changeLabel: NSTextField!;

    private var trackingArea: NSTrackingArea?;
        
    override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea);
        }
        
        trackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil);
        self.addTrackingArea(trackingArea!);
    }
    
    override func mouseEntered(with event: NSEvent) {
        self.changeLabel.isHidden = (!isEnabled) || false;
    }
    
    override func mouseExited(with event: NSEvent) {
        self.changeLabel.isHidden = true;
    }
    
    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 1 && isEnabled else {
            return;
        }
        self.target?.performSelector(onMainThread: self.action!, with: self, waitUntilDone: false);
    }
}

class NSTextFieldNoClick: NSTextField {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil;
    }
    
}
