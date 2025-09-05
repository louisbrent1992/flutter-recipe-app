import receive_sharing_intent
import os.log
import UIKit

class ShareViewController: RSIShareViewController {
    private var containerView: UIView!
    private var titleLabel: UILabel!
    private var detailLabel: UILabel!
    private var activity: UIActivityIndicatorView!
    private var openButton: UIButton!
    private var cancelButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("[ShareExtension] viewDidLoad", type: .info)
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Give the plugin a short moment to persist the shared payload
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.activity.stopAnimating()
            self.detailLabel.text = "Ready to import into Recipease"
            self.openButton.isEnabled = true
            self.openButton.alpha = 1.0
        }
    }

    // Disable auto-redirect; we show an overlay and let the user open the app explicitly
    override func shouldAutoRedirect() -> Bool {
        return false
    }

    @objc private func handleOpenTapped() {
        // Use the plugin's custom scheme to open the host app so the stored
        // media is delivered via ReceiveSharingIntent.getInitialMedia in Flutter
        let bundleId = (Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) ?? ""
        let scheme = "ShareMedia-\(bundleId)"
        if let url = URL(string: "\(scheme)://") {
            os_log("[ShareExtension] Opening host app via %{public}@", type: .info, scheme)
            self.extensionContext?.open(url, completionHandler: { _ in })
        }
        // Close the extension UI
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func handleCancelTapped() {
        self.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Importing Recipe"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        detailLabel = UILabel()
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.text = "Preparing shared content..."
        detailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = UIColor.secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        activity = UIActivityIndicatorView(style: .medium)
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.startAnimating()

        openButton = UIButton(type: .system)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.setTitle("Open in Recipease", for: .normal)
        openButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        openButton.isEnabled = false
        openButton.alpha = 0.6
        openButton.addTarget(self, action: #selector(handleOpenTapped), for: .touchUpInside)

        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)

        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(detailLabel)
        containerView.addSubview(activity)
        containerView.addSubview(openButton)
        containerView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            activity.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 16),
            activity.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            openButton.topAnchor.constraint(equalTo: activity.bottomAnchor, constant: 20),
            openButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            openButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            cancelButton.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 8),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }
}