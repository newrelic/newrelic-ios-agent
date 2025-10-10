//
//  ListsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct ListsView: View {
    let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"]

    var body: some View {
        NavigationView {
            List(items, id: \.self) { item in
                if item == "Item 3" {
                    Text(item)
                        .nrMasked()

                }else {
                    Text(item)
                }
            }
            .navigationBarTitle("Lists")
            .NRTrackView(name: "ListsView")
        }
        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
    }
}

struct ListsView_Previews: PreviewProvider {
    static var previews: some View {
        ListsView()
    }
}
