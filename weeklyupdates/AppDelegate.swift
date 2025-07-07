//
//  AppDelegate.swift
//  weeklyupdates
//
//  Created by Ryan West on 7/7/25.
//

import Cocoa
import WebKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var globalKeyMonitor: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "🐦"
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create the popover with web view
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        let webViewController = WebPopoverViewController()
        webViewController.appDelegate = self
        popover.contentViewController = webViewController
        
        // Set up global keyboard shortcut (Control+Shift+N)
        setupGlobalKeyboardShortcut()
        
        // Check for auto-summary generation on launch
        checkAutoSummaryGeneration()
    }
    
    private func setupGlobalKeyboardShortcut() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Control+Shift+N
            if event.modifierFlags.contains([.control, .shift]) && event.keyCode == 45 { // 45 is 'N'
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }
    
    private func checkAutoSummaryGeneration() {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Check if it's Friday (weekday 6) at 9am (within 10 minutes)
        if weekday == 6 && hour == 9 && minute < 10 {
            print("🤖 Auto-summary check: Friday 9am detected")
            
            // Check if we should generate auto-summary
            if let webViewController = popover.contentViewController as? WebPopoverViewController {
                webViewController.checkAndGenerateAutoSummary()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Remove the global key monitor
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // Focus the text area after a short delay to ensure the web view is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let webViewController = self.popover.contentViewController as? WebPopoverViewController {
                        webViewController.focusTextArea()
                    }
                }
            }
        }
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "weeklyupdates")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support

    func save() {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }
}

// MARK: - Web Popover View Controller
class WebPopoverViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var webView: WKWebView!
    weak var appDelegate: AppDelegate?
    
    override func loadView() {
        // Create web view configuration
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "nativeApp")
        
        // Add console message handler to capture JavaScript console logs
        config.userContentController.add(self, name: "console")
        
        // Create web view
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 600), configuration: config)
        webView.navigationDelegate = self
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
        self.view = webView
        
        // Load the local web app
        loadLocalWebApp()
    }
    
    private func loadLocalWebApp() {
        print("=== LOADING LOCAL WEB APP ===")
        
        // Load from bundled HTML file at the root of the Resources directory
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            print("Found HTML file at: \(htmlPath)")
            let url = URL(fileURLWithPath: htmlPath)
            let baseURL = url.deletingLastPathComponent()
            print("Loading URL: \(url)")
            print("Base URL: \(baseURL)")
            
            // Check if the file exists and is readable
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: htmlPath) {
                print("HTML file exists and is readable")
                do {
                    let htmlContent = try String(contentsOf: url, encoding: .utf8)
                    print("HTML content length: \(htmlContent.count) characters")
                    print("HTML content preview: \(String(htmlContent.prefix(200)))...")
                } catch {
                    print("Error reading HTML file: \(error)")
                }
            } else {
                print("ERROR: HTML file does not exist at path!")
            }
            
            webView.loadFileURL(url, allowingReadAccessTo: baseURL)
        } else {
            print("ERROR: Could not find index.html in bundle!")
            print("Bundle resources: \(Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil))")
            // Fallback to embedded HTML
            print("Falling back to embedded HTML")
            loadEmbeddedHTML()
        }
    }
    
    private func loadEmbeddedHTML() {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Weekly Updates</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: var(--bg-color);
                    color: var(--text-color);
                    padding: 20px;
                    transition: all 0.3s ease;
                }
                
                :root {
                    --bg-color: #ffffff;
                    --text-color: #333333;
                    --primary-color: #007AFF;
                    --secondary-color: #f0f0f0;
                    --border-color: #e0e0e0;
                }
                
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg-color: #1c1c1e;
                        --text-color: #ffffff;
                        --secondary-color: #2c2c2e;
                        --border-color: #38383a;
                    }
                }
                
                .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 20px;
                    padding-bottom: 15px;
                    border-bottom: 1px solid var(--border-color);
                }
                
                .header h1 {
                    font-size: 24px;
                    font-weight: 600;
                }
                
                .add-btn {
                    background: var(--primary-color);
                    color: white;
                    border: none;
                    padding: 8px 16px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 14px;
                    transition: opacity 0.2s;
                }
                
                .add-btn:hover {
                    opacity: 0.8;
                }
                
                .updates-container {
                    max-height: 500px;
                    overflow-y: auto;
                }
                
                .update-item {
                    background: var(--secondary-color);
                    border-radius: 8px;
                    padding: 15px;
                    margin-bottom: 10px;
                    border: 1px solid var(--border-color);
                }
                
                .update-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 8px;
                }
                
                .update-title {
                    font-weight: 600;
                    font-size: 16px;
                }
                
                .update-date {
                    font-size: 12px;
                    color: #666;
                }
                
                .update-content {
                    font-size: 14px;
                    line-height: 1.4;
                }
                
                .update-actions {
                    display: flex;
                    gap: 8px;
                    margin-top: 10px;
                }
                
                .action-btn {
                    background: none;
                    border: 1px solid var(--border-color);
                    padding: 4px 8px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 12px;
                    transition: background 0.2s;
                }
                
                .action-btn:hover {
                    background: var(--border-color);
                }
                
                .empty-state {
                    text-align: center;
                    padding: 40px 20px;
                    color: #666;
                }
                
                .empty-state h3 {
                    margin-bottom: 10px;
                    font-weight: 500;
                }
                
                .form-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0, 0, 0, 0.5);
                    display: none;
                    align-items: center;
                    justify-content: center;
                    z-index: 1000;
                }
                
                .form-container {
                    background: var(--bg-color);
                    border-radius: 12px;
                    padding: 24px;
                    width: 90%;
                    max-width: 400px;
                    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
                }
                
                .form-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 20px;
                }
                
                .form-title {
                    font-size: 18px;
                    font-weight: 600;
                }
                
                .close-btn {
                    background: none;
                    border: none;
                    font-size: 20px;
                    cursor: pointer;
                    color: #666;
                }
                
                .form-group {
                    margin-bottom: 16px;
                }
                
                .form-label {
                    display: block;
                    margin-bottom: 6px;
                    font-weight: 500;
                }
                
                .form-input, .form-textarea {
                    width: 100%;
                    padding: 8px 12px;
                    border: 1px solid var(--border-color);
                    border-radius: 6px;
                    background: var(--bg-color);
                    color: var(--text-color);
                    font-size: 14px;
                }
                
                .form-textarea {
                    resize: vertical;
                    min-height: 80px;
                }
                
                .form-actions {
                    display: flex;
                    gap: 10px;
                    justify-content: flex-end;
                }
                
                .btn-secondary {
                    background: var(--secondary-color);
                    color: var(--text-color);
                    border: 1px solid var(--border-color);
                }
                
                .btn-primary {
                    background: var(--primary-color);
                    color: white;
                    border: none;
                }
                
                .btn {
                    padding: 8px 16px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 14px;
                    transition: opacity 0.2s;
                }
                
                .btn:hover {
                    opacity: 0.8;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Weekly Updates</h1>
                <button class="add-btn" onclick="showAddForm()">+ Add Update</button>
            </div>
            
            <div class="updates-container" id="updatesContainer">
                <div class="empty-state">
                    <h3>No updates yet</h3>
                    <p>Click "Add Update" to get started</p>
                </div>
            </div>
            
            <div class="form-overlay" id="formOverlay">
                <div class="form-container">
                    <div class="form-header">
                        <h2 class="form-title" id="formTitle">Add Weekly Update</h2>
                        <button class="close-btn" onclick="hideForm()">&times;</button>
                    </div>
                    <form id="updateForm">
                        <div class="form-group">
                            <label class="form-label" for="updateTitle">Title</label>
                            <input type="text" id="updateTitle" class="form-input" required>
                        </div>
                        <div class="form-group">
                            <label class="form-label" for="updateContent">Content</label>
                            <textarea id="updateContent" class="form-textarea" required></textarea>
                        </div>
                        <div class="form-actions">
                            <button type="button" class="btn btn-secondary" onclick="hideForm()">Cancel</button>
                            <button type="submit" class="btn btn-primary">Save</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <script>
                let updates = [];
                let editingIndex = -1;
                
                // Load updates from native app
                function loadUpdates() {
                    window.webkit.messageHandlers.nativeApp.postMessage({
                        action: 'getUpdates'
                    });
                }
                
                // Display updates
                function displayUpdates() {
                    const container = document.getElementById('updatesContainer');
                    
                    if (updates.length === 0) {
                        container.innerHTML = `
                            <div class="empty-state">
                                <h3>No updates yet</h3>
                                <p>Click "Add Update" to get started</p>
                            </div>
                        `;
                        return;
                    }
                    
                    container.innerHTML = updates.map((update, index) => `
                        <div class="update-item">
                            <div class="update-header">
                                <div class="update-title">${update.title}</div>
                                <div class="update-date">${new Date(update.date).toLocaleDateString()}</div>
                            </div>
                            <div class="update-content">${update.content}</div>
                            <div class="update-actions">
                                <button class="action-btn" onclick="editUpdate(${index})">Edit</button>
                                <button class="action-btn" onclick="deleteUpdate(${index})">Delete</button>
                            </div>
                        </div>
                    `).join('');
                }
                
                // Show add form
                function showAddForm() {
                    editingIndex = -1;
                    document.getElementById('formTitle').textContent = 'Add Weekly Update';
                    document.getElementById('updateForm').reset();
                    document.getElementById('formOverlay').style.display = 'flex';
                }
                
                // Show edit form
                function editUpdate(index) {
                    editingIndex = index;
                    const update = updates[index];
                    document.getElementById('formTitle').textContent = 'Edit Weekly Update';
                    document.getElementById('updateTitle').value = update.title;
                    document.getElementById('updateContent').value = update.content;
                    document.getElementById('formOverlay').style.display = 'flex';
                }
                
                // Hide form
                function hideForm() {
                    document.getElementById('formOverlay').style.display = 'none';
                }
                
                // Delete update
                function deleteUpdate(index) {
                    if (confirm('Are you sure you want to delete this update?')) {
                        updates.splice(index, 1);
                        displayUpdates();
                        saveUpdates();
                    }
                }
                
                // Save updates to native app
                function saveUpdates() {
                    window.webkit.messageHandlers.nativeApp.postMessage({
                        action: 'saveUpdates',
                        updates: updates
                    });
                }
                
                // Handle form submission
                document.getElementById('updateForm').addEventListener('submit', function(e) {
                    e.preventDefault();
                    
                    const title = document.getElementById('updateTitle').value;
                    const content = document.getElementById('updateContent').value;
                    
                    if (editingIndex === -1) {
                        // Add new update
                        updates.unshift({
                            title: title,
                            content: content,
                            date: new Date().toISOString()
                        });
                    } else {
                        // Edit existing update
                        updates[editingIndex] = {
                            ...updates[editingIndex],
                            title: title,
                            content: content
                        };
                    }
                    
                    displayUpdates();
                    saveUpdates();
                    hideForm();
                });
                
                // Handle messages from native app
                function handleNativeMessage(message) {
                    if (message.action === 'loadUpdates') {
                        updates = message.updates || [];
                        displayUpdates();
                    }
                }
                
                // Initialize
                document.addEventListener('DOMContentLoaded', function() {
                    loadUpdates();
                });
                
                // Expose function for native app
                window.handleNativeMessage = handleNativeMessage;
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    // Focus the text area for quick note entry
    func focusTextArea() {
        print("=== FOCUSING TEXT AREA ===")
        let focusScript = """
            (function() {
                const textarea = document.getElementById('noteContent');
                if (textarea) {
                    textarea.focus();
                    textarea.select();
                    console.log('Text area focused successfully');
                } else {
                    console.log('Text area not found');
                }
            })();
        """
        
        webView.evaluateJavaScript(focusScript) { result, error in
            if let error = error {
                print("Error focusing text area: \(error)")
            } else {
                print("Text area focus script executed successfully")
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("=== RECEIVED MESSAGE FROM WEB VIEW ===")
        print("Message name: \(message.name)")
        print("Message body: \(message.body)")
        
        switch message.name {
        case "console":
            // Handle console messages from JavaScript
            if let body = message.body as? [String: Any],
               let level = body["level"] as? String,
               let messageText = body["message"] as? String {
                print("JS CONSOLE [\(level)]: \(messageText)")
            } else if let messageText = message.body as? String {
                print("JS CONSOLE: \(messageText)")
            }
            
        case "nativeApp":
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { 
                print("Invalid message format")
                return 
            }
            
            print("Native app action: \(action)")
            
            switch action {
            case "getUpdates":
                let context = (NSApp.delegate as! AppDelegate).persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                
                do {
                    let notes = try context.fetch(fetchRequest)
                    let updates = notes.map { [
                        "content": $0.content ?? "",
                        "createdAt": ISO8601DateFormatter().string(from: $0.createdAt ?? Date())
                    ] }
                    
                    DispatchQueue.main.async {
                        self.webView.evaluateJavaScript("handleNativeMessage({action: 'loadUpdates', updates: \(updates)})")
                    }
                } catch {
                    print("Error fetching notes: \(error)")
                }
            
            case "saveUpdates":
                if let updates = body["updates"] as? [[String: Any]] {
                    let context = (NSApp.delegate as! AppDelegate).persistentContainer.viewContext
                    // Delete all existing notes
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    _ = try? context.execute(deleteRequest)
                    // Insert new notes
                    for update in updates {
                        guard let content = update["content"] as? String,
                              let createdAtStr = update["createdAt"] as? String,
                              let createdAt = ISO8601DateFormatter().date(from: createdAtStr) else { continue }
                        let note = Note(context: context)
                        note.content = content
                        note.createdAt = createdAt
                    }
                    try? context.save()
                }
            
            case "closePopover":
                // Close the popover
                DispatchQueue.main.async {
                    self.appDelegate?.popover.performClose(nil)
                }
            
            case "openPopover":
                // Open the popover
                DispatchQueue.main.async {
                    if let button = self.appDelegate?.statusItem.button {
                        self.appDelegate?.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                    }
                }
            
            default:
                break
            }
        
        default:
            break
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Web app loaded successfully
        print("=== WEB VIEW DID FINISH LOADING ===")
        print("Navigation: \(navigation)")
        print("URL: \(webView.url?.absoluteString ?? "nil")")
        
        // Test if JavaScript is working by evaluating a simple script
        webView.evaluateJavaScript("console.log('JavaScript is working from native app!'); alert('JavaScript is working!');") { result, error in
            if let error = error {
                print("JavaScript evaluation error: \(error)")
            } else {
                print("JavaScript evaluation successful: \(result ?? "nil")")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("=== WEB VIEW NAVIGATION FAILED ===")
        print("Navigation: \(navigation)")
        print("Error: \(error.localizedDescription)")
        print("Error details: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("=== WEB VIEW PROVISIONAL NAVIGATION FAILED ===")
        print("Navigation: \(navigation)")
        print("Error: \(error.localizedDescription)")
        print("Error details: \(error)")
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("=== WEB VIEW STARTED PROVISIONAL NAVIGATION ===")
        print("Navigation: \(navigation)")
        print("URL: \(webView.url?.absoluteString ?? "nil")")
    }
    
    // Check and generate auto-summary if conditions are met
    func checkAndGenerateAutoSummary() {
        print("🤖 Checking auto-summary conditions...")
        let checkScript = """
            (function() {
                // Check if auto-summary is enabled and there are updates
                const autoSummaryEnabled = localStorage.getItem('autoSummaryEnabled') !== 'false';
                const updates = JSON.parse(localStorage.getItem('updates') || '[]');
                
                console.log('Auto-summary enabled:', autoSummaryEnabled);
                console.log('Number of updates:', updates.length);
                
                if (autoSummaryEnabled && updates.length > 0) {
                    console.log('🤖 Auto-generating weekly summary');
                    if (typeof generateSummary === 'function') {
                        generateSummary();
                    } else {
                        console.log('generateSummary function not found');
                    }
                } else {
                    console.log('Auto-summary conditions not met');
                }
            })();
        """
        
        webView.evaluateJavaScript(checkScript) { result, error in
            if let error = error {
                print("Error checking auto-summary: \(error)")
            } else {
                print("Auto-summary check completed")
            }
        }
    }
}

