
import UIKit

final class CommentBlacklistViewController: UITableViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		return Settings.commentAuthorBlacklist.isEmpty ? 0 : 1
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return Settings.commentAuthorBlacklist.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "UsernameCell", for: indexPath)
		cell.textLabel?.text = Settings.commentAuthorBlacklist[indexPath.row]
		return cell
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			var blackList = Settings.commentAuthorBlacklist
			blackList.remove(at: indexPath.row)
			Settings.commentAuthorBlacklist = blackList
			if blackList.isEmpty { // last delete
				tableView.deleteSections(IndexSet(integer: 0), with: .fade)
			} else {
				tableView.deleteRows(at: [indexPath], with: .fade)
			}
		}
	}

	@IBAction private func addSelected() {

		let a = UIAlertController(title: "Block commenter",
			message: "Enter the username of the poster whose comments you don't want to be notified about",
			preferredStyle: .alert)

		a.addTextField { textField in
			textField.placeholder = "Username"
		}
		a.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		a.addAction(UIAlertAction(title: "Block", style: .default, handler: { action in

			if let tf = a.textFields?.first, let n = tf.text?.trim {

				let name = n.hasPrefix("@") ? String(n.dropFirst()) : n

                DispatchQueue.main.async { [weak self] in
                    guard let S = self else { return }
					if !name.isEmpty && !Settings.commentAuthorBlacklist.contains(name) {
						var blackList = Settings.commentAuthorBlacklist
						blackList.append(name)
						Settings.commentAuthorBlacklist = blackList
						let ip = IndexPath(row: blackList.count-1, section: 0)
						if blackList.count == 1 { // first insert
							S.tableView.insertSections(IndexSet(integer: 0), with: .fade)
						} else {
							S.tableView.insertRows(at: [ip], with: .fade)
						}
					}
				}
			}
		}))

		present(a, animated: true)
	}
}
