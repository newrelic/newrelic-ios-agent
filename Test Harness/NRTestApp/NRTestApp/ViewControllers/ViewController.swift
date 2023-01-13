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
    
    var spaceImageView = UIImageView()
    var spaceLabel = UILabel()
    var spaceStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupSpaceStack()
        setupButtonsStack()
        
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
        
        viewModel.loadImage()
    }
    
    func setupSpaceStack() {
        //Image View
        spaceImageView.contentMode = .scaleAspectFit
        spaceImageView.heightAnchor.constraint(equalToConstant: 250.0).isActive = true
        spaceImageView.widthAnchor.constraint(equalToConstant: 250.0).isActive = true
                                
        //Text Label
        spaceLabel.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
        spaceLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
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
    
    func setupButtonsStack() {
        let utilities = makeButton(title: "Utilities")
        utilities.addTarget(self, action: #selector(utilitiesAction(_:)), for: .touchUpInside)
        
        let webView = makeButton(title: "WebView")
        webView.addTarget(self, action: #selector(webViewAction(_:)), for: .touchUpInside)
        
        let refresh = makeButton(title: "Change Image")
        refresh.addTarget(self, action: #selector(refreshAction(_:)), for: .touchUpInside)
        
        //Stack View
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 16.0
        
        stackView.addArrangedSubview(utilities)
        stackView.addArrangedSubview(webView)
        stackView.addArrangedSubview(refresh)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(stackView)
        
        stackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: self.spaceStack.bottomAnchor, constant: 50).isActive = true
    }
    
    @objc func utilitiesAction(_ sender: UIButton!) {
        coordinator?.showUtilitiesViewController()
    }
    
    @objc func webViewAction(_ sender: UIButton!) {
        coordinator?.showWebViewController()
    }
    
    @objc func refreshAction(_ sender: UIButton!) {
        viewModel.loadImage()
    }
    
    func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
        
        return button
    }
}
