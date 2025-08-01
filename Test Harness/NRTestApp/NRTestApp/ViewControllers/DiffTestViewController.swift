//
//  DiffTestViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/31/25.
//

import UIKit

class DiffTestViewController: UIViewController {

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter text"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.layer.borderColor = UIColor.lightGray.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Diff Test"
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .white
        view.addSubview(textField)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textField.heightAnchor.constraint(equalToConstant: 40),

            textView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            textView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
}
