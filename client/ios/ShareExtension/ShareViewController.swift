import receive_sharing_intent
import os.log
import UIKit

class ShareViewController: RSIShareViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad - Recipe sharing extension initialized", type: .info)
        
        // Immediately process any shared content to prevent "Post" behavior
        processSharedContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("[ShareExtension] viewDidAppear - Processing shared content", type: .info)
        
        // Process content again if it wasn't handled in viewDidLoad
        processSharedContent()
    }
    
    private func processSharedContent() {
        guard let extensionContext = self.extensionContext else {
            os_log("[ShareExtension] No extension context available", type: .error)
            return
        }
        
        let items = extensionContext.inputItems as? [NSExtensionItem] ?? []
        os_log("[ShareExtension] Processing %d input items", type: .info, items.count)
        
        for (i, item) in items.enumerated() {
            let attachments = item.attachments ?? []
            os_log("[ShareExtension] Item %d has %d attachments", type: .info, i, attachments.count)
            
            for (j, provider) in attachments.enumerated() {
                let typeIdentifiers = provider.registeredTypeIdentifiers
                os_log("[ShareExtension] Attachment %d type identifiers: %@", type: .info, j, typeIdentifiers.joined(separator: ", "))
                
                // Process URL content immediately
                if typeIdentifiers.contains("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (url, error) in
                        if let url = url as? URL {
                            os_log("[ShareExtension] Processing URL: %@", type: .info, url.absoluteString)
                            self?.handleRecipeURL(url)
                        } else if let error = error {
                            os_log("[ShareExtension] Error loading URL: %@", type: .error, error.localizedDescription)
                        }
                    }
                }
                
                // Process text content immediately
                if typeIdentifiers.contains("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (text, error) in
                        if let text = text as? String {
                            os_log("[ShareExtension] Processing text: %@", type: .info, String(text.prefix(100)))
                            self?.handleRecipeText(text)
                        } else if let error = error {
                            os_log("[ShareExtension] Error loading text: %@", type: .error, error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    private func handleRecipeURL(_ url: URL) {
        os_log("[ShareExtension] Handling recipe URL: %@", type: .info, url.absoluteString)
        
        // Use the receive_sharing_intent plugin to handle the URL
        // This should prevent the generic "Post" behavior
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func handleRecipeText(_ text: String) {
        os_log("[ShareExtension] Handling recipe text: %@", type: .info, String(text.prefix(100)))
        
        // Use the receive_sharing_intent plugin to handle the text
        // This should prevent the generic "Post" behavior
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func shouldAutoRedirect() -> Bool {
        os_log("[ShareExtension] shouldAutoRedirect called - returning true for immediate handling", type: .info)
        return true
    }
}