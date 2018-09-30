//
//  ChatsListGroupAbstractChat.swift
//  BeagleIM
//
//  Created by Andrzej Wójcik on 20.09.2018.
//  Copyright © 2018 HI-LOW. All rights reserved.
//

import AppKit
import TigaseSwift

class ChatsListGroupAbstractChat<I: DBChatProtocol>: ChatsListGroupProtocol {
    
    let name: String;
    weak var delegate: ChatsListViewDataSourceDelegate?;
    fileprivate var items: [ChatItemProtocol] = [];
    let dispatcher: QueueDispatcher;
    
    init(name: String, dispatcher: QueueDispatcher, delegate: ChatsListViewDataSourceDelegate) {
        self.name = name;
        self.delegate = delegate;
        self.dispatcher = dispatcher;
        
        NotificationCenter.default.addObserver(self, selector: #selector(chatOpened), name: DBChatStore.CHAT_OPENED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(chatClosed), name: DBChatStore.CHAT_CLOSED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(chatUpdated), name: DBChatStore.CHAT_UPDATED, object: nil);
        
        dispatcher.async {
            DispatchQueue.main.sync {
                self.items = DBChatStore.instance.getChats().filter({dbChatProtocol -> Bool in
                    return dbChatProtocol is I;
                }).map({ (dbChat) -> ChatItemProtocol in
                    let item = self.newChatItem(chat: dbChat as! I)!;
                    return item;
                }).sorted(by: self.chatsSorter);
                print("loaded", self.items.count, "during initialization of the view");
                self.delegate?.reload();
            }
        }
    }
    
    var count: Int {
        return items.count;
    }
    
    func newChatItem(chat: I) -> ChatItemProtocol? {
        return nil;
    }
    
    func getChat(at index: Int) -> ChatItemProtocol? {
        return items[index];
    }
    
    func forChat(_ chat: DBChatProtocol, execute: @escaping (ChatItemProtocol) -> Void) {
        self.dispatcher.async {
            let items = DispatchQueue.main.sync { return self.items; };
            guard let item = items.first(where: { (it) -> Bool in
                it.chat.id == chat.id
            }) else {
                return;
            }
            
            execute(item);
        }
    }
    
    func forChat(account: BareJID, jid: BareJID, execute: @escaping (ChatItemProtocol) -> Void) {
        self.dispatcher.async {
            let items = DispatchQueue.main.sync { return self.items; };
            guard let item = items.first(where: { (it) -> Bool in
                it.chat.account == account && it.chat.jid.bareJid == jid
            }) else {
                return;
            }
            
            execute(item);
        }
    }
    
    func chatsSorter(i1: ChatItemProtocol, i2: ChatItemProtocol) -> Bool {
        return i1.lastMessageTs.compare(i2.lastMessageTs) == .orderedDescending;
    }

    @objc func avatarChanged(_ notification: Notification) {
        guard let account = notification.userInfo?["account"] as? BareJID, let jid = notification.userInfo?["jid"] as? BareJID else {
            return;
        }
        self.updateItem(for: account, jid: jid, execute: nil);
    }
    
    @objc func chatOpened(_ notification: Notification) {
        guard let opened = notification.object as? I else {
            return;
        }
        
        dispatcher.async {
            print("opened chat account =", opened.account, ", jid =", opened.jid)
            
            var items = DispatchQueue.main.sync { return self.items };
            
            guard items.index(where: { (item) -> Bool in
                item.chat.id == opened.id
            }) == nil else {
                return;
            }
            
            let item = self.newChatItem(chat: opened)!;
            let idx = items.index(where: { (it) -> Bool in
                it.lastMessageTs.compare(item.lastMessageTs) == .orderedAscending;
            }) ?? items.count;
            items.insert(item, at: idx);
            
            DispatchQueue.main.async {
                self.items = items;
                self.delegate?.itemsInserted(at: IndexSet(integer: idx), inParent: self);
            }
        }
    }
    
    @objc func chatClosed(_ notification: Notification) {
        guard let opened = notification.object as? I else {
            return;
        }
        
        dispatcher.async {
            var items = DispatchQueue.main.sync { return self.items };
            guard let idx = items.index(where: { (item) -> Bool in
                item.chat.id == opened.id
            }) else {
                return;
            }
            
            _ = items.remove(at: idx);
            
            DispatchQueue.main.async {
                self.items = items;
                self.delegate?.itemsRemoved(at: IndexSet(integer: idx), inParent: self);
            }
        }
    }
    
    @objc func chatUpdated(_ notification: Notification) {
        guard let e = notification.object as? I else {
            return;
        }
        
        dispatcher.async {
            var items = DispatchQueue.main.sync { return self.items };
            guard let oldIdx = items.index(where: { (item) -> Bool in
                item.chat.id == e.id;
            }) else {
                return;
            }
            
            let item = items.remove(at: oldIdx);
            
            let newIdx = items.index(where: { (it) -> Bool in
                it.lastMessageTs.compare(item.lastMessageTs) == .orderedAscending;
            }) ?? items.count;
            items.insert(item, at: newIdx);
            
            if oldIdx == newIdx {
                DispatchQueue.main.async {
                    self.delegate?.itemChanged(item: item);
                }
            } else {
                DispatchQueue.main.async {
                    self.items = items;
                    self.delegate?.itemMoved(from: oldIdx, fromParent: self, to: newIdx, toParent: self);
                    self.delegate?.itemChanged(item: item);
                }
            }
        }
    }

    func updateItem(for account: BareJID, jid: BareJID, execute: ((ChatItemProtocol) -> Void)?) {
        dispatcher.async {
            let items = DispatchQueue.main.sync { return self.items };
            guard let idx = items.index(where: { (item) -> Bool in
                item.chat.account == account && item.chat.jid.bareJid == jid
            }) else {
                return;
            }
            
            let item = self.items[idx];
            
            execute?(item);
            
            DispatchQueue.main.async {
                self.delegate?.itemChanged(item: item);
            }
        }
    }
}
