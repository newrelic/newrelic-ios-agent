//
//  MapViewSwiftUI.swift
//  NRTestApp
//

import SwiftUI
import MapKit

@available(iOS 14.0, tvOS 14.0, *)
struct MapViewSwiftUI: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        Map(coordinateRegion: $region)
            .navigationTitle("Map (SwiftUI)")
            .NRTrackView(name: "MapViewSwiftUI")
    }
}
