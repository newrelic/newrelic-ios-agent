//
//  SideMenuViewController.swift
//  ExpensesTracker
//
//  Port of the Android drawer: activity_home.xml's NavigationView, with nav_header.xml above
//  content_menu.xml's three destinations, plus the logout the options menu carried.
//
//  It reports itself as a view. A drawer is a screen a user navigates to and away from — it has an
//  appearance, a dwell time, and it is where a tab switch comes from — so leaving it out would put a
//  hole in the very timeline this app exists to produce.
//

import UIKit

final class SideMenuViewController: InstrumentedViewController {

    override var viewName: ViewName { .sideMenu }
    /// Installed as a child of Home at load time and slid in later, so appearing is not the same thing as
    /// being visible. HomeViewController reports it when the drawer opens.
    override var reportsViewOnAppear: Bool { false }

    enum Destination: CaseIterable {
        case dashboard, income, expense

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .income:    return "Income"
            case .expense:   return "Expense"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .income:    return "arrow.down.circle"
            case .expense:   return "arrow.up.circle"
            }
        }
    }

    var onSelect: ((Destination) -> Void)?
    var onLogout: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 4, height: 0)

        let header = makeHeader()
        let destinations = Destination.allCases.map(makeRow)
        let logout = makeLogoutRow()

        let stack = UIStackView(arrangedSubviews: [header] + destinations + [spacer(), logout])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Rows

    /// nav_header.xml showed the app name over a green field; the signed-in email is added because the
    /// header had a placeholder for it and never filled it in.
    private func makeHeader() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.home

        let title = UILabel()
        title.text = "Expenses tracker"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = .white

        let subtitle = UILabel()
        subtitle.text = AuthService.shared.currentUser?.email ?? "Not signed in"
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = Theme.accentGreen
        subtitle.lineBreakMode = .byTruncatingMiddle

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        return container
    }

    private func makeRow(_ destination: Destination) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = destination.title
        configuration.image = UIImage(systemName: destination.symbol)
        configuration.imagePadding = 14
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "sidemenu.\(destination.title.lowercased())"
        button.addAction(UIAction { [weak self] _ in
            self?.onSelect?(destination)
        }, for: .touchUpInside)
        return button
    }

    private func makeLogoutRow() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "LOGOUT"
        configuration.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
        configuration.imagePadding = 14
        configuration.baseForegroundColor = .systemRed
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "sidemenu.logout"
        button.addAction(UIAction { [weak self] _ in
            self?.onLogout?()
        }, for: .touchUpInside)
        return button
    }

    private func spacer() -> UIView {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }
}
