
import SafariServices

final class QuickStartViewController: UIViewController, UITextFieldDelegate {

	@IBOutlet private weak var testButton: UIButton!
	@IBOutlet private var otherViews: [UIView]!
	@IBOutlet private weak var spinner: UIActivityIndicatorView!
	@IBOutlet private weak var feedback: UILabel!
	@IBOutlet private weak var skip: UIBarButtonItem!
	@IBOutlet private weak var importer: UIBarButtonItem!
	@IBOutlet private weak var link: UIButton!

	private let newServer = ApiServer.allApiServers(in: DataManager.main).first!
	private var token = ""
	private var checkTimer: Timer?
	private var importExport: ImportExport!

    override func viewDidLoad() {
        super.viewDidLoad()
		importExport = ImportExport(parent: self)
		normalMode()
    }

	@IBAction private func importSelected(_ sender: UIBarButtonItem) {
		importExport.importSelected(sender: sender)
	}

	@IBAction private func skipSelected(_ sender: UIBarButtonItem) {
		dismiss(animated: true)
	}

	@IBAction private func openGitHubSelected(_ sender: UIButton) {
		let s = SFSafariViewController(url: URL(string: "https://github.com/settings/tokens/new")!)
		s.view.tintColor = self.view.tintColor
		self.present(s, animated: true)
	}

	@IBAction private func testSelected(_ sender: UIButton) {
		testMode()
		API.testApi(to: newServer) { [weak self] error in
			guard let s = self else { return }
			if let e = error {
				showMessage("Testing the token failed - please check that you have pasted your token correctly", e.localizedDescription)
				s.normalMode()
			} else {
				s.feedback.text = "\nFetching your watchlist. This will take a moment…"
				Settings.lastSuccessfulRefresh = nil
				app.startRefreshIfItIsDue()
				s.checkTimer = Timer(repeats: true, interval: 1) {
					s.checkRefreshDone()
				}
			}
		}
	}

	private func checkRefreshDone() {
        if API.isRefreshing {
			feedback.text = "\nFetching your watchlist. This will take a moment…"
		} else {
			checkTimer = nil
			if newServer.lastSyncSucceeded {
				dismiss(animated: true) {
					popupManager.masterController.resetView(becauseOfChanges: true)
					Settings.lastPreferencesTabSelected = 1 // repos
					popupManager.masterController.performSegue(withIdentifier: "showPreferences", sender: self)
					showMessage("Setup complete!", "This is the 'Repos' tab that displays your current GitHub watchlist. By default everything is hidden. Be sure to enable only the repos you need, in order to keep API (and data & battery) usage low.\n\nYou can tweak options & behaviour from the 'Advanced' tab. When you're done, just close this settings view from the top-left.\n\nTrailer has read-only access to your GitHub data, so feel free to experiment, you can't damage your data or settings on GitHub.")
				}
			} else {
				showMessage("Syncing with this server failed - please check that your network connection is working and that you have pasted your token correctly", nil)
				normalMode()
			}
		}
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		if string == "\n" {
			view.endEditing(false)
			return false
		}
		token = S(textField.text)
		if let r = Range(range, in: token) {
			token = token.replacingCharacters(in: r, with: string)
		}
		token = token.trim
		testButton.isEnabled = !token.isEmpty
		link.alpha = testButton.isEnabled ? 0.5 : 1.0
		return true
	}

	private func testMode() {
		view.endEditing(true)

		for v in otherViews {
			v.isHidden = true
		}
		skip.isEnabled = false
		importer.isEnabled = false
		spinner.startAnimating()
		feedback.text = "\nTesting the token…"

		newServer.authToken = token
		newServer.lastSyncSucceeded = true
	}

	private func normalMode() {
		feedback.text = "Quick Start"
		skip.isEnabled = true
		importer.isEnabled = true
		for v in otherViews {
			v.isHidden = false
		}
		spinner.stopAnimating()
	}
}
