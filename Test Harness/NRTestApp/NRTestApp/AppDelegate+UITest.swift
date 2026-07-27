//
//  AppDelegate+UITest.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/20/23.
//

import Foundation
import CoreData

extension AppDelegate {
    func clearConnectUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "com.newrelic.connectionInformation")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.harvesterConfiguration")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.applicationIdentifier")
        UserDefaults.standard.synchronize()
    }

    // Headless driver for the Core Data instrumentation crash path (see CoreDataView.swift),
    // so it can be exercised from the command line / UI tests without tapping the UI:
    //
    //   xcrun simctl launch --console <sim> com.newrelic.NRApp.bitcode -RunCoreDataCrashRepro
    //
    // Runs the same context.fetch(_:) chain the McDonald's crash hit
    // (fetch<A> -> executeRequest:error: -> instrumented executeFetchRequest:error:), including
    // the nested re-entrant fetch that drives NRMA__beginMethod into its former @throw branch.
    // With the hardened agent the process must survive and print "DONE".
    func runCoreDataCrashReproIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-RunCoreDataCrashRepro") else { return }

        // Delay so NewRelic.start() has installed the Core Data method instrumentation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSLog("[NRTestApp] CoreDataRepro: starting")
            NRCoreDataStack.seedIfNeeded()
            let context = NRCoreDataStack.container.viewContext

            func fetchAll() -> [NRCoreDataItem] {
                let request = NSFetchRequest<NRCoreDataItem>(entityName: "NRCoreDataItem")
                request.returnsObjectsAsFaults = false
                return (try? context.fetch(request)) ?? []
            }

            context.reset()
            NRCoreDataItem.triggerNestedFetch = false
            NSLog("[NRTestApp] CoreDataRepro: plain fetch -> \(fetchAll().count) results (survived)")

            context.reset()
            NRCoreDataItem.triggerNestedFetch = true
            let nestedCount = fetchAll().count
            NRCoreDataItem.triggerNestedFetch = false
            NSLog("[NRTestApp] CoreDataRepro: nested re-entrant fetch -> \(nestedCount) results (survived)")

            NSLog("[NRTestApp] CoreDataRepro: DONE — app survived the executeFetchRequest:error: instrumentation path")
        }
    }
}
