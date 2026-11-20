//
//  DashboardViewController.swift
//  ExpensesTracker
//
//  Port of dashboardFragment — income total, expense total, balance, two horizontal strips of recent
//  records, and the expanding add button.
//
//  The Android original was 500 lines, most of it duplication: two near-identical Firebase listeners,
//  two near-identical RecyclerView setups, two ViewHolder classes with the same three setters, and two
//  copies of the add dialog differing only in which database reference they wrote to. All of that
//  collapses into a `RecordKind` loop here, which is the single biggest reason this file is a third the
//  size without losing a feature.
//
//  Two behaviours are fixed rather than ported:
//
//    * The balance was computed by reading the two total *labels* back out of the UI and parsing them,
//      stripping the comma separators it had just inserted. It reads the numbers here.
//
//    * The FAB's two children were animated in and out with `startAnimation` but their `isClickable`
//      state was the only thing actually gating them, so they stayed on screen and tappable after the
//      close animation finished. A UIMenu has none of that bookkeeping to get wrong.
//

import UIKit
import NewRelic

final class DashboardViewController: InstrumentedViewController {

    override var viewName: ViewName { .dashboard }

    private let store: LedgerStore
    private var observation: Task<Void, Never>?

    private let incomeTotalLabel = UILabel()
    private let expenseTotalLabel = UILabel()
    private let balanceLabel = UILabel()

    private lazy var incomeStrip = makeStrip(for: .income)
    private lazy var expenseStrip = makeStrip(for: .expense)

    private let addButton = UIButton(configuration: .filled())

    init(store: LedgerStore) {
        self.store = store
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

        // Android attached a ValueEventListener per database reference. One stream covers both, and it
        // is cancelled with the screen instead of leaking as the fragment's listeners did.
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
        let balanceCard = makeBalanceCard()

        let content = UIStackView(arrangedSubviews: [
            balanceCard,
            sectionHeader("Recent income"),
            incomeStrip,
            sectionHeader("Recent expenses"),
            expenseStrip
        ])
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        view.addSubview(scroll)

        configureAddButton()
        view.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -96),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    /// fragment_blank.xml's header: the two totals side by side with the balance beneath.
    private func makeBalanceCard() -> UIView {
        balanceLabel.font = .systemFont(ofSize: 38, weight: .heavy)
        balanceLabel.textColor = .white
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.minimumScaleFactor = 0.6
        balanceLabel.accessibilityIdentifier = "dashboard.balance"

        let balanceCaption = UILabel()
        balanceCaption.text = "BALANCE"
        balanceCaption.font = .systemFont(ofSize: 12, weight: .semibold)
        balanceCaption.textColor = Theme.accentGreen

        let totals = UIStackView(arrangedSubviews: [
            totalColumn(caption: "INCOME", label: incomeTotalLabel, color: Theme.accentGreen),
            totalColumn(caption: "EXPENSE", label: expenseTotalLabel, color: .systemPink)
        ])
        totals.axis = .horizontal
        totals.distribution = .fillEqually
        totals.spacing = 12

        let stack = UIStackView(arrangedSubviews: [balanceCaption, balanceLabel, totals])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(16, after: balanceLabel)

        return Theme.card(stack)
    }

    private func totalColumn(caption: String, label: UILabel, color: UIColor) -> UIStackView {
        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.65)

        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = color
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.accessibilityIdentifier = "dashboard.total.\(caption.lowercased())"

        let stack = UIStackView(arrangedSubviews: [captionLabel, label])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = Theme.home
        return label
    }

    /// A horizontal strip of tiles, newest first — the Android layout managers set `reverseLayout` and
    /// `stackFromEnd` to achieve the same ordering.
    private func makeStrip(for kind: RecordKind) -> RecordStripView {
        let strip = RecordStripView(kind: kind)
        strip.onSelect = { [weak self] record in
            self?.presentEditor(for: record, kind: kind)
        }
        return strip
    }

    /// The Android FAB expanded into two more FABs with labels. A UIMenu offers the same two choices
    /// without the animation bookkeeping that version got wrong.
    private func configureAddButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "plus",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        configuration.baseBackgroundColor = Theme.home
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        addButton.configuration = configuration
        addButton.accessibilityIdentifier = "dashboard.add"

        addButton.menu = UIMenu(children: [
            UIAction(title: "Add income",
                     image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
                self?.presentEditor(for: nil, kind: .income)
            },
            UIAction(title: "Add expense",
                     image: UIImage(systemName: "arrow.up.circle")) { [weak self] _ in
                self?.presentEditor(for: nil, kind: .expense)
            }
        ])
        addButton.showsMenuAsPrimaryAction = true

        addButton.addAction(UIAction { _ in
            NewRelic.logDebug("Dashboard: add menu opened")
        }, for: .menuActionTriggered)
    }

    // MARK: - Data

    private func refresh() {
        incomeTotalLabel.text = NumberFormatting.format(store.total(for: .income))
        expenseTotalLabel.text = NumberFormatting.format(store.total(for: .expense))
        balanceLabel.text = NumberFormatting.formatBalance(store.balance)

        incomeStrip.records = store.records(for: .income).reversed()
        expenseStrip.records = store.records(for: .expense).reversed()
    }

    // MARK: - Editing

    private func presentEditor(for record: LedgerRecord?, kind: RecordKind) {
        let editor = RecordEditorViewController(kind: kind, existing: record, store: store)
        present(UINavigationController(rootViewController: editor), animated: true)
    }
}
