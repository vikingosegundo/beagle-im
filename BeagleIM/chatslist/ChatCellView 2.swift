//
// ChatCellView.swift
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

class ChatCellView: NSTableCellView {
    
    fileprivate static let todaysFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.dateStyle = .none;
        f.timeStyle = .short;
        return f;
    })();
    fileprivate static let defaultFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "dd.MM", options: 0, locale: NSLocale.current);
        //        f.timeStyle = .NoStyle;
        return f;
    })();
    fileprivate static let fullFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "dd.MM.yyyy", options: 0, locale: NSLocale.current);
        //        f.timeStyle = .NoStyle;
        return f;
    })();
    
    @IBOutlet weak var avatar: AvatarViewWithStatus! {
        didSet {
            self.avatar?.avatarView?.appearance = NSAppearance(named: .darkAqua);
        }
    }
    @IBOutlet weak var label: NSTextField!;
    @IBOutlet weak var lastMessage: ChatCellViewMessage!;
    @IBOutlet weak var lastMessageTs: NSTextField!;
    @IBOutlet weak var unreadButton: NSButton!;
    @IBOutlet weak var closeButton: ChatsCellViewCloseButton!
    
    var closeFunction: (()->Void)?;
    
    fileprivate var chatState: ChatState = .active;
    
    @IBAction func closeClicked(_ sender: ChatsCellViewCloseButton) {
        closeFunction?();
    }
    
    func set(avatar: NSImage?) {
        self.avatar?.avatar = avatar;
    }
    
    func set(name: String?) {
        self.label?.stringValue = name ?? "";
        self.avatar?.name = name;
    }
    
    func set(lastActivity: LastChatActivity?, ts: Date?, chatState: ChatState) {
        self.chatState = chatState;
        if chatState != .composing {
            self.lastMessage?.stopAnimating();
            if let activity = lastActivity {
                switch activity {
                case .message(let lastMessage, let sender):
                    let msg = NSMutableAttributedString(string: lastMessage);
                    if Settings.enableMarkdownFormatting.bool() {
                        Markdown.applyStyling(attributedString: msg, fontSize: NSFont.systemFontSize - 1, showEmoticons: Settings.showEmoticons.bool());
                    }
                    if let prefix = sender != nil ? NSMutableAttributedString(string: "\(sender!): ") : nil {
                        prefix.append(msg);
                        self.lastMessage?.attributedStringValue = prefix;
                    } else {
                        self.lastMessage?.attributedStringValue = msg;
                    }
                case .invitation(_, let sender):
                    if let fieldfont = self.lastMessage?.font {
                        let msg = NSAttributedString(string: "📨 Invitation", attributes: [.font:  NSFontManager.shared.convert(fieldfont, toHaveTrait: [.italicFontMask, .fixedPitchFontMask, .boldFontMask]), .foregroundColor: self.lastMessage.textColor!.withAlphaComponent(0.8)]);

                        if let prefix = sender != nil ? NSMutableAttributedString(string: "\(sender!): ") : nil {
                            prefix.append(msg);
                            self.lastMessage?.attributedStringValue = prefix;
                        } else {
                            self.lastMessage?.attributedStringValue = msg;
                        }
                    } else {
                        let msg = NSAttributedString(string: "📨 Invitation", attributes: [.foregroundColor: self.lastMessage.textColor!.withAlphaComponent(0.8)]);
                        
                        if let prefix = sender != nil ? NSMutableAttributedString(string: "\(sender!): ") : nil {
                            prefix.append(msg);
                            self.lastMessage?.attributedStringValue = prefix;
                        } else {
                            self.lastMessage?.attributedStringValue = msg;
                        }
                    }
                case .attachment(_, let sender):
                    if let fieldfont = self.lastMessage?.font {
                        let msg = NSAttributedString(string: "📎 Attachment", attributes: [.font:  NSFontManager.shared.convert(fieldfont, toHaveTrait: [.italicFontMask, .fixedPitchFontMask, .boldFontMask]), .foregroundColor: self.lastMessage.textColor!.withAlphaComponent(0.8)]);

                        if let prefix = sender != nil ? NSMutableAttributedString(string: "\(sender!): ") : nil {
                            prefix.append(msg);
                            self.lastMessage?.attributedStringValue = prefix;
                        } else {
                            self.lastMessage?.attributedStringValue = msg;
                        }
                    } else {
                        let msg = NSAttributedString(string: "📎 Attachment", attributes: [.foregroundColor: self.lastMessage.textColor!.withAlphaComponent(0.8)]);
                        
                        if let prefix = sender != nil ? NSMutableAttributedString(string: "\(sender!): ") : nil {
                            prefix.append(msg);
                            self.lastMessage?.attributedStringValue = prefix;
                        } else {
                            self.lastMessage?.attributedStringValue = msg;
                        }
                    }
                }
            } else {
                self.lastMessage?.stringValue = "";
            }
            self.lastMessage?.maximumNumberOfLines = 2;
        } else {
            self.lastMessage?.stringValue = "";
            self.lastMessage?.startAnimating();
        }
        //self.lastMessage?.preferredMaxLayoutWidth = self.lastMessage!.frame.width;
        self.lastMessageTs?.stringValue = ts != nil ? formatTimestamp(ts!) : "";
        self.lastMessage?.invalidateIntrinsicContentSize();
    }
    
    func set(chatState: ChatState) {
        self.chatState = chatState;
        if chatState == .composing {
            self.lastMessage?.stringValue = "";
            self.lastMessage?.startAnimating();
        } else {
            self.lastMessage?.stringValue = "";
            self.lastMessage?.stopAnimating();
        }
    }
    
    func set(unread: Int) {
        if unread > 0 {
            self.unreadButton.title = "\(unread)"
            self.unreadButton.isHidden = false;
        } else {
            self.unreadButton.title = "0";
            self.unreadButton.isHidden = true;
        }
    }
    
    fileprivate func formatTimestamp(_ ts: Date) -> String {
        let flags: Set<Calendar.Component> = [.day, .year];
        let components = Calendar.current.dateComponents(flags, from: ts, to: Date());
        if (components.day! == 1) {
            return "Yesterday";
        } else if (components.day! < 1) {
            return ChatCellView.todaysFormatter.string(from: ts);
        }
        if (components.year! != 0) {
            return ChatCellView.fullFormatter.string(from: ts);
        } else {
            return ChatCellView.defaultFormatter.string(from: ts);
        }
        
    }
    
    func update(from item: ChatItemProtocol) {
        self.set(name: item.name);
        self.set(unread: item.unread);
        self.set(lastActivity: item.lastActivity, ts: item.lastMessageTs, chatState: (item.chat as? DBChatStore.DBChat)?.remoteChatState ?? .active);
        if item.chat is Chat {
            self.avatar.update(for: item.chat.jid.bareJid, on: item.chat.account);
        } else if let room  = item.chat as? Room {
            self.avatar.update(for: item.chat.jid.bareJid, on: item.chat.account, orDefault: NSImage(named: NSImage.userGroupName));
            self.avatar.status = room.state == .joined ? .online : (room.state == .requested ? .away : nil);
        } else if let channel = item.chat as? Channel {
            self.avatar.update(for: item.chat.jid.bareJid, on: item.chat.account, orDefault: NSImage(named: NSImage.userGroupName));
            self.avatar.status = (XmppService.instance.getClient(for: item.chat.account)?.state ?? .disconnected == .connected) && channel.state == .joined ? .online : nil;
        }
    }

//    override func layout() {
//        super.layout();
//
//        if let width = self.superview?.superview?.frame.width {
//            self.lastMessage.preferredMaxLayoutWidth = width - 66;
//        }
//    }
//
//    override func resize(withOldSuperviewSize oldSize: NSSize) {
//        super.resize(withOldSuperviewSize: oldSize);
//        if let width = self.superview?.superview?.frame.width {
//            self.lastMessage.preferredMaxLayoutWidth = width - 66;
//        }
//    }
 
    func setMouseHovers(_ val: Bool) {
        self.lastMessage.blured = val;
        self.closeButton.isHidden = !val;
    }
}

