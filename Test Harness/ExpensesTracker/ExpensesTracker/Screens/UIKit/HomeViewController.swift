//
//  HomeViewController.swift
//  ExpensesTracker
//
//  Port of HomeActivity — the chrome that holds the three tabs.
//
//  Android composed this from a DrawerLayout wrapping a Toolbar, a BottomNavigationView, and a
//  FrameLayout that fragments were swapped into, plus a NavigationView for the drawer and an options
//  menu carrying Logout and the Compose entry point. The iOS equivalents, one for one:
//
//      Toolbar + options menu   → the navigation bar and its bar button items
//      BottomNavigationView     → a child UITabBarController
//      FrameLayout + fragments  → the tab controller's view controllers
//      DrawerLayout + NavigationView → SideMenuViewController, slid in over the content
//
//  The tabs are held as three long-lived view controllers, as HomeActivity held three long-lived
//  Fragments. Its drawer, though, built a *new* fragment on every selection while the bottom bar reused
//  the originals, so picking "Income" from the drawer and from the bar gave you two different instances
//  with two different scroll positions. Both paths select the same tab here.
//
//  One Android behaviour is deliberately dropped: press-back-twice-to-exit. iOS apps do not exit
//  themselves, and a `finishAffinity()` equivalent would be rejected by review.
//

import UIKit
import NewRelic

final class HomeViewController: InstrumentedViewController {

    override var viewName: ViewName { .home }

    private let store: LedgerStore
    private unowned let flow: AppFlow

    private let tabs = UITabBarController()
    private let dashboard: DashboardViewController
    private let income: IncomeViewController
    private let expense: ExpenseViewController

    // MARK: Drawer

    private let sideMenu: SideMenuViewController
    private let dimmingView = UIView()
    private var sideMenuLeading: NSLayoutConstraint?
    private static let sideMenuWidth: CGFloat = 280

    init(store: LedgerStore, flow: AppFlow) {
        self.store = store
        self.flow = flow
        self.dashboard = DashboardViewController(store: store)
        self.income = IncomeViewController(store: store)
        self.expense = ExpenseViewController(store: store)
        self.sideMenu = SideMenuViewController()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        installTabs()
        installSideMenu()
    }

    // MARK: - Navigation bar

    private func configureNavigationBar() {
        navigationItem.title = "Expenses tracker"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.home
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white
        navigationItem.hidesBackButton = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(toggleSideMenu)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "home.menu"

        // Android's options menu held exactly these two items.
        let swiftUIItem = UIBarButtonItem(title: "SwiftUI",
                                         style: .plain,
                                         target: self,
                                         action: #selector(showSwiftUISection))
        swiftUIItem.accessibilityIdentifier = "home.swiftui"

        let logoutItem = UIBarButtonItem(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(confirmLogout))
        logoutItem.accessibilityIdentifier = "home.logout"

        navigationItem.rightBarButtonItems = [logoutItem, swiftUIItem]
    }

    // MARK: - Tabs

    private func installTabs() {
        dashboard.tabBarItem = UITabBarItem(title: "Dashboard",
                                           image: UIImage(systemName: "square.grid.2x2"),
                                           tag: 0)
        income.tabBarItem = UITabBarItem(title: "Income",
                                        image: UIImage(systemName: "arrow.down.circle"),
                                        tag: 1)
        expense.tabBarItem = UITabBarItem(title: "Expense",
                                         image: UIImage(systemName: "arrow.up.circle"),
                                         tag: 2)

        tabs.viewControllers = [dashboard, income, expense]
        tabs.tabBar.tintColor = Theme.home
        tabs.delegate = self

        addChild(tabs, to: view)
    }

    private func addChild(_ child: UIViewController, to container: UIView) {
        addChild(child)
        container.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: container.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        child.didMove(toParent: self)
    }

    // MARK: - Side menu

    private func installSideMenu() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.alpha = 0
        dimmingView.isUserInteractionEnabled = false
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)

        dimmingView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleDimmingTap))
        )

        addChild(sideMenu)
        view.addSubview(sideMenu.view)
        sideMenu.view.translatesAutoresizingMaskIntoConstraints = false

        // Parked entirely off-screen; the drawer is opened by animating this to 0.
        let leading = sideMenu.view.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                            constant: -Self.sideMenuWidth)
        sideMenuLeading = leading

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            leading,
            sideMenu.view.topAnchor.constraint(equalTo: view.topAnchor),
            sideMenu.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sideMenu.view.widthAnchor.constraint(equalToConstant: Self.sideMenuWidth)
        ])
        sideMenu.didMove(toParent: self)

        sideMenu.onSelect = { [weak self] destination in
            self?.closeSideMenu(reportingUnderlyingTab: false)
            self?.select(destination)
        }
        sideMenu.onLogout = { [weak self] in
            self?.closeSideMenu(reportingUnderlyingTab: false)
            self?.confirmLogout()
        }
    }

    private var isSideMenuOpen: Bool { (sideMenuLeading?.constant ?? 0) == 0 }

    @objc private func toggleSideMenu() {
        isSideMenuOpen ? closeSideMenu(reportingUnderlyingTab: true) : openSideMenu()
    }

    private func openSideMenu() {
        sideMenuLeading?.constant = 0
        dimmingView.isUserInteractionEnabled = true
        NewRelic.recordBreadcrumb("side_menu_opened", attributes: ["screen": viewName.rawValue])
        // See SideMenuViewController.reportsViewOnAppear: this is the moment the drawer becomes visible.
        sideMenu.reportView()

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            self.dimmingView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    /// Tapping the dim overlay dismisses the drawer without choosing a destination.
    @objc private func handleDimmingTap() {
        closeSideMenu(reportingUnderlyingTab: true)
    }

    /// `reportingUnderlyingTab` is false when the drawer is closing *because* a destination was chosen:
    /// the tab switch that follows reports the new tab through its own `viewDidAppear`, and reporting the
    /// old one on the way out would put a view event in the timeline for a screen nobody looked at.
    private func closeSideMenu(reportingUnderlyingTab: Bool) {
        guard isSideMenuOpen else { return }
        sideMenuLeading?.constant = -Self.sideMenuWidth
        dimmingView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseIn]) {
            self.dimmingView.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard reportingUnderlyingTab else { return }
            // Dismissed without choosing anything, so the tab underneath becomes current again — its
            // viewDidAppear will not fire a second time.
            (self?.tabs.selectedViewController as? InstrumentedViewController)?.reportView()
        }
    }

    // MARK: - Actions

    /// Both the drawer and the tab bar route here, so the two cannot disagree about which screen you
    /// are on — the bug the Android version had.
    private func select(_ destination: SideMenuViewController.Destination) {
        switch destination {
        case .dashboard: tabs.selectedIndex = 0
        case .income:    tabs.selectedIndex = 1
        case .expense:   tabs.selectedIndex = 2
        }
        // Programmatic selection does not call the delegate, so the breadcrumb is recorded here. The view
        // event itself comes from the tab's own viewDidAppear either way.
        reportTabSelection()
    }

    @objc private func showSwiftUISection() {
        flow.showSwiftUISection(from: self)
    }

    /// Android put this behind an AlertDialog with Yes/No; a destructive alert is the iOS equivalent.
    @objc private func confirmLogout() {
        let alert = UIAlertController(title: "Logout",
                                     message: "Are you sure you want to logout?",
                                     preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            self?.showToast("You have been logged out")
            self?.flow.signOut()
        })
        present(alert, animated: true)
    }

    private func reportTabSelection() {
        guard let selected = tabs.selectedViewController as? InstrumentedViewController else { return }
        NewRelic.recordBreadcrumb("tab_selected", attributes: ["tab": selected.viewName.rawValue])
    }
}

// MARK: - UITabBarControllerDelegate

extension HomeViewController: UITabBarControllerDelegate {

    /// The tab's own `viewDidAppear` reports the view; this only records the navigation itself, which is
    /// what BottomNavigationView's listener did on Android beyond swapping the fragment.
    func tabBarController(_ tabBarController: UITabBarController,
                          didSelect viewController: UIViewController) {
        guard let selected = viewController as? InstrumentedViewController else { return }
        NewRelic.recordBreadcrumb("tab_selected", attributes: ["tab": selected.viewName.rawValue])
    }
}
