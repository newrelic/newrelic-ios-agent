//
//  ViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/11/23.
//

import UIKit
import NewRelic

class ViewController: UIViewController {
    weak var coordinator: MainCoordinator?
    var viewModel: ApodViewModel!
    
    var options =  [UtilOption]()
    
    var spaceImageView = UIImageView()
    var spaceLabel = UILabel()
    var spaceStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
#if os(iOS)
        self.view.backgroundColor = .systemBackground
#endif
        setupSpaceStack()
        setupButtonsTable()
        
        viewModel.error.onUpdate = { [weak self] _ in
            if let error = self?.viewModel.error.value {
                NewRelic.recordError(error)
            }
        }

        viewModel.apodResponse.onUpdate = { [weak self] _ in
            if let url = self?.viewModel.apodResponse.value?.url {
                self?.spaceImageView.loadImage(withUrl: url)
            }
            if let title = self?.viewModel.apodResponse.value?.title, let date = self?.viewModel.apodResponse.value?.date{
                self?.spaceLabel.text = title + ", " + date
            }
        }
        
        viewModel.loadApodData()
    }
    
    func setupSpaceStack() {
        //Image View
        spaceImageView.contentMode = .scaleAspectFit
        spaceImageView.heightAnchor.constraint(equalToConstant: 250.0).isActive = true
        spaceImageView.widthAnchor.constraint(equalToConstant: 250.0).isActive = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        spaceImageView.isUserInteractionEnabled = true
        spaceImageView.addGestureRecognizer(tapGestureRecognizer)
        
        //Text Label
        spaceLabel.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
        spaceLabel.heightAnchor.constraint(equalToConstant: 40).isActive = true
        spaceLabel.text  = ""
        spaceLabel.textAlignment = .center
        
        //Stack View
        spaceStack.axis = .vertical
        spaceStack.distribution = .equalSpacing
        spaceStack.alignment = .center
        spaceStack.spacing = 16.0

        spaceStack.addArrangedSubview(spaceImageView)
        spaceStack.addArrangedSubview(spaceLabel)
        spaceStack.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(spaceStack)

        //Constraints
        spaceStack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        spaceStack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        guard let spaceImage = spaceImageView.image else { return }

        coordinator?.showImageViewController(image:spaceImage)
    }
    
    func setupButtonsTable() {
        let tableView = UITableView()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 140
        tableView.bounces = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "utilitiesCell")
        
        self.view.addSubview(tableView)
        
        tableView.topAnchor.constraint(equalTo: spaceStack.bottomAnchor, constant: 30.0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        
        options.append(UtilOption(title: "Utilities", handler: { [self] in utilitiesAction()}))
#if os(iOS)
        options.append(UtilOption(title: "WebView", handler: { [self] in webViewAction()}))
#endif
        options.append(UtilOption(title: "Change Image", handler: { [self] in refreshAction()}))
    }
    
    func utilitiesAction() {
        coordinator?.showUtilitiesViewController()
    }
  
    func webViewAction() {
        self.coordinator?.showWebViewController()
    }

    func refreshAction() {
        viewModel.loadApodData()
    }
    
    func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
        
        return button
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "utilitiesCell", for: indexPath)

        if #available(iOS 14.0, tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = options[indexPath.row].title
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = options[indexPath.row].title
            cell.textLabel?.textColor = .black
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        options[indexPath.row].handler()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
