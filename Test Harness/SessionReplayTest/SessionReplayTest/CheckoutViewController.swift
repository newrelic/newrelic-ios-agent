//
//  CheckoutViewController.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 11/21/24.
//

import UIKit

class CheckoutViewController: UIViewController {

    @IBOutlet weak var cartTableView: UITableView!
    @IBOutlet weak var nameInput: UITextField!
    @IBOutlet weak var addressInput: UITextField!
    @IBOutlet weak var cityStateInput: UITextField!
    @IBOutlet weak var zipInput: UITextField!
    @IBOutlet weak var addressesTheSameSwitch: UISwitch!
    
    var dataSource: CheckoutDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dataSource = CheckoutDataSource(dogs: generateDogList())
        
        self.cartTableView.dataSource = dataSource
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func continueToBilling(_ sender: Any) {
    }
}

class CheckoutDataSource: NSObject, UITableViewDataSource {
    let dogList: [DogModel]
    
    init(dogs: [DogModel]) {
        dogList = dogs
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CheckoutTableViewCell.reuseID, for: indexPath) as! CheckoutTableViewCell
        let dog = dogList[indexPath.row]
        cell.set(dog: dog)
        return cell
    }
}
