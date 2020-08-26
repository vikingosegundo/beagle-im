//
// AddAccountController.swift
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

class AddAccountController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet var logInButton: NSButton!;
    @IBOutlet var stackView: NSStackView!
    @IBOutlet var registerButton: NSButton!;
    
    var usernameField: NSTextField!;
    var passwordField: NSSecureTextField!;
    
    override func viewWillAppear() {
        super.viewWillAppear();
        usernameField = addRow(label: "Username", field: NSTextField(string: ""));
        usernameField.placeholderString = "user@domain.com";
        usernameField.delegate = self;
        passwordField = addRow(label: "Password", field: NSSecureTextField(string: ""));
        passwordField.placeholderString = "Required";
        passwordField.delegate = self;
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertTab(_:)) {
            control.resignFirstResponder();
            
            guard var idx = self.stackView.views.firstIndex(where: { (view) -> Bool in
                view.subviews[1] == control;
            }) else {
                return false;
            }
            
            var responder: NSResponder? = nil;
            repeat {
                idx = idx + 1;
                if idx >= self.stackView.views.count {
                    idx = 0;
                }
                responder = self.stackView.views[idx].subviews[1];
                if !(responder?.acceptsFirstResponder ?? false) {
                    responder = nil;
                }
            } while responder == nil;
            
            self.view.window?.makeFirstResponder(responder);
            
            return true;
        }
        return false;
    }
    
    func controlTextDidChange(_ obj: Notification) {
        logInButton.isEnabled = !(usernameField.stringValue.isEmpty || passwordField.stringValue.isEmpty);
    }
    
    @IBAction func cancelClicked(_ button: NSButton) {
        self.view.window?.sheetParent?.endSheet(self.view.window!)
    }
    
    @IBAction func logInClicked(_ button: NSButton) {
        let jid = BareJID(usernameField.stringValue);
        let account = AccountManager.Account(name: jid);
        account.password = passwordField.stringValue;
        _ = AccountManager.save(account: account);
        self.view.window?.sheetParent?.endSheet(self.view.window!);
    }
    
    @IBAction func registerClicked(_ button: NSButton) {
        guard let registerAccountController = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("RegisterAccountController")) as? RegisterAccountController else {
            self.view.window?.sheetParent?.endSheet(self.view.window!);
            return;
        }
        
        let window = NSWindow(contentViewController: registerAccountController);
        self.view.window?.beginSheet(window, completionHandler: { (reponse) in
            self.view.window?.sheetParent?.endSheet(self.view.window!);
        })
    }
    
    func addRow<T: NSView>(label text: String, field: T) -> T {
        let label = createLabel(text: text);
        let row = RowView(views: [label, field]);
        self.stackView.addView(row, in: .bottom);
        return field;
    }
    
    func createLabel(text: String) -> NSTextField {
        let label = NSTextField(string: text);
        label.isEditable = false;
        label.isBordered = false;
        label.drawsBackground = false;
        label.widthAnchor.constraint(equalToConstant: 120).isActive = true;
        label.alignment = .right;
        return label;
    }
    
    class RowView: NSStackView {
    }
}
