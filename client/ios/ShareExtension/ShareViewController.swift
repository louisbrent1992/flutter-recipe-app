import receive_sharing_intent
import os.log
import UIKit

class ShareViewController: RSIShareViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad", type: .info)
    }

    // Let the plugin store the shared content in the App Group and
    // immediately redirect to the host app. Custom processing here
    // can prevent the redirect and leave the overlay visible.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}