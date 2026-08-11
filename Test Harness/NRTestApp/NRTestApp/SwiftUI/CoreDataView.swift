//
//  CoreDataView.swift
//  NRTestApp
//
//  Reproduces the production Core Data crash path that New Relic instrumentation hit in
//  the field.
//
//      NRInvalidArgumentException — "New Relic detected an unrecognized selector,
//      'executeFetchRequest:error:', sent to 'NSObject'."
//
//      2  NewRelic   NRMA__beginMethod            (NRMAMethodProfiler.m)
//      3  NewRelic   NRMA__ptrPtrParamHandler     (NRMAMethodProfiler.m)
//      4  CoreData   -[NSManagedObjectContext executeRequest:error:]
//      5  CoreData   NSManagedObjectContext.fetch<A>(_:)
//      6  Arch       CoreDataStorage.fetch<A>(...)
//      7  Arch       OrderManager.fetchCurrentOrderRequestCart()
//
//  The agent instruments -[NSManagedObjectContext executeFetchRequest:error:]. A Swift
//  `context.fetch(_:)` dispatches through `executeRequest:error:`, which in turn invokes
//  the (NR-swizzled) `executeFetchRequest:error:` — the exact chain above.
//
//  Two buttons exercise it:
//   • "Run Core Data fetch"          — the faithful call chain (normal, traced path).
//   • "Run nested re-entrant fetch"  — performs a second fetch on the SAME context+thread
//     from within awakeFromFetch(), while the outer executeFetchRequest:error: is still on
//     the stack. That re-entry (depth > 1) drives NRMA__beginMethod down the [super _cmd]
//     branch; because NSManagedObjectContext's superclass is NSObject (which has no
//     NRMAMethodOverride_ variant) it reaches the `method == nil` dead-end — the exact spot
//     that used to @throw an uncaught NSException and crash the host. With the hardened
//     agent this now falls back to the real implementation and the app keeps running.
//

import SwiftUI
import CoreData
import NewRelic

// MARK: - Managed object

// A custom NSManagedObject subclass so we can hook awakeFromFetch() and trigger a
// re-entrant fetch. @objc keeps the runtime class name unmangled so the programmatic
// model below can map to it.
@objc(NRCoreDataItem)
final class NRCoreDataItem: NSManagedObject {
    @NSManaged var name: String?
    @NSManaged var order: Int64

    // One-shot switch. When true, the next object materialized by a fetch performs a
    // nested fetch on the same context+thread (re-entering executeFetchRequest:error:).
    static var triggerNestedFetch = false

    override func awakeFromFetch() {
        super.awakeFromFetch()

        guard NRCoreDataItem.triggerNestedFetch else { return }
        NRCoreDataItem.triggerNestedFetch = false // recurse exactly once — no infinite loop
        guard let context = managedObjectContext else { return }

        // Nested fetch while the outer executeFetchRequest:error: is still executing.
        // This is what pushes NRMA's per-(self,selector) re-entry depth past 1.
        let request = NSFetchRequest<NRCoreDataItem>(entityName: "NRCoreDataItem")
        request.returnsObjectsAsFaults = false
        _ = try? context.fetch(request)
    }
}

// MARK: - Programmatic in-memory Core Data stack (no .xcdatamodeld needed)

enum NRCoreDataStack {
    static let container: NSPersistentContainer = {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "NRCoreDataItem"
        entity.managedObjectClassName = "NRCoreDataItem"

        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true

        let orderAttr = NSAttributeDescription()
        orderAttr.name = "order"
        orderAttr.attributeType = .integer64AttributeType
        orderAttr.isOptional = false
        orderAttr.defaultValue = 0

        entity.properties = [nameAttr, orderAttr]
        model.entities = [entity]

        let container = NSPersistentContainer(name: "NRTestCoreData", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                NSLog("[NRTestApp] Core Data store load error: \(error)")
            }
        }
        return container
    }()

    private static var didSeed = false

    static func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        let context = container.viewContext
        for index in 0..<5 {
            let item = NRCoreDataItem(context: context)
            item.name = "Item \(index)"
            item.order = Int64(index)
        }
        try? context.save()
    }
}

// MARK: - View

struct CoreDataView: View {
    @State private var status = "Idle"
    @State private var results: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Core Data Fetch")
                .font(.largeTitle)

            Text("Exercises -[NSManagedObjectContext executeFetchRequest:error:] via context.fetch(_:) — the path New Relic instruments.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Run Core Data fetch") {
                runFetch(nested: false)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("run_core_data_fetch")

            Button("Run nested re-entrant fetch") {
                runFetch(nested: true)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("run_core_data_nested_fetch")

            Text(status)
                .font(.callout)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("core_data_status")

            List(results, id: \.self) { Text($0) }
        }
        .padding()
        .onAppear { NRCoreDataStack.seedIfNeeded() }
        .NRTrackView(name: "CoreDataView")
    }

    private func runFetch(nested: Bool) {
        let context = NRCoreDataStack.container.viewContext

        // Turn any already-registered objects back into faults so this fetch re-materializes
        // them — that materialization is what invokes awakeFromFetch() (and, for the nested
        // case, the re-entrant fetch). The seeded rows live in the store, so they come back.
        context.reset()
        NRCoreDataItem.triggerNestedFetch = nested

        // context.fetch(_:)  ->  -[NSManagedObjectContext executeRequest:error:]
        //                    ->  -[NSManagedObjectContext executeFetchRequest:error:]  (instrumented)
        let request = NSFetchRequest<NRCoreDataItem>(entityName: "NRCoreDataItem")
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        request.returnsObjectsAsFaults = false

        do {
            let items = try context.fetch(request)
            results = items.map { $0.name ?? "(nil)" }
            status = "\(nested ? "Nested " : "")fetch completed: \(items.count) results — no crash ✅"
        } catch {
            status = "fetch threw: \(error.localizedDescription)"
        }

        NRCoreDataItem.triggerNestedFetch = false
    }
}

struct CoreDataView_Previews: PreviewProvider {
    static var previews: some View {
        CoreDataView()
    }
}
