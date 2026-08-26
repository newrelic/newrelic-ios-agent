//
//  RecordCell.swift
//  ExpensesTracker
//
//  Two cells, matching the two shapes the Android app used for the same record.
//
//  `RecordRowCell` is income_recycler.xml / expense_recycler_data.xml: a full-width row with purpose,
//  note, date and amount, used by the Income and Expense tabs.
//
//  `RecordTileCell` is incomedashboardrecycler.xml / expensedashboardrecycler.xml: a compact card for
//  the dashboard's two horizontal strips.
//

import UIKit

final class RecordRowCell: UICollectionViewCell {

    static let reuseIdentifier = "RecordRowCell"

    private let purposeLabel = UILabel()
    private let noteLabel = UILabel()
    private let dateLabel = UILabel()
    private let amountLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous

        purposeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        noteLabel.font = .systemFont(ofSize: 13)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 1
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        amountLabel.font = .systemFont(ofSize: 18, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = UIStackView(arrangedSubviews: [purposeLabel, noteLabel, dateLabel])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [text, amountLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with record: LedgerRecord, kind: RecordKind) {
        purposeLabel.text = record.purpose
        noteLabel.text = record.note
        dateLabel.text = record.dateText
        amountLabel.text = record.displayAmount(for: kind)
        amountLabel.textColor = Theme.tint(for: kind)
        accessibilityIdentifier = "record.\(kind.rawValue).\(record.purpose)"
    }
}

final class RecordTileCell: UICollectionViewCell {

    static let reuseIdentifier = "RecordTileCell"

    private let purposeLabel = UILabel()
    private let amountLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // cardColor (#0C134F) from the Android palette, which is what these tiles used.
        contentView.backgroundColor = Theme.card
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous

        purposeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        purposeLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        purposeLabel.numberOfLines = 1

        amountLabel.font = .systemFont(ofSize: 22, weight: .bold)
        amountLabel.textColor = .white
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.7

        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        dateLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [purposeLabel, amountLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with record: LedgerRecord, kind: RecordKind) {
        purposeLabel.text = record.purpose
        amountLabel.text = record.displayAmount(for: kind)
        amountLabel.textColor = kind == .income ? Theme.accentGreen : UIColor.systemPink
        dateLabel.text = record.dateText
    }
}
