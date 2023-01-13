//
//  UtilitiesViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/13/23.
//

import UIKit

class UtilitiesViewController: UIViewController {
    var viewModel = UtilViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.createUtilOptions()
        
        self.view.backgroundColor = .white
        self.title = "Utilities"
        
        let tableView = UITableView()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 140
        tableView.bounces = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "utilitiesCell")
        
        self.view.addSubview(tableView)
        
        tableView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

    }
    
}

extension UtilitiesViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return viewModel.options.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "utilitiesCell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = viewModel.options[indexPath.row].title
        
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.makeEvent()
        
        viewModel.options[indexPath.row].handler()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
