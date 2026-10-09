//
//  LedgerListViewController.swift
//  ExpensesTracker
//
//  The shared body of incomeFragment and expenseFragment: a total at the top, a newest-first list of
//  records beneath, a tap on a row opening the update/delete editor, and a button for the New Relic test
//  menu.
//
//  On Android these were two separate files — 771 lines and 319 — that differed in three ways: the
//  Firebase path they read, the colour of the amount, and which of them carried the big test menu (income
//  had all thirteen options; expense had a single button that fired a handled exception and a custom
//  event). Everything else, including both ViewHolder classes and both update dialogs, was duplicated
//  verbatim.
//
//  So this holds the shared behaviour and takes the ledger kind as a parameter. IncomeViewController and
//  ExpenseViewController are what remains once the duplication is gone: a `kind`, a `viewName`, and in the
//  income case the full test menu.
//

import UIKit
import NewRelic

class LedgerListViewController: InstrumentedViewController {

    let kind: RecordKind
    let store: LedgerStore

    override var viewName: ViewName { kind.viewName }
    override var viewAttributes: [String: Any] {
        ["ledger": kind.rawValue, "record_count": store.records(for: kind).count]
    }

    private let totalLabel = UILabel()
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    private var observation: Task<Void, Never>?

    private var records: [LedgerRecord] = []

    init(kind: RecordKind, store: LedgerStore) {
        self.kind = kind
        self.store = store

        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.backgroundColor = .clear
        configuration.showsSeparators = false
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observation?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        layout()

        observation = Task { [weak self] in
            guard let changes = self?.store.changes else { return }
            for await _ in changes {
                self?.refresh()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    // MARK: - Layout

    private func layout() {
        let caption = UILabel()
        caption.text = "TOTAL \(kind.displayName.uppercased())"
        caption.font = .systemFont(ofSize: 12, weight: .semibold)
        caption.textColor = UIColor.white.withAlphaComponent(0.65)

        totalLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        totalLabel.textColor = kind == .income ? Theme.accentGreen : .systemPink
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.6
        totalLabel.accessibilityIdentifier = "\(kind.rawValue).total"

        let totalStack = UIStackView(arrangedSubviews: [caption, totalLabel])
        totalStack.axis = .vertical
        totalStack.spacing = 4
        let totalCard = Theme.card(totalStack)

        collectionView.backgroundColor = .clear
        collectionView.register(RecordRowCell.self,
                                forCellWithReuseIdentifier: RecordRowCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.accessibilityIdentifier = "\(kind.rawValue).list"

        emptyLabel.text = "Nothing here yet. Add a record from the Dashboard."
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .tertiaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true

        for subview in [totalCard, collectionView, emptyLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let testMenuButton = makeTestMenuButton()
        testMenuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(testMenuButton)

        NSLayoutConstraint.activate([
            totalCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            totalCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            totalCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: totalCard.bottomAnchor, constant: 12),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 40),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            testMenuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            testMenuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                   constant: -20),
            testMenuButton.widthAnchor.constraint(equalToConstant: 60),
            testMenuButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    /// Android put a FAB on both list fragments for this: `fab_crash_test` on income opened the full
    /// thirteen-option menu, `fab_test_exception` on expense fired one handled exception directly.
    /// Subclasses decide which by overriding `presentTestMenu()`.
    private func makeTestMenuButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "ladybug",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
        configuration.baseBackgroundColor = Theme.card
        configuration.baseForegroundColor = Theme.accentGreen
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "\(kind.rawValue).testmenu"
        button.addAction(UIAction { [weak self] _ in
            self?.presentTestMenu()
        }, for: .touchUpInside)
        return button
    }

    /// Overridden by both subclasses.
    func presentTestMenu() {}

    // MARK: - Data

    private func refresh() {
        // Newest first, as the Android layout managers arranged with reverseLayout + stackFromEnd.
        records = store.records(for: kind).reversed()
        totalLabel.text = NumberFormatting.format(store.total(for: kind))
        emptyLabel.isHidden = !records.isEmpty
        collectionView.reloadData()
    }
}

// MARK: - Collection view

extension LedgerListViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        records.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecordRowCell.reuseIdentifier,
                                                     for: indexPath)
        (cell as? RecordRowCell)?.configure(with: records[indexPath.item], kind: kind)
        return cell
    }
}

extension LedgerListViewController: UICollectionViewDelegate {

    /// Android's row tap opened the update dialog, having first stashed the tapped record's fields in
    /// four mutable fields on the fragment and its key in a fifth — which meant a second tap before the
    /// dialog appeared could update the wrong record. The record is passed directly here.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let record = records[indexPath.item]
        NewRelic.logDebug("\(viewName.rawValue): user tapped record \(record.purpose)")

        let editor = RecordEditorViewController(kind: kind, existing: record, store: store)
        present(UINavigationController(rootViewController: editor), animated: true)
    }
}
