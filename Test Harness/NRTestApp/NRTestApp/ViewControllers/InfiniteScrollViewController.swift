//
//  InfiniteScrollViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/3/25.
//

import UIKit

class InfiniteScrollTableViewController: UIViewController {

    // MARK: - Properties
    
    private var tableView: UITableView!
    private var data = [String]()
    private var isLoading = false
    private let reuseIdentifier = "InfoCell"
    private var currentPage = 1
    private let itemsPerPage = 25

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
        tableView.backgroundColor = .systemBackground
        
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
        
        print("Loading page \(currentPage)...")
        
        // Simulate a network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            // Generate new items
            let newItems = (self.data.count..<(self.data.count + self.itemsPerPage)).map { "Row \($0 + 1)" }
            
            // Append new data on the main thread
            DispatchQueue.main.async {
                self.data.append(contentsOf: newItems)
                self.tableView.reloadData()
                self.currentPage += 1
                self.isLoading = false
                print("Data loaded. Total items: \(self.data.count)")
            }
        }
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
        print("Selected: \(data[indexPath.row])")
    }
}
