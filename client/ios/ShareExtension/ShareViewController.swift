import receive_sharing_intent
import os.log
import UIKit

class ShareViewController: RSIShareViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad", type: .info)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let items = self.extensionContext?.inputItems as? [NSExtensionItem] ?? []
        os_log("[ShareExtension] viewDidAppear inputItems=%d", type: .info, items.count)
        
        for (i, item) in items.enumerated() {
            let attachments = item.attachments ?? []
            os_log("[ShareExtension] item %d attachments=%d", type: .info, i, attachments.count)
            
            for (j, provider) in attachments.enumerated() {
                let typeIdentifiers = provider.registeredTypeIdentifiers
                os_log("[ShareExtension] item %d attachment %d UTIs=%@", type: .info, i, j, typeIdentifiers.joined(separator: ", "))
                
                // Log specific content types for debugging
                for typeId in typeIdentifiers {
                    if typeId.contains("url") || typeId.contains("text") {
                        os_log("[ShareExtension] Found shareable content type: %@", type: .info, typeId)
                    }
                }
            }
        }
    }

    override func shouldAutoRedirect() -> Bool {
        os_log("[ShareExtension] shouldAutoRedirect called", type: .info)
        return false
    }
}