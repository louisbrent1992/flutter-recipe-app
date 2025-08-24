import receive_sharing_intent
import os.log
import UIKit

class ShareViewController: RSIShareViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad - Recipe sharing extension initialized", type: .info)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let items = self.extensionContext?.inputItems as? [NSExtensionItem] ?? []
        os_log("[ShareExtension] viewDidAppear - Processing %d input items", type: .info, items.count)
        
        for (i, item) in items.enumerated() {
            let attachments = item.attachments ?? []
            os_log("[ShareExtension] Item %d has %d attachments", type: .info, i, attachments.count)
            
            for (j, provider) in attachments.enumerated() {
                let typeIdentifiers = provider.registeredTypeIdentifiers
                os_log("[ShareExtension] Attachment %d type identifiers: %@", type: .info, j, typeIdentifiers.joined(separator: ", "))
                
                // Check if this is a URL or text that could contain a recipe
                for typeId in typeIdentifiers {
                    if typeId.contains("url") || typeId.contains("text") {
                        os_log("[ShareExtension] Found recipe-shareable content: %@", type: .info, typeId)
                        
                        // Try to load the content to see what we're actually sharing
                        if typeId.contains("url") {
                            provider.loadItem(forTypeIdentifier: typeId, options: nil) { (url, error) in
                                if let url = url as? URL {
                                    os_log("[ShareExtension] Sharing URL: %@", type: .info, url.absoluteString)
                                } else if let error = error {
                                    os_log("[ShareExtension] Error loading URL: %@", type: .error, error.localizedDescription)
                                }
                            }
                        } else if typeId.contains("text") {
                            provider.loadItem(forTypeIdentifier: typeId, options: nil) { (text, error) in
                                if let text = text as? String {
                                    os_log("[ShareExtension] Sharing text: %@", type: .info, String(text.prefix(100)))
                                } else if let error = error {
                                    os_log("[ShareExtension] Error loading text: %@", type: .error, error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override func shouldAutoRedirect() -> Bool {
        os_log("[ShareExtension] shouldAutoRedirect called - returning false for manual handling", type: .info)
        return false
    }
}