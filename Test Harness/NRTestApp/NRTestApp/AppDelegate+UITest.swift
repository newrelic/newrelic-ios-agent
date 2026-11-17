//
//  AppDelegate+UITest.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/20/23.
//

import Foundation
import CoreData
import NewRelic

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
    // Runs the same context.fetch(_:) chain crash hit
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

    // Headless driver for GitHub issue #884 / NR-614312: the reporter's suggested
    // repro -- "call recordError in a tight loop ... while the device is nearly out
    // of memory, so that the allocations inside HexStore::store and
    // HandledException::serialize start failing."
    //
    // Normally driven by scripts/run_oom_resilience_tests.sh, which pairs this loop
    // with the operator-new injector in Tests/OOM-Resilience/oom_injector.cxx. By hand:
    //
    //   SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=<path>/liboominject.dylib \
    //   SIMCTL_CHILD_NR_OOM_ONE_IN=1000 SIMCTL_CHILD_NR_OOM_DELAY=12 \
    //   xcrun simctl launch --console <sim> com.newrelic.NRApp.bitcode \
    //       -RunHexOOMRepro -HexOOMIterations 20000 -HexOOMStartDelay 16
    //
    // Prints "DONE" with a count if the process survives. -HexOOMBallastMB additionally
    // pins N MiB resident first; that alone will not make a simulator's malloc fail
    // (see Tests/OOM-RESILIENCE.md), so it is off by default.
    func runHexOOMReproIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-RunHexOOMRepro") else { return }

        let args = ProcessInfo.processInfo.arguments
        func intArg(_ name: String, _ fallback: Int) -> Int {
            guard let i = args.firstIndex(of: name), i + 1 < args.count,
                  let v = Int(args[i + 1]) else { return fallback }
            return v
        }
        let iterations = intArg("-HexOOMIterations", 20000)
        let ballastMB  = intArg("-HexOOMBallastMB", 0)
        // Delay the loop so the DYLD_INSERT_LIBRARIES OOM injector (if used) has
        // armed itself first, and so agent startup runs on a healthy heap.
        let startDelay = Double(intArg("-HexOOMStartDelay", 1))

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + startDelay) {
            // The OOM injector only fails allocations on this thread name, so that the
            // agent's harvest/upload threads are not dragged into the test. Must match
            // NR_OOM_THREAD in Tests/OOM-Resilience/oom_injector.cxx.
            pthread_setname_np("nr-oom-loop")

            var ballast: [UnsafeMutableRawPointer] = []
            if ballastMB > 0 {
                NSLog("[NRTestApp] HexOOMRepro: allocating \(ballastMB) MiB of ballast to squeeze the heap")
                for _ in 0..<ballastMB {
                    let sz = 1 << 20
                    guard let p = malloc(sz) else {
                        NSLog("[NRTestApp] HexOOMRepro: malloc returned NULL after \(ballast.count) MiB")
                        break
                    }
                    memset(p, 0xA5, sz)   // touch it so it is really resident
                    ballast.append(p)
                }
                NSLog("[NRTestApp] HexOOMRepro: ballast resident = \(ballast.count) MiB")
            }

            NSLog("[NRTestApp] HexOOMRepro: starting tight recordError loop, \(iterations) iterations")
            let err = NSError(domain: "PlatformException", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Flutter recordError"])
            for i in 0..<iterations {
                NewRelic.recordError(err, attributes: ["id": i])
                if i % 2000 == 0 { NSLog("[NRTestApp] HexOOMRepro: \(i) recordError calls survived") }
            }
            NSLog("[NRTestApp] HexOOMRepro: DONE — survived \(iterations) recordError calls")
            for p in ballast { free(p) }
        }
    }
}
