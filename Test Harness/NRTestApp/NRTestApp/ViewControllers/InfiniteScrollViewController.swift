//
//  InfiniteScrollViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/3/25.
//
//  MobileViewTiming on a paged list. Two things make this screen worth instrumenting:
//
//    * The agent's `timeToInitialDisplay` is fixed at viewDidAppear, which here is an *empty*
//      table -- page 1 is still 1.5s out. `markViewTiming("timeToFullDisplay")` stops where the
//      first real rows are on screen, measured from the same zero point, so subtracting the two
//      gives the interval this screen looked finished while showing nothing.
//
//    * Pages 2..n did not start when the view appeared, so a mark would report "time since the
//      screen opened" and grow without bound. Those are measured by this screen and handed over
//      with `recordViewTiming(_:milliseconds:)`.
//

import UIKit
import NewRelic

class InfiniteScrollTableViewController: UIViewController {

    // MARK: - Properties
    
    private var tableView: UITableView!
    private var data = [String]()
    private var isLoading = false
    private let reuseIdentifier = "InfoCell"
    private var currentPage = 1
    private let itemsPerPage = 25

    // MARK: - MobileViewTiming state

    /// timeToFullDisplay describes one visit, so it is marked once per appearance of this screen.
    private var didMarkFullDisplay = false

    /// How many `nextPageLoad` timings this visit is allowed to emit. The agent caps customer
    /// timings at 16 per view instance and an infinite list can load pages all day; stopping
    /// deliberately at a budget beats letting the length of a scroll session decide which timings
    /// survive.
    private static let pageTimingBudget = 8
    private var pageTimingsRecorded = 0

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Infinite Scroll"
        setupTableView()
        loadData()
    }
    
    // MARK: - UI Setup
    
    private func setupTableView() {
        // Instantiate the table view
        tableView = UITableView(frame: view.bounds, style: .plain)
        
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set the background color
        #if os(iOS)
        tableView.backgroundColor = .systemBackground
        #endif
        
        // Register a standard UITableViewCell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        
        // Set the data source and delegate
        if #available(iOS 14.0, *) {
            tableView.dataSource = self
        }
        tableView.delegate = self
        
        view.addSubview(tableView)
    }
    
    // MARK: - Data Handling
    
    /// Simulates loading data from a source (e.g., a network API).
    private func loadData() {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        isLoading = true

        // Zero point for *this* page's fetch. Page 1 shares the view's zero point and so is marked;
        // every later page is timed from here instead.
        let isFirstPage = data.isEmpty
        let pageStart = ProcessInfo.processInfo.systemUptime

        NewRelic.logVerbose("Loading page \(currentPage)...")
        
        // Simulate a network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            // Generate new items
            let newItems = (self.data.count..<(self.data.count + self.itemsPerPage)).map { "Row \($0 + 1)" }
            
            // Append new data on the main thread
            DispatchQueue.main.async {
                self.data.append(contentsOf: newItems)

                // Time the rows to when Core Animation has committed them rather than to the
                // reloadData() call: what is being timed is pixels, not bookkeeping.
                CATransaction.begin()
                CATransaction.setCompletionBlock { [weak self] in
                    guard let self else { return }
                    if isFirstPage {
                        self.markFirstPageDisplayed()
                    } else {
                        self.recordPageLoad(startedAt: pageStart)
                    }
                }
                self.tableView.reloadData()
                CATransaction.commit()

                self.currentPage += 1
                self.isLoading = false
                NewRelic.logVerbose("Data loaded. Total items: \(self.data.count)")
            }
        }
    }

    // MARK: - MobileViewTiming

    /// The first page's rows are on screen. This is what the user would call "loaded", and it is the
    /// number `timeToInitialDisplay` cannot report, because at viewDidAppear the table was empty.
    private func markFirstPageDisplayed() {
        guard !didMarkFullDisplay else { return }
        didMarkFullDisplay = true

        // Measured from the same instant the agent measured timeToInitialDisplay from, so the two
        // are subtractable: WHERE timingOrigin = 'constructionStart'.
        let marked = NewRelic.markViewTiming("timeToFullDisplay")
        NewRelic.logVerbose("markViewTiming(timeToFullDisplay) -> \(marked)")
    }

    /// A later page arrived. `markViewTiming` is the wrong tool here -- it always measures from the
    /// view's zero point, so page 7 would report the whole scroll session. This screen measured the
    /// fetch itself, so it supplies the duration.
    private func recordPageLoad(startedAt start: TimeInterval) {
        guard pageTimingsRecorded < Self.pageTimingBudget else { return }
        pageTimingsRecorded += 1

        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let recorded = NewRelic.recordViewTiming("nextPageLoad", milliseconds: elapsedMs)
        NewRelic.logVerbose("recordViewTiming(nextPageLoad, \(Int(elapsedMs))ms) -> \(recorded)  [\(data.count) rows]")
    }
}

// MARK: - UITableViewDataSource
@available(iOS 14.0, *)
extension InfiniteScrollTableViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the total number of items in our data array
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue a reusable cell
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        // Configure the cell with the corresponding data
        var content = cell.defaultContentConfiguration()
        content.text = data[indexPath.row]
        cell.contentConfiguration = content
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension InfiniteScrollTableViewController: UITableViewDelegate {
    
    /// This delegate method is the core of the infinite scroll implementation.
    /// It's called just before a cell is displayed.
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Check if the user has scrolled to the last row
        if indexPath.row == data.count - 1 && !isLoading {
            // If they have, load the next page of data
            loadData()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect the row for a cleaner UI experience
        tableView.deselectRow(at: indexPath, animated: true)
        NewRelic.logVerbose("Selected: \(data[indexPath.row])")
    }
}
