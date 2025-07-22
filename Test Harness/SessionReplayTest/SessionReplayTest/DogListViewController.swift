//
//  DogListViewController.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 7/24/24.
//

import UIKit

class DogListViewController: UITableViewController {
    
    var dataSource: DogListDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        dataSource = DogListDataSource(dogs: getDogs())
        
        self.tableView.dataSource = dataSource
        self.tableView.layoutMargins = UIEdgeInsets.zero
    }
    
    private func getDogs() -> [DogModel] {
        return generateDogList();
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}


class DogListDataSource: NSObject, UITableViewDataSource {
    let dogList: [DogModel]
    
    init(dogs: [DogModel]) {
        dogList = dogs
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dogList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DogInfoCellTableViewCell.reuseID, for: indexPath) as! DogInfoCellTableViewCell
        let dog = dogList[indexPath.row]
        cell.set(dog: dog)
        
        cell.borderView.borderWidth = 2
        cell.borderView.borderColor = .black
        cell.borderView.cornerRadius = 10
        return cell
    }
}
