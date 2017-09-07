FetchedRecordsController
========================

**You use FetchedRecordsController to track changes in the results of an SQLite request.**

**FetchedRecordsController can also feed table views, collection views, and animate cells when the results of the request change.**

It looks and behaves very much like [Core Data's NSFetchedResultsController](https://developer.apple.com/library/ios/documentation/CoreData/Reference/NSFetchedResultsController_Class/).

Given a fetch request, and a type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, such as a subclass of the [Record](#record-class) class, a FetchedRecordsController is able to track changes in the results of the fetch request, notify of those changes, and return the results of the request in a form that is suitable for a table view or a collection view, with one cell per fetched record.

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS/GRDBDemoiOS) for an sample app that uses FetchedRecordsController.

See also [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB), an [RxSwift](https://github.com/ReactiveX/RxSwift) extension, for a reactive way to track request changes.

- [Creating the Fetched Records Controller](#creating-the-fetched-records-controller)
- [Responding to Changes](#responding-to-changes)
- [The Changes Notifications](#the-changes-notifications)
- [Modifying the Fetch Request](#modifying-the-fetch-request)
- [Table and Collection Views](#table-and-collection-views)
    - [Implementing the Table View Datasource Methods](#implementing-the-table-view-datasource methods)
    - [Implementing Table View Updates](#implementing-table-view-updates)
- [FetchedRecordsController Concurrency](#fetchedrecordscontroller-concurrency)


## Creating the Fetched Records Controller

When you initialize a fetched records controller, you provide the following mandatory information:

- A [database connection](#database-connections)
- The type of the fetched records. It must be a type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, such as a subclass of the [Record](#record-class) class
- A fetch request

```swift
class Player : Record { ... }
let dbQueue = DatabaseQueue(...)    // Or DatabasePool

// Using a Request from the Query Interface:
let controller = FetchedRecordsController(
    dbQueue,
    request: Player.order(Column("name")))

// Using SQL, and eventual arguments:
let controller = FetchedRecordsController<Player>(
    dbQueue,
    sql: "SELECT * FROM players ORDER BY name WHERE countryIsoCode = ?",
    arguments: ["FR"])
```

The fetch request can involve several database tables. The fetched records controller will only track changes in the columns and tables used by the fetch request.

```swift
let controller = FetchedRecordsController<Player>(
    dbQueue,
    sql: """
        SELECT players.name, COUNT(books.id) AS bookCount
        FROM players
        LEFT JOIN books ON books.authorId = players.id
        GROUP BY players.id
        ORDER BY players.name
        """)
```


After creating an instance, you invoke `performFetch()` to actually execute
the fetch.

```swift
try controller.performFetch()
```


## Responding to Changes

In general, FetchedRecordsController is designed to respond to changes at *the database layer*, by [notifying](#the-changes-notifications) when *database rows* change location or values.

Changes are not reflected until they are applied in the database by a successful [transaction](#transactions-and-savepoints). Transactions can be explicit, or implicit:

```swift
try dbQueue.inTransaction { db in
    try player1.insert(db)
    try player2.insert(db)
    return .commit         // Explicit transaction
}

try dbQueue.inDatabase { db in
    try player1.insert(db) // Implicit transaction
    try player2.insert(db) // Implicit transaction
}
```

When you apply several changes to the database, you should group them in a single explicit transaction. The controller will then notify of all changes together.


## The Changes Notifications

An instance of FetchedRecordsController notifies that the controller’s fetched records have been changed by the mean of *callbacks*:

```swift
let controller = try FetchedRecordsController(...)

controller.trackChanges(
    // controller's records are about to change:
    willChange: { controller in ... },
    
    // notification of individual record changes:
    onChange: { (controller, record, change) in ... },
    
    // controller's records have changed:
    didChange: { controller in ... })

try controller.performFetch()
```

See [Implementing Table View Updates](#implementing-table-view-updates) for more detail on table view updates.

**All callbacks are optional.** When you only need to grab the latest results, you can omit the `didChange` argument name:

```swift
controller.trackChanges { controller in
    let newPlayers = controller.fetchedRecords // [Player]
}
```

Callbacks have the fetched record controller itself as an argument: use it in order to avoid memory leaks:

```swift
// BAD: memory leak
controller.trackChanges { _ in
    let newPlayers = controller.fetchedRecords
}

// GOOD
controller.trackChanges { controller in
    let newPlayers = controller.fetchedRecords
}
```

**Callbacks are invoked asynchronously.** See [FetchedRecordsController Concurrency](#fetchedrecordscontroller-concurrency) for more information.

**Values fetched from inside callbacks may be inconsistent with the controller's records.** This is because after database has changed, and before the controller had the opportunity to invoke callbacks in the main thread, other database changes can happen.

To avoid inconsistencies, provide a `fetchAlongside` argument to the `trackChanges` method, as below:

```swift
controller.trackChanges(
    fetchAlongside: { db in
        // Fetch any extra value, for example the number of fetched records:
        return try Player.fetchCount(db)
    },
    didChange: { (controller, count) in
        // The extra value is the second argument.
        let recordsCount = controller.fetchedRecords.count
        assert(count == recordsCount) // guaranteed
    })
```

Whenever the fetched records controller can not look for changes after a transaction has potentially modified the tracked request, an error handler is called. The request observation is not stopped, though: future transactions may successfully be handled, and the notified changes will then be based on the last successful fetch.

```swift
controller.trackErrors { (controller, error) in
    print("Missed a transaction because \(error)")
}
```


## Modifying the Fetch Request

You can change a fetched records controller's fetch request or SQL query.

```swift
controller.setRequest(Player.order(Column("name")))
controller.setRequest(sql: "SELECT ...", arguments: ...)
```

The [notification callbacks](#the-changes-notifications) are notified of eventual changes if the new request fetches a different set of records.

> :point_up: **Note**: This behavior differs from Core Data's NSFetchedResultsController, which does not notify of record changes when the fetch request is replaced.

**Change callbacks are invoked asynchronously.** This means that modifying the request from the main thread does *not* immediately triggers callbacks. When you need to take immediate action, force the controller to refresh immediately with its `performFetch` method. In this case, changes callbacks are *not* called:

```swift
// Change request on the main thread:
controller.setRequest(Player.order(Column("name")))
// Here callbacks have not been called yet.
// You can cancel them, and refresh records immediately:
try controller.performFetch()
```

## Table and Collection Views

FetchedRecordsController let you feed table and collection views, and keep them up-to-date with the database content.

For nice animated updates, a fetched records controller needs to recognize identical records between two different result sets. When records adopt the [TableMapping](#tablemapping-protocol) protocol, they are automatically compared according to their primary key:

```swift
class Player : TableMapping { ... }
let controller = FetchedRecordsController(
    dbQueue,
    request: Player.all())
```

For other types, the fetched records controller needs you to be more explicit:

```swift
let controller = FetchedRecordsController(
    dbQueue,
    request: ...,
    isSameRecord: { (player1, player2) in player1.id == player2.id })
```


### Implementing the Table View Datasource Methods

The table view data source asks the fetched records controller to provide relevant information:

```swift
func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedRecordsController.sections.count
}

func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedRecordsController.sections[section].numberOfRecords
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = ...
    let record = fetchedRecordsController.record(at: indexPath)
    // Configure the cell
    return cell
}
```

> :point_up: **Note**: In its current state, FetchedRecordsController does not support grouping table view rows into custom sections: it generates a unique section.


### Implementing Table View Updates

When changes in the fetched records should reload the whole table view, you can simply tell so:

```swift
controller.trackChanges { [unowned self] _ in
    self.tableView.reloadData()
}
```

Yet, FetchedRecordsController can notify that the controller’s fetched records have been changed due to some add, remove, move, or update operations, and help applying animated changes to a UITableView.


#### Typical Table View Updates

For animated table view updates, use the `willChange` and `didChange` callbacks to bracket events provided by the fetched records controller, as illustrated in the following example:

```swift
// Assume self has a tableView property, and a cell configuration
// method named configure(_:at:).

controller.trackChanges(
    // controller's records are about to change:
    willChange: { [unowned self] _ in
        self.tableView.beginUpdates()
    },
    
    // notification of individual record changes:
    onChange: { [unowned self] (controller, record, change) in
        switch change {
        case .insertion(let indexPath):
            self.tableView.insertRows(at: [indexPath], with: .fade)
            
        case .deletion(let indexPath):
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .update(let indexPath, _):
            if let cell = self.tableView.cellForRow(at: indexPath) {
                self.configure(cell, at: indexPath)
            }
            
        case .move(let indexPath, let newIndexPath, _):
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            self.tableView.insertRows(at: [newIndexPath], with: .fade)

            // // Alternate technique which actually moves cells around:
            // let cell = self.tableView.cellForRow(at: indexPath)
            // self.tableView.moveRow(at: indexPath, to: newIndexPath)
            // if let cell = cell {
            //     self.configure(cell, at: newIndexPath)
            // }
        }
    },
    
    // controller's records have changed:
    didChange: { [unowned self] _ in
        self.tableView.endUpdates()
    })
```

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS/GRDBDemoiOS) for an sample app that uses FetchedRecordsController.

> :point_up: **Note**: our sample code above uses `unowned` references to the table view controller. This is a safe pattern as long as the table view controller owns the fetched records controller, and is deallocated from the main thread (this is usually the case). In other situations, prefer weak references.


## FetchedRecordsController Concurrency

**A fetched records controller *can not* be used from any thread.**

When the database itself can be read and modified from [any thread](#database-connections), fetched records controllers **must** be used from the main thread. Record changes are also [notified](#the-changes-notifications) on the main thread.

**Change callbacks are invoked asynchronously.** This means that changes made from the main thread are *not* immediately notified. When you need to take immediate action, force the controller to refresh immediately with its `performFetch` method. In this case, changes callbacks are *not* called:

```swift
// Change database on the main thread:
try dbQueue.inDatabase { db in
    try Player(...).insert(db)
}
// Here callbacks have not been called yet.
// You can cancel them, and refresh records immediately:
try controller.performFetch()
```

> :point_up: **Note**: when the main thread does not fit your needs, give a serial dispatch queue to the controller initializer: the controller must then be used from this queue, and record changes are notified on this queue as well.
>
> ```swift
> let queue = DispatchQueue()
> queue.async {
>     let controller = try FetchedRecordsController(..., queue: queue)
>     controller.trackChanges { /* in queue */ }
>     try controller.performFetch()
> }
> ```
