//
//  DogModel.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 7/24/24.
//

import UIKit
import Foundation


struct DogModel {
    let title : String
    let shortDescription : String
    let longDescription : String
    let features : [String]
    let price: String
    let image : UIImage?
    let id: Int
}


func getMardiGrasDog() -> DogModel {
    return DogModel(title: "Mardi Gras Dog", 
                    shortDescription: "This dog is always up for a party",
                    longDescription: "The Mardi Gras style dog is always ready to party!",
                    features: ["Comes with Beads!"],
                    price: "$1 million dollars",
                    image: UIImage(named: "mardi gras dog"),
                    id:1)
}

func getEeyoreDog() -> DogModel{
    return DogModel(title: "Eeyore Style Dog", 
                    shortDescription: "This dog will always give you puppy dog eyes",
                    longDescription: "The Eeyore Style Dog will surprise you! Turns out, she is not only pretty, but she is smart and playful too. This princess will keep you on your toes",
                    features: ["Short hair, no mess!",
                               "Eats over a pound of raw meat a day!",
                               "Can tell time - she knows when it's her dinner time!",
                               "Gets along with other dogs!",
                               "Loves to run zoomies!",
                               "Will roll in whatever happens to be on the ground!"],
                    price: "Free to a good home",
                    image: UIImage(named: "eeyore dog"),
                    id:2)
}

func generateDogList() -> [DogModel] {
    return [getMardiGrasDog(), getEeyoreDog()]
}
