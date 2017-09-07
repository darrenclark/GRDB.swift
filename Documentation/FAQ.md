FAQ
===

- [How do I close a database connection?](#how-do-i-close-a-database-connection)
- [How do I open a database stored as a resource of my application?](#how-do-i-open-a-database-stored-as-a-resource-of-my-application)
- [Generic parameter 'T' could not be inferred](#generic-parameter-t-could-not-be-inferred)
- [Compilation takes a long time](#compilation-takes-a-long-time)
- [SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"](#sqlite-error-10-disk-io-error-sqlite-error-23-not-authorized)
- [What Are Experimental Features?](#what-are-experimental-features)


### How do I close a database connection?
    
Database connections are managed by [database queues](#database-queues) and [pools](#database-pools). A connection is closed when its database queue or pool is deallocated, and all usages of this connection are completed.

Database accesses that run in background threads postpone the closing of connections.


### How do I open a database stored as a resource of my application?

If your application does not need to modify the database, open a read-only [connection](#database-connections) to your resource:

```swift
var configuration = Configuration()
configuration.readonly = true
let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite")!
let dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
```

If the application should modify the database, you need to copy it to a place where it can be modified. For example, in the Documents folder. Only then, open a [connection](#database-connections):

```swift
let fm = FileManager.default
let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let dbPath = (documentsPath as NSString).appendingPathComponent("db.sqlite")
if !fm.fileExists(atPath: dbPath) {
    let dbResourcePath = Bundle.main.path(forResource: "db", ofType: "sqlite")!
    try fm.copyItem(atPath: dbResourcePath, toPath: dbPath)
}
let dbQueue = try DatabaseQueue(path: dbPath)
```


### Generic parameter 'T' could not be inferred
    
You may get this error when using DatabaseQueue.inDatabase, DatabasePool.read, or DatabasePool.write:

```swift
// Generic parameter 'T' could not be inferred
let x = try dbQueue.inDatabase { db in
    let result = try String.fetchOne(db, ...)
    return result
}
```

This is a Swift compiler issue (see [SR-1570](https://bugs.swift.org/browse/SR-1570)).

The general workaround is to explicitly declare the type of the closure result:

```swift
// General Workaround
let string = try dbQueue.inDatabase { db -> String? in
    let result = try String.fetchOne(db, ...)
    return result
}
```

You can also, when possible, write a single-line closure:

```swift
// Single-line closure workaround:
let string = try dbQueue.inDatabase { db in
    try String.fetchOne(db, ...)
}
```


### SQLite error 10 "disk I/O error", SQLite error 23 "not authorized"

Those errors may be the sign that SQLite can't access the database due to [data protection](#data-protection).

When your application should be able to run in the background on a locked device, it has to catch this error, and, for example, wait for [UIApplicationDelegate.applicationProtectedDataDidBecomeAvailable(_:)](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623044-applicationprotecteddatadidbecom) or [UIApplicationProtectedDataDidBecomeAvailable](https://developer.apple.com/reference/uikit/uiapplicationprotecteddatadidbecomeavailable) notification and retry the failed database operation.

This error can also be prevented altogether by using a more relaxed [file protection](https://developer.apple.com/reference/foundation/filemanager/1653059-file_protection_values).


### What Are Experimental Features?

Since GRDB 1.0, all backwards compatibility guarantees of [semantic versioning](http://semver.org) apply: no breaking change will happen until the next major version of the library.

There is an exception, though: *experimental features*, marked with the "**:fire: EXPERIMENTAL**" badge. Those are advanced features that are too young, or lack user feedback. They are not stabilized yet.

Those experimental features are not protected by semantic versioning, and may break between two minor releases of the library. To help them becoming stable, [your feedback](https://github.com/groue/GRDB.swift/issues) is greatly appreciated.
