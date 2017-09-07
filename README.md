GRDB 2.0 [![Swift](https://img.shields.io/badge/swift-4-orange.svg?style=flat)](https://developer.apple.com/swift/) [![Platforms](https://img.shields.io/cocoapods/p/GRDB.swift.svg)](https://developer.apple.com/swift/) [![License](https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000)](/LICENSE) [![Build Status](https://travis-ci.org/groue/GRDB.swift.svg?branch=master)](https://travis-ci.org/groue/GRDB.swift)
==========

### A toolkit for SQLite databases, with a focus on application development

**Latest release**: [CHANGELOG](CHANGELOG.md)

**Requirements**: iOS 8.0+ / OSX 10.9+ / watchOS 2.0+ &bull; Swift 4.0 / Xcode 9+

**Other Swift versions**: For Swift 2.2 and Xcode 7.3, use [v0.80.2](https://github.com/groue/GRDB.swift/tree/v0.80.2) &bull; Swift 2.3, Xcode 8.0: [v0.81.2](https://github.com/groue/GRDB.swift/tree/v0.81.2) &bull; Swift 3.0, Xcode 8.0: [v1.0](https://github.com/groue/GRDB.swift/tree/v1.0) &bull; Swift 3.1, Xcode 8.3: [v1.3](https://github.com/groue/GRDB.swift/tree/v1.3.0) &bull; Swift 3.2, Xcode 9 beta: [v1.3](https://github.com/groue/GRDB.swift/tree/v1.3.0)

Follow [@groue](http://twitter.com/groue) on Twitter for release announcements and usage tips.


## What is this?

GRDB provides raw access to SQL and advanced SQLite features, because one sometimes enjoys a sharp tool. It has robust concurrency primitives, so that multi-threaded applications can efficiently use their databases. It grants your application models with persistence and fetching methods, so that you don't have to deal with SQL and raw database rows when you don't want to.

Compared to [SQLite.swift](http://github.com/stephencelis/SQLite.swift) or [FMDB](http://github.com/ccgus/fmdb), GRDB can spare you a lot of glue code. Compared to [Core Data](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreData/) or [Realm](http://realm.io), it can simplify your multi-threaded applications.

It comes with [up-to-date documentation](#documentation), [general articles](https://medium.com/@gwendal.roue), [sample code](#sample-code), and a lot of interesting resolved issues that may answer your eventual [questions](https://github.com/groue/GRDB.swift/issues?utf8=✓&q=is%3Aissue%20label%3Aquestion) and foster [best practices](https://github.com/groue/GRDB.swift/issues?q=is%3Aissue+label%3A%22best+practices%22).



---

<p align="center">
    <a href="#features">Features</a> &bull;
    <a href="#usage">Usage</a> &bull;
    <a href="#installation">Installation</a> &bull;
    <a href="#documentation">Documentation</a> &bull;
    <a href="#faq">FAQ</a>
</p>

---


## Features

GRDB ships with:

- [Access to raw SQL and SQLite](#sqlite-api)
- [Records](#records): fetching and persistence methods for your custom structs and class hierarchies
- [Query Interface](#the-query-interface): a swift way to avoid the SQL language
- [WAL Mode Support](#database-pools): extra performance for multi-threaded applications
- [Migrations](#migrations): transform your database as your application evolves
- [Database Observation](#database-changes-observation): track database transactions, get notified of database changes
- [Full-Text Search](#full-text-search)
- [Encryption](#encryption)
- [Support for Custom SQLite Builds](Documentation/CustomSQLiteBuilds.md)

Companion libraries that enhance and extend GRDB:

- [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB): track database changes in a reactive way, with [RxSwift](https://github.com/ReactiveX/RxSwift).
- [GRDBObjc](https://github.com/groue/GRDBObjc): FMDB-compatible bindings to GRDB.

More than a set of tools that leverage SQLite abilities, GRDB is also:

- **Safer**: read the blog post [Four different ways to handle SQLite concurrency](https://medium.com/@gwendal.roue/four-different-ways-to-handle-sqlite-concurrency-db3bcc74d00e)
- **Faster**: see [Comparing the Performances of Swift SQLite libraries](https://github.com/groue/GRDB.swift/wiki/Performance) for a comparison between raw SQLite, FMDB, SQLite.swift, Core Data, Realm, and GRDB.

For a general overview of how a protocol-oriented library impacts database accesses, have a look at [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3).


## Usage

Open a [connection](#database-connections) to the database:

```swift
import GRDB

// Simple database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// Enhanced multithreading based on SQLite's WAL mode
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

[Execute SQL statements](#executing-updates):

```swift
try dbQueue.inDatabase { db in
    try db.execute("""
        CREATE TABLE places (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          favorite BOOLEAN NOT NULL DEFAULT 0,
          latitude DOUBLE NOT NULL,
          longitude DOUBLE NOT NULL)
        """)

    try db.execute("""
        INSERT INTO places (title, favorite, latitude, longitude)
        VALUES (?, ?, ?, ?)
        """, arguments: ["Paris", true, 48.85341, 2.3488])
    
    let parisId = db.lastInsertedRowID
}
```

[Fetch database rows and values](#fetch-queries):

```swift
try dbQueue.inDatabase { db in
    let rows = try Row.fetchCursor(db, "SELECT * FROM places")
    while let row = try rows.next() {
        let title: String = row["title"]
        let isFavorite: Bool = row["favorite"]
        let coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
    }

    let placeCount = try Int.fetchOne(db, "SELECT COUNT(*) FROM places")! // Int
    let placeTitles = try String.fetchAll(db, "SELECT title FROM places") // [String]
}

// Extraction
let placeCount = try dbQueue.inDatabase { db in
    try Int.fetchOne(db, "SELECT COUNT(*) FROM places")!
}
```

Insert and fetch [records](#records):

```swift
struct Place {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// snip: turn Place into a "record" by adopting the protocols that
// provide fetching and persistence methods.

try dbQueue.inDatabase { db in
    var berlin = Place(
        id: nil,
        title: "Berlin",
        isFavorite: false,
        coordinate: CLLocationCoordinate2D(latitude: 52.52437, longitude: 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.isFavorite = true
    try berlin.update(db)
    
    // Fetch [Place] from SQL
    let places = try Place.fetchAll(db, "SELECT * FROM places")
}
```

Avoid SQL with the [query interface](#the-query-interface):

```swift
try dbQueue.inDatabase { db in
    try db.create(table: "places") { t in
        t.column("id", .integer).primaryKey()
        t.column("title", .text).notNull()
        t.column("favorite", .boolean).notNull().defaults(to: false)
        t.column("longitude", .double).notNull()
        t.column("latitude", .double).notNull()
    }
    
    // Place?
    let paris = try Place.fetchOne(db, key: 1)
    
    // Place?
    let titleColumn = Column("title")
    let berlin = try Place.filter(titleColumn == "Berlin").fetchOne(db)
    
    // [Place]
    let favoriteColumn = Column("favorite")
    let favoritePlaces = try Place
        .filter(favoriteColumn)
        .order(titleColumn)
        .fetchAll(db)
}
```


Documentation
=============

**GRDB runs on top of SQLite**: you should get familiar with the [SQLite FAQ](http://www.sqlite.org/faq.html). For general and detailed information, jump to the [SQLite Documentation](http://www.sqlite.org/docs.html).

**Reference**

- [GRDB Reference](http://groue.github.io/GRDB.swift/docs/1.3/index.html) (generated by [Jazzy](https://github.com/realm/jazzy))

**Getting Started**

- [Installation](#installation)
- [Database Connections](#database-connections): Connect to SQLite databases

**SQLite and SQL**

- [SQLite API](#sqlite-api): The low-level SQLite API &bull; [executing updates](#executing-updates) &bull; [fetch queries](#fetch-queries)

**Records and the Query Interface**

- [Records](#records): Fetching and persistence methods for your custom structs and class hierarchies.
- [Query Interface](#the-query-interface): A swift way to generate SQL &bull; [table creation](#database-schema) &bull; [requests](#requests)

**Application Tools**

- [Migrations](#migrations): Transform your database as your application evolves.
- [Full-Text Search](#full-text-search): Perform efficient and customizable full-text searches.
- [Database Changes Observation](#database-changes-observation): Perform post-commit and post-rollback actions.
- [FetchedRecordsController](#fetchedrecordscontroller): Automated tracking of changes in a query results, plus UITableView animations.
- [Encryption](#encryption): Encrypt your database with SQLCipher.
- [GRDB Extension Guide](Documentation/ExtendingGRDB.md): When a feature is lacking, extend GRDB right from your application.

**Good to Know**

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Data Protection](#data-protection)
- [Concurrency](#concurrency)
- [Performance](#performance)

[FAQ](#faq)

[Sample Code](#sample-code)


Installation
============

**The installation procedures below have GRDB use the version of SQLite that ships with the target operating system.**

See [Encryption](#encryption) for the installation procedure of GRDB with SQLCipher.

See [Custom SQLite builds](Documentation/CustomSQLiteBuilds.md) for the installation procedure of GRDB with a customized build of SQLite 3.20.0.


## CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects. To use GRDB with CocoaPods (version 1.2 or higher), specify in your `Podfile`:

```ruby
use_frameworks!
pod 'GRDB.swift'
```


## Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) automates the distribution of Swift code. To use GRDB with SPM, add a dependency to your `Package.swift` file:

```swift
let package = Package(
    ...
    dependencies: [
        .Package(url: "https://github.com/groue/GRDB.swift.git", majorVersion: 0)
    ]
)
```

Note that Linux is not currently supported.


## Carthage

Carthage does not support the variety of frameworks built by GRDB (standard SQLite, custom SQLite, SQLCipher).

Any pull request that has the `make test_CarthageBuild` command successfully complete will be greatly appreciated, though. Bring your local Xcode guru!


## Manually

1. [Download](https://github.com/groue/GRDB.swift/releases/tag/v1.3.0) a copy of GRDB, or clone its repository and make sure you use the latest tagged version with the `git checkout v1.3.0` command.

2. Embed the `GRDB.xcodeproj` project in your own project.

3. Add the `GRDBOSX`, `GRDBiOS`, or `GRDBWatchOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target (extension target for WatchOS).

4. Add the `GRDB.framework` from the targetted platform to the **Embedded Binaries** section of the **General**  tab of your application target (extension target for WatchOS).

See [GRDBDemoiOS](DemoApps/GRDBDemoiOS/GRDBDemoiOS) for an example of such integration.








Good To Know
============

This chapter covers general topics that you should be aware of.

- [Avoiding SQL Injection](#avoiding-sql-injection)
- [Error Handling](#error-handling)
- [Unicode](#unicode)
- [Memory Management](#memory-management)
- [Data Protection](#data-protection)
- [Concurrency](#concurrency)
- [Performance](#performance)


## Avoiding SQL Injection

SQL injection is a technique that lets an attacker nuke your database.

> ![XKCD: Exploits of a Mom](https://imgs.xkcd.com/comics/exploits_of_a_mom.png)
>
> https://xkcd.com/327/

Here is an example of code that is vulnerable to SQL injection:

```swift
// BAD BAD BAD
let name = textField.text
try dbQueue.inDatabase { db in
    try db.execute("UPDATE students SET name = '\(name)' WHERE id = \(id)")
}
```

If the user enters a funny string like `Robert'; DROP TABLE students; --`, SQLite will see the following SQL, and drop your database table instead of updating a name as intended:

```sql
UPDATE students SET name = 'Robert';
DROP TABLE students;
--' WHERE id = 1
```

To avoid those problems, **never embed raw values in your SQL queries**. The only correct technique is to provide [arguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html) to your SQL queries:

```swift
// Good
let name = textField.text
try dbQueue.inDatabase { db in
    try db.execute(
        "UPDATE students SET name = ? WHERE id = ?",
        arguments: [name, id])
}
```

See [Executing Updates](#executing-updates) for more information on statement arguments.



## Unicode

SQLite lets you store unicode strings in the database.

However, SQLite does not provide any unicode-aware string transformations or comparisons.


### Unicode functions

The `UPPER` and `LOWER` built-in SQLite functions are not unicode-aware:

```swift
// "JéRôME"
try String.fetchOne(db, "SELECT UPPER('Jérôme')")
```

GRDB extends SQLite with [SQL functions](#custom-sql-functions-and-aggregates) that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:

```swift
// "JÉRÔME"
let uppercase = DatabaseFunction.uppercase
try String.fetchOne(db, "SELECT \(uppercased.name)('Jérôme')")
```

Those unicode-aware string functions are also readily available in the [query interface](#sql-functions):

```
Player.select(nameColumn.uppercased)
```


### String Comparison

SQLite compares strings in many occasions: when you sort rows according to a string column, or when you use a comparison operator such as `=` and `<=`.

The comparison result comes from a *collating function*, or *collation*. SQLite comes with three built-in collations that do not support Unicode: [binary, nocase, and rtrim](https://www.sqlite.org/datatype3.html#collation).

GRDB comes with five extra collations that leverage unicode-aware comparisons based on the standard Swift String comparison functions and operators:

- `unicodeCompare` (uses the built-in `<=` and `==` Swift operators)
- `caseInsensitiveCompare`
- `localizedCaseInsensitiveCompare`
- `localizedCompare`
- `localizedStandardCompare`

A collation can be applied to a table column. All comparisons involving this column will then automatically trigger the comparison function:
    
```swift
try db.create(table: "players") { t in
    // Guarantees case-insensitive email unicity
    t.column("email", .text).unique().collate(.nocase)
    
    // Sort names in a localized case insensitive way
    t.column("name", .text).collate(.localizedCaseInsensitiveCompare)
}

// Players are sorted in a localized case insensitive way:
let players = try Player.order(nameColumn).fetchAll(db)
```

> :warning: **Warning**: SQLite *requires* host applications to provide the definition of any collation other than binary, nocase and rtrim. When a database file has to be shared or migrated to another SQLite library of platform (such as the Android version of your application), make sure you provide a compatible collation.

If you can't or don't want to define the comparison behavior of a column (see warning above), you can still use an explicit collation in SQL requests and in the [query interface](#the-query-interface):

```swift
let collation = DatabaseCollation.localizedCaseInsensitiveCompare
let players = try Player.fetchAll(db,
    "SELECT * FROM players ORDER BY name COLLATE \(collation.name))")
let players = try Player.order(nameColumn.collating(collation)).fetchAll(db)
```


**You can also define your own collations**:

```swift
let collation = DatabaseCollation("customCollation") { (lhs, rhs) -> NSComparisonResult in
    // return the comparison of lhs and rhs strings.
}
dbQueue.add(collation: collation) // Or dbPool.add(collation: ...)
```


## Memory Management

Both SQLite and GRDB use non-essential memory that help them perform better.

You can reclaim this memory with the `releaseMemory` method:

```swift
// Release as much memory as possible.
dbQueue.releaseMemory()
dbPool.releaseMemory()
```

This method blocks the current thread until all current database accesses are completed, and the memory collected.


### Memory Management on iOS

**The iOS operating system likes applications that do not consume much memory.**

[Database queues](#database-queues) and [pools](#database-pools) can call the `releaseMemory` method for you, when application receives memory warnings, and when application enters background: call the `setupMemoryManagement` method after creating the queue or pool instance:

```
let dbQueue = try DatabaseQueue(...)
dbQueue.setupMemoryManagement(in: UIApplication.sharedApplication())
```


## Data Protection

[Data Protection](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/StrategiesforImplementingYourApp/StrategiesforImplementingYourApp.html#//apple_ref/doc/uid/TP40007072-CH5-SW21) lets you protect files so that they are encrypted and unavailable until the device is unlocked.

Data protection can be enabled [globally](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/AddingCapabilities/AddingCapabilities.html#//apple_ref/doc/uid/TP40012582-CH26-SW30) for all files created by an application.

You can also explicitly protect a database, by configuring its enclosing *directory*. This will not only protect the database file, but also all [temporary files](https://www.sqlite.org/tempfiles.html) created by SQLite (including the persistent `.shm` and `.wal` files created by [database pools](#database-pools)).

For example, to explicitely use [complete](https://developer.apple.com/reference/foundation/fileprotectiontype/1616200-complete) protection:

```swift
// Paths
let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let directoryPath = (documentsPath as NSString).appendingPathComponent("database")
let databasePath = (directoryPath as NSString).appendingPathComponent("db.sqlite")

// Create directory if needed
let fm = FileManager.default
var isDirectory: ObjCBool = false
if !fm.fileExists(atPath: directoryPath, isDirectory: &isDirectory) {
    try fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: false)
} else if !isDirectory.boolValue {
    throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: nil)
}

// Enable data protection
try fm.setAttributes([.protectionKey : FileProtectionType.complete], ofItemAtPath: directoryPath)

// Open database
let dbQueue = try DatabaseQueue(path: databasePath)
```

When a database is protected, an application that runs in the background on a locked device won't be able to read or write from it. Instead, it will get [DatabaseError](#error-handling) with code [`SQLITE_IOERR`](https://www.sqlite.org/rescode.html#ioerr) (10) "disk I/O error", or [`SQLITE_AUTH`](https://www.sqlite.org/rescode.html#auth) (23) "not authorized".

You can catch those errors and wait for [UIApplicationDelegate.applicationProtectedDataDidBecomeAvailable(_:)](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623044-applicationprotecteddatadidbecom) or [UIApplicationProtectedDataDidBecomeAvailable](https://developer.apple.com/reference/uikit/uiapplicationprotecteddatadidbecomeavailable) notification in order to retry the failed database operation.




## Performance

GRDB is a reasonably fast library, and can deliver quite efficient SQLite access. See [Comparing the Performances of Swift SQLite libraries](https://github.com/groue/GRDB.swift/wiki/Performance) for an overview.

You'll find below general advice when you do look after performance:

- Focus
- Know your platform
- Use transactions
- Don't do useless work
- Learn about SQL strengths and weaknesses
- Avoid strings & dictionaries


### Performance tip: focus

You don't know which part of your program needs improvement until you have run a benchmarking tool.

Don't make any assumption, avoid optimizing code too early, and use [Instruments](https://developer.apple.com/library/ios/documentation/ToolsLanguages/Conceptual/Xcode_Overview/MeasuringPerformance.html).


### Performance tip: know your platform

If your application processes a huge JSON file and inserts thousands of rows in the database right from the main thread, it will quite likely become unresponsive, and provide a sub-quality user experience.

If not done yet, read the [Concurrency Programming Guide](https://developer.apple.com/library/ios/documentation/General/Conceptual/ConcurrencyProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008091) and learn how to perform heavy computations without blocking your application.

Most GRBD APIs are [synchronous](#database-connections). Spawning them into parallel queues is as easy as:

```swift
DispatchQueue.global().async { 
    dbQueue.inDatabase { db in
        // Perform database work
    }
    DispatchQueue.main.async { 
        // update your user interface
    }
}
```


### Performance tip: use transactions

Performing multiple updates to the database is much faster when executed inside a [transaction](#transactions-and-savepoints). This is because a transaction allows SQLite to postpone writing changes to disk until the final commit:

```swift
// Inefficient
try dbQueue.inDatabase { db in
    for player in players {
        try player.insert(db)
    }
}

// Efficient
try dbQueue.inTransaction { db in
    for player in players {
        try player.insert(db)
    }
    return .Commit
}
```


### Performance tip: don't do useless work

Obviously, no code is faster than any code.


**Don't fetch columns you don't use**

```swift
// SELECT * FROM players
try Player.fetchAll(db)

// SELECT id, name FROM players
try Player.select(idColumn, nameColumn).fetchAll(db)
```

If your Player type can't be built without other columns (it has non-optional properties for other columns), *do define and use a different type*.


**Don't fetch rows you don't use**

Use [fetchOne](#fetching-methods) when you need a single value, and otherwise limit your queries at the database level:

```swift
// Wrong way: this code may discard hundreds of useless database rows
let players = try Player.order(scoreColumn.desc).fetchAll(db)
let hallOfFame = players.prefix(5)

// Better way
let hallOfFame = try Player.order(scoreColumn.desc).limit(5).fetchAll(db)
```


**Don't copy values unless necessary**

Particularly: the Array returned by the `fetchAll` method, and the cursor returned by `fetchCursor` aren't the same:

`fetchAll` copies all values from the database into memory, when `fetchCursor` iterates database results as they are generated by SQLite, taking profit from SQLite efficiency.

You should only load arrays if you need to keep them for later use (such as iterating their contents in the main thread). Otherwise, use `fetchCursor`.

See [fetching methods](#fetching-methods) for more information about `fetchAll` and `fetchCursor`. See also the [Row.dataNoCopy](#data-and-memory-savings) method.


**Don't update rows unless necessary**

An UPDATE statement is costly: SQLite has to look for the updated row, update values, and write changes to disk.

When the overwritten values are the same as the existing ones, it's thus better to avoid performing the UPDATE statement.

The [Record](#record-class) class can help you: it provides [changes tracking](#changes-tracking):

```swift
if player.hasPersistentChangedValues {
    try player.update(db)
}
```


### Performance tip: learn about SQL strengths and weaknesses

Consider a simple use case: your store application has to display a list of authors with the number of available books:

- J. M. Coetzee (6)
- Herman Melville (1)
- Alice Munro (3)
- Kim Stanley Robinson (7)
- Oliver Sacks (4)

The following code is inefficient. It is an example of the [N+1 problem](http://stackoverflow.com/questions/97197/what-is-the-n1-selects-issue), because it performs one query to load the authors, and then N queries, as many as there are authors. This turns very inefficient as the number of authors grows:

```swift
// SELECT * FROM authors
let authors = try Author.fetchAll(db)
for author in authors {
    // SELECT COUNT(*) FROM books WHERE authorId = ...
    author.bookCount = try Book.filter(authorIdColumn == author.id).fetchCount(db)
}
```

Instead, perform *a single query*:

```swift
let sql = """
    SELECT authors.*, COUNT(books.id) AS bookCount
    FROM authors
    LEFT JOIN books ON books.authorId = authors.id
    GROUP BY authors.id
    """
let authors = try Author.fetchAll(db, sql)
```

In the example above, consider extending your Author with an extra bookCount property, or define and use a different type.

Generally, define indexes on your database tables, and use SQLite's efficient query planning:

- [Query Planning](https://www.sqlite.org/queryplanner.html)
- [CREATE INDEX](https://www.sqlite.org/lang_createindex.html)
- [The SQLite Query Planner](https://www.sqlite.org/optoverview.html)
- [EXPLAIN QUERY PLAN](https://www.sqlite.org/eqp.html)


### Performance tip: avoid strings & dictionaries

The String and Dictionary Swift types are better avoided when you look for the best performance.

Now GRDB [records](#records), for your convenience, do use strings and dictionaries:

```swift
class Player : Record {
    var id: Int64?
    var name: String
    var email: String
    
    required init(_ row: Row) {
        id = row["id"]       // String
        name = row["name"]   // String
        email = row["email"] // String
        super.init()
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id              // String
        container["name"] = name          // String
        container["email"] = email        // String
    }
}
```

When convenience hurts performance, you can still use records, but you have better avoiding their string and dictionary-based methods.

For example, when fetching values, prefer loading columns by index:

```swift
// Strings & dictionaries
let players = try Player.fetchAll(db)

// Column indexes
// SELECT id, name, email FROM players
let request = Player.select(idColumn, nameColumn, emailColumn)
let rows = try Row.fetchCursor(db, request)
while let row = try rows.next() {
    let id: Int64 = row[0]
    let name: String = row[1]
    let email: String = row[2]
    let player = Player(id: id, name: name, email: email)
    ...
}
```

When inserting values, use reusable [prepared statements](#prepared-statements), and set statements values with an *array*:

```swift
// Strings & dictionaries
for player in players {
    try player.insert(db)
}

// Prepared statement
let insertStatement = db.prepareStatement("INSERT INTO players (name, email) VALUES (?, ?)")
for player in players {
    // Only use the unsafe arguments setter if you are sure that you provide
    // all statement arguments. A mistake can store unexpected values in
    // the database.
    insertStatement.unsafeSetArguments([player.name, player.email])
    try insertStatement.execute()
}
```


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [GRDBDemoiOS](DemoApps/GRDBDemoiOS/GRDBDemoiOS): A sample iOS application.
- [WWDC Companion](https://github.com/groue/WWDCCompanion): A sample iOS application.
- Check `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- How to synchronize a database table with a JSON payload: [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift)


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [Vladimir Babin](https://github.com/Chiliec), [Pascal Edmond](https://github.com/pakko972), [Andrey Fidrya](https://github.com/zmeyc), [Cristian Filipov](https://github.com/cfilipov), [David Hart](https://github.com/hartbit), [Brad Lindsay](https://github.com/bfad), [@peter-ss](https://github.com/peter-ss), [Pierre-Loïc Raynaud](https://github.com/pierlo), [Stefano Rodriguez](https://github.com/sroddy) [Steven Schveighoffer](https://github.com/schveiguy), [@swiftlyfalling](https://github.com/swiftlyfalling), and [Kevin Wooten](https://github.com/kdubb) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [Mathieu "Kali" Poumeyrol](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.
