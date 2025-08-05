import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    // Constants for content management
    private let maxContentSize = 1024 * 1024 // 1MB limit for shared content
    private let maxImageCompressionQuality: CGFloat = 0.6 // Reduced from 0.8 for smaller size
    
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
        var processedCount = 0
        let totalAttachments = countTotalAttachments()
        
        for item in extensionContext.inputItems {
            guard let inputItem = item as? NSExtensionItem else { continue }
            
            for attachment in inputItem.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (url, error) in
                        if let url = url as? URL {
                            sharedItems.append("URL: \(url.absoluteString)")
                        }
                        processedCount += 1
                        if processedCount >= totalAttachments {
                            self.processSharedItems(sharedItems)
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (text, error) in
                        if let text = text as? String {
                            sharedItems.append("TEXT: \(text)")
                        }
                        processedCount += 1
                        if processedCount >= totalAttachments {
                            self.processSharedItems(sharedItems)
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (image, error) in
                        if let image = image as? UIImage {
                            // Handle image data with size limits
                            if let imageData = self.processImageWithSizeLimit(image) {
                                let base64String = imageData.base64EncodedString()
                                sharedItems.append("IMAGE: data:image/jpeg;base64,\(base64String)")
                            }
                        }
                        processedCount += 1
                        if processedCount >= totalAttachments {
                            self.processSharedItems(sharedItems)
                        }
                    }
                } else {
                    // Handle other content types
                    processedCount += 1
                    if processedCount >= totalAttachments {
                        self.processSharedItems(sharedItems)
                    }
                }
            }
        }
        
        // If no items were processed, complete the request
        if totalAttachments == 0 {
            completeRequest()
        }
    }
    
    private func countTotalAttachments() -> Int {
        var count = 0
        for item in extensionContext?.inputItems ?? [] {
            guard let inputItem = item as? NSExtensionItem else { continue }
            count += inputItem.attachments?.count ?? 0
        }
        return count
    }
    
    private func processImageWithSizeLimit(_ image: UIImage) -> Data? {
        // Start with higher quality and reduce if needed
        var compressionQuality: CGFloat = maxImageCompressionQuality
        var imageData: Data?
        
        repeat {
            imageData = image.jpegData(compressionQuality: compressionQuality)
            compressionQuality -= 0.1
        } while (imageData?.count ?? 0) > maxContentSize && compressionQuality > 0.1
        
        return imageData
    }
    
    private func processSharedItems(_ items: [String]) {
        // Use a more reliable URL scheme - hardcode if known
        let urlScheme = "recipease" // More reliable than dynamic construction
        
        // Encode the shared content with better error handling
        let sharedContent = items.joined(separator: "\n")
        
        // Check content size before encoding
        let contentData = sharedContent.data(using: .utf8)
        if let data = contentData, data.count > maxContentSize {
            // Content too large, truncate or show error
            let truncatedContent = String(sharedContent.prefix(maxContentSize / 2))
            let encodedContent = truncatedContent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            createAndOpenURL(scheme: urlScheme, content: encodedContent, truncated: true)
        } else {
            let encodedContent = sharedContent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            createAndOpenURL(scheme: urlScheme, content: encodedContent, truncated: false)
        }
    }
    
    private func createAndOpenURL(scheme: String, content: String, truncated: Bool) {
        // Create the URL to open the main app
        if let url = URL(string: "\(scheme)://share?content=\(content)&truncated=\(truncated)") {
            // Open the main app on main thread
            DispatchQueue.main.async {
                let success = self.openURL(url)
                if !success {
                    // Fallback: try to open the main app without content
                    if let fallbackURL = URL(string: "\(scheme)://") {
                        _ = self.openURL(fallbackURL)
                    }
                }
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