//
//  ScrollableCollectionViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/3/25.
//


import UIKit

class ScrollableCollectionViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private let reuseIdentifier = "ColorCell"
    private let numberOfItems = 100 // Plenty of items to make it scrollable
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        // Create a flow layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        
        // Calculate cell size (3 cells per row with spacing)
        let cellWidth = (view.bounds.width - 40) / 3
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        // Create and configure collection view
        collectionView = UICollectionView(frame: view.safeAreaLayoutGuide.layoutFrame, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(ColorCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
    }
}

// MARK: - UICollectionViewDataSource
extension ScrollableCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ColorCollectionViewCell
        
        // Create a different color for each cell
        let hue = CGFloat(indexPath.item) / CGFloat(numberOfItems)
        cell.backgroundColor = UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 1.0)
        cell.configure(with: indexPath.item)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ScrollableCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected item at \(indexPath.item)")
    }
}

// MARK: - Custom Cell
class ColorCollectionViewCell: UICollectionViewCell {
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 8
        clipsToBounds = true
        
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        // Set up constraints for the label to be centered in the cell
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with number: Int) {
        label.text = "\(number)"
    }
}
