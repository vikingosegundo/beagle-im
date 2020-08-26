//
// ExecuteAdhocCommandController.swift
//
// BeagleIM
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

class ExecuteAdHocCommandController: NSViewController {

    @IBOutlet var titleField: NSTextField!;
    @IBOutlet var titleFieldHeightConstraint: NSLayoutConstraint!;
    @IBOutlet var titleInstructionsSpaceConstraint: NSLayoutConstraint!;
    var titleInstructionsNoSpaceConstraint: NSLayoutConstraint?;
    @IBOutlet var instructionsField: NSTextField!;
    @IBOutlet var instructionsFieldHeightConstraint: NSLayoutConstraint!;
    @IBOutlet var instructionsFormSpaceConstraint: NSLayoutConstraint!;
    var instructionsFormNoSpaceConstraint: NSLayoutConstraint?;

    @IBOutlet var progressIndicator: NSProgressIndicator!;
    @IBOutlet var executeButton: NSButton!;
    @IBOutlet var closeButton: NSButton!;
    @IBOutlet var formView: JabberDataFormView!;
    @IBOutlet var scrollView: NSScrollView!;
    
    var account: BareJID!;
    var jid: JID!;
    var commandId: String!;

    var form: JabberDataElement? {
        didSet {
            if let title = form?.title, !title.isEmpty {
                titleField.stringValue = title;
                titleFieldHeightConstraint.isActive = false;
                titleInstructionsNoSpaceConstraint?.isActive = false;
                titleInstructionsSpaceConstraint.isActive = true;
            } else {
                titleField.stringValue = "";
                titleFieldHeightConstraint.isActive = true;
                titleInstructionsSpaceConstraint.isActive = false;
                titleInstructionsNoSpaceConstraint?.isActive = true;
            }
            
            if let instructions = form?.instructions?.map({ s -> String in s ?? ""}).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), !instructions.isEmpty {
                instructionsField.stringValue = instructions;
                instructionsFieldHeightConstraint.isActive = false;
                instructionsFormNoSpaceConstraint?.isActive = false;
                instructionsFormSpaceConstraint.isActive = true;
            } else {
                instructionsField.stringValue = "";
                instructionsFieldHeightConstraint.isActive = true;
                instructionsFormSpaceConstraint.isActive = false;
                instructionsFormNoSpaceConstraint?.isActive = true;
            }
            
            self.formView.form = form;
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear();
        if titleInstructionsNoSpaceConstraint == nil {
            titleInstructionsNoSpaceConstraint = self.titleField.bottomAnchor.constraint(equalTo: self.instructionsField.topAnchor);
        }
        if instructionsFormNoSpaceConstraint == nil {
            instructionsFormNoSpaceConstraint = self.instructionsField.bottomAnchor.constraint(equalTo: self.scrollView.topAnchor);
        }
        titleInstructionsSpaceConstraint.isActive = false;
        titleInstructionsNoSpaceConstraint?.isActive = true;
        instructionsFormSpaceConstraint.isActive = false;
        instructionsFormNoSpaceConstraint?.isActive = true;
        
        self.execute();
    }
    
    @IBAction func cancelClicked(_ sender: NSButton) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: .cancel);
    }
    
    @IBAction func executeClicked(_ sender: NSButton) {
        self.execute();
    }
    
    fileprivate func execute() {
        executeButton.isEnabled = false;
        guard let adhocModule: AdHocCommandsModule = XmppService.instance.getClient(for: account)?.modulesManager.getModule(AdHocCommandsModule.ID) else {
            return;
        }
        self.formView.synchronize();
        progressIndicator.startAnimation(self);
        adhocModule.execute(on: jid, command: commandId, action: .execute, data: formView.form, onSuccess: { [weak self] (stanza, data) in
            DispatchQueue.main.async {
                self?.form = data;
                self?.progressIndicator.stopAnimation(self)
                self?.executeButton.isEnabled = (data?.type ?? .result) == .form;
            }
        }) { [weak self] (error) in
            DispatchQueue.main.async {
                if let that = self {
                    that.progressIndicator.stopAnimation(nil);
                    let alert = NSAlert();
                    alert.messageText = "Error occurred";
                    alert.icon = NSImage(named: NSImage.cautionName);
                    let errorText = error?.rawValue ?? "timeout";
                    alert.informativeText = "Could not execute command: \(errorText)";
                    alert.addButton(withTitle: "OK");
                    alert.beginSheetModal(for: that.view.window!, completionHandler: { result in
                        // nothing to do..
                    });
                }
            }
        }
    }
    
}
