//
//  CrashTestUIKitViewController.swift
//  NRTestApp
//
//  A menu of UIKit / Foundation / Objective-C crashes for validating
//  New Relic crash reporting. Every row crashes the app immediately on tap.
//
//  NOTE: New Relic records a crash and uploads it on the NEXT launch, and the
//  Xcode debugger intercepts signals first. To validate NR capture, run the app
//  detached from the debugger (or continue past it), let it die, then relaunch.
//

#if os(iOS)
import UIKit

class CrashTestUIKitViewController: UIViewController {

    private struct CrashRow {
        let title: String
        let detail: String
        let action: () -> Void
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private lazy var rows: [CrashRow] = makeRows()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Crashes"
        view.backgroundColor = .systemBackground
        setupTableView()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "crashCell")
        tableView.tableHeaderView = makeBanner()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeBanner() -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.text = "⚠️ Each row crashes the app instantly. New Relic uploads the crash on the NEXT launch — run detached from the Xcode debugger, let it die, then relaunch."
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 90))
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])

        // Size the header to fit its content against the table's width.
        container.setNeedsLayout()
        container.layoutIfNeeded()
        let width = view.bounds.width
        let height = container.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        ).height
        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        return container
    }

    private func makeRows() -> [CrashRow] {
        return [
            CrashRow(title: "Unrecognized selector",
                     detail: "NSInvalidArgumentException · SIGABRT",
                     action: { CrashTriggers.crashUnrecognizedSelector() }),
            CrashRow(title: "NSArray index out of bounds",
                     detail: "NSRangeException · SIGABRT",
                     action: { CrashTriggers.crashArrayIndexOutOfBounds() }),
            CrashRow(title: "Insert nil into NSMutableArray",
                     detail: "NSInvalidArgumentException · SIGABRT",
                     action: { CrashTriggers.crashInsertNilIntoArray() }),
            CrashRow(title: "Mutate array while enumerating",
                     detail: "NSGenericException · SIGABRT",
                     action: { CrashTriggers.crashMutateWhileEnumerating() }),
            CrashRow(title: "Remove unregistered KVO observer",
                     detail: "NSRangeException · SIGABRT",
                     action: { CrashTriggers.crashRemoveUnregisteredKVOObserver() }),
            CrashRow(title: "Uncaught NSException",
                     detail: "@throw · SIGABRT",
                     action: { CrashTriggers.crashUncaughtException() }),
            CrashRow(title: "Invalid UITableView batch update",
                     detail: "NSInternalInconsistencyException · SIGABRT",
                     action: { [weak self] in self?.crashInvalidTableUpdate() }),
            CrashRow(title: "UI update from background thread",
                     detail: "Main Thread Checker (debug builds)",
                     action: { [weak self] in self?.crashBackgroundThreadUI() })
        ]
    }

    // MARK: - UIKit-object crashes (Swift side)

    private func crashInvalidTableUpdate() {
        // The data source still reports `rows.count`, so inserting a row the
        // model doesn't have raises NSInternalInconsistencyException.
        tableView.performBatchUpdates({
            tableView.insertRows(at: [IndexPath(row: 999, section: 0)], with: .automatic)
        })
    }

    private func crashBackgroundThreadUI() {
        DispatchQueue.global().async {
            // Touching UIKit off the main thread trips the Main Thread Checker.
            self.view.backgroundColor = .red
            self.tableView.reloadData()
        }
    }
}

extension CrashTestUIKitViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "crashCell", for: indexPath)
        let row = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.detail
        content.textProperties.color = .systemRed
        cell.contentConfiguration = content
        cell.accessibilityIdentifier = "crash-\(indexPath.row)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        rows[indexPath.row].action()
    }
}
#endif
