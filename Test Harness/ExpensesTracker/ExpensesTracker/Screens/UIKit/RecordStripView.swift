//
//  RecordStripView.swift
//  ExpensesTracker
//
//  The dashboard's horizontal strip of record tiles — one of the two RecyclerViews in
//  fragment_blank.xml, wired up twice in dashboardFragment with a HorizontalSpaceItemDecoration for
//  spacing.
//
//  A compositional layout with `interGroupSpacing` replaces the decoration class outright, and an empty
//  state replaces the blank gap Android showed when a ledger had no records yet.
//

import UIKit

final class RecordStripView: UIView {

    var onSelect: ((LedgerRecord) -> Void)?

    var records: [LedgerRecord] = [] {
        didSet {
            emptyLabel.isHidden = !records.isEmpty
            collectionView.isHidden = records.isEmpty
            collectionView.reloadData()
        }
    }

    private let kind: RecordKind
    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()

    init(kind: RecordKind) {
        self.kind = kind

        var configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(150),
                heightDimension: .absolute(96)
            ))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(150),
                                                   heightDimension: .absolute(96)),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 10
            return section
        }, configuration: configuration)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(RecordTileCell.self,
                                forCellWithReuseIdentifier: RecordTileCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.accessibilityIdentifier = "dashboard.strip.\(kind.rawValue)"

        emptyLabel.text = "No \(kind.displayName.lowercased()) recorded yet"
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .tertiaryLabel
        emptyLabel.isHidden = true

        for subview in [collectionView, emptyLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 96),

            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),

            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RecordStripView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        records.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecordTileCell.reuseIdentifier,
                                                     for: indexPath)
        (cell as? RecordTileCell)?.configure(with: records[indexPath.item], kind: kind)
        return cell
    }
}

extension RecordStripView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        onSelect?(records[indexPath.item])
    }
}
