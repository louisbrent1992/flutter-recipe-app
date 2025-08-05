import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }
    
    private func handleSharedContent() {
        guard let extensionContext = extensionContext else {
            completeRequest()
            return
        }
        
        var sharedItems: [String] = []
        
        for item in extensionContext.inputItems {
            guard let inputItem = item as? NSExtensionItem else { continue }
            
            for attachment in inputItem.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (url, error) in
                        if let url = url as? URL {
                            sharedItems.append(url.absoluteString)
                        }
                        self.processSharedItems(sharedItems)
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (text, error) in
                        if let text = text as? String {
                            sharedItems.append(text)
                        }
                        self.processSharedItems(sharedItems)
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (image, error) in
                        if let image = image as? UIImage {
                            // Handle image data
                            if let imageData = image.jpegData(compressionQuality: 0.8) {
                                let base64String = imageData.base64EncodedString()
                                sharedItems.append("data:image/jpeg;base64,\(base64String)")
                            }
                        }
                        self.processSharedItems(sharedItems)
                    }
                }
            }
        }
        
        // If no items were processed, complete the request
        if sharedItems.isEmpty {
            completeRequest()
        }
    }
    
    private func processSharedItems(_ items: [String]) {
        // Use a more reliable URL scheme - hardcode if known
        let urlScheme = "recipease" // More reliable than dynamic construction
        
        // Encode the shared content
        let sharedContent = items.joined(separator: "\n")
        let encodedContent = sharedContent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Create the URL to open the main app
        if let url = URL(string: "\(urlScheme)://share?content=\(encodedContent)") {
            // Open the main app on main thread
            DispatchQueue.main.async {
                _ = self.openURL(url)
                self.completeRequest()
            }
        } else {
            completeRequest()
        }
    }
    
    @objc private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return true
            }
            responder = responder?.next
        }
        return false
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}