Records
=======

**On top of the [SQLite API](#sqlite-api), GRDB provides protocols and a class** that help manipulating database rows as regular objects named "records":

```swift
try dbQueue.inDatabase { db in
    if let place = try Place.fetchOne(db, key: 1) {
        place.isFavorite = true
        try place.update(db)
    }
}
```

Of course, you need to open a [database connection](#database-connections), and [create a database table](#database-schema) first.

Your custom structs and classes can adopt each protocol individually, and opt in to focused sets of features. Or you can subclass the `Record` class, and get the full toolkit in one go: fetching methods, persistence methods, and changes tracking. See the [list of record methods](#list-of-record-methods) for an overview.

> :point_up: **Note**: if you are familiar with Core Data's NSManagedObject or Realm's Object, you may experience a cultural shock: GRDB records are not uniqued, and do not auto-update. This is both a purpose, and a consequence of protocol-oriented programming. You should read [How to build an iOS application with SQLite and GRDB.swift](https://medium.com/@gwendal.roue/how-to-build-an-ios-application-with-sqlite-and-grdb-swift-d023a06c29b3) for a general introduction.

**Overview**

- [Inserting Records](#inserting-records)
- [Fetching Records](#fetching-records)
- [Updating Records](#updating-records)
- [Deleting Records](#deleting-records)
- [Counting Records](#counting-records)

**Protocols and the Record class**

- [Record Protocols Overview](#record-protocols-overview)
- [RowConvertible Protocol](#rowconvertible-protocol)
- [TableMapping Protocol](#tablemapping-protocol)
- [Persistable Protocol](#persistable-protocol)
    - [Persistence Methods](#persistence-methods)
    - [Customizing the Persistence Methods](#customizing-the-persistence-methods)
    - [Conflict Resolution](#conflict-resolution)
- [Record Class](#record-class)
    - [Changes Tracking](#changes-tracking)
- [The Implicit RowID Primary Key](#the-implicit-rowid-primary-key)
- **[List of Record Methods](#list-of-record-methods)**

**Records, Swift Archival & Serialization**

- [Codable Records](#codable-records)


### Inserting Records

To insert a record in the database, subclass the [Record](#record-class) class or adopt the [Persistable](#persistable-protocol) protocol, and call the `insert` method:

```swift
class Player : Record { ... }

let player = Player(name: "Arthur", email: "arthur@example.com")
try player.insert(db)
```


### Fetching Records

[Record](#record-class) subclasses and types that adopt the [RowConvertible](#rowconvertible-protocol) protocol can be fetched from the database:

```swift
class Player : Record { ... }
let players = try Player.fetchAll(db, "SELECT ...", arguments: ...) // [Player]
```

Add the [TableMapping](#tablemapping-protocol) protocol and you can stop writing SQL:

```swift
let spain = try Country.fetchOne(db, key: "ES") // Country?
let players = try Player                        // [Player]
    .filter(Column("email") != nil)
    .order(Column("name"))
    .fetchAll(db)
```

See [fetching methods](#fetching-methods), and the [query interface](#the-query-interface).


### Updating Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be updated in the database:

```swift
let player = try Player.fetchOne(db, key: 1)!
player.name = "Arthur"
try player.update(db)
```

[Record](#record-class) subclasses track changes, so that you can avoid useless updates:

```swift
let player = try Player.fetchOne(db, key: 1)!
player.name = "Arthur"
if player.hasPersistentChangedValues {
    try player.update(db)
}
```

For batch updates, execute an [SQL query](#executing-updates):

```swift
try db.execute("UPDATE players SET synchronized = 1")
```


### Deleting Records

[Record](#record-class) subclasses and types that adopt the [Persistable](#persistable-protocol) protocol can be deleted from the database:

```swift
let player = try Player.fetchOne(db, key: 1)!
try player.delete(db)
```

Such records can also delete according to primary key or any unique index:

```swift
try Player.deleteOne(db, key: 1)
try Player.deleteOne(db, key: ["email": "arthur@example.com"])
try Country.deleteAll(db, keys: ["FR", "US"])
```

For batch deletes, see the [query interface](#the-query-interface):

```swift
try Player.filter(emailColumn == nil).deleteAll(db)
```


### Counting Records

[Record](#record-class) subclasses and types that adopt the [TableMapping](#tablemapping-protocol) protocol can be counted:

```swift
let playerWithEmailCount = try Player.filter(emailColumn != nil).fetchCount(db)  // Int
```


You can now jump to:

- [Record Protocols Overview](#record-protocols-overview)
- [RowConvertible Protocol](#rowconvertible-protocol)
- [TableMapping Protocol](#tablemapping-protocol)
- [Persistable Protocol](#persistable-protocol)
- [Record Class](#record-class)
- [List of Record Methods](#list-of-record-methods)
- [The Query Interface](#the-query-interface)


## Record Protocols Overview

**GRDB ships with three record protocols**. Your own types will adopt one or several of them, according to the abilities you want to extend your types with.

- [RowConvertible](#rowconvertible-protocol) is able to **read**: it grants the ability to efficiently decode raw database row.
    
    Imagine you want to load places from the `places` database table.
    
    One way to do it is to load raw database rows:
    
    ```swift
    func fetchPlaceRows(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, "SELECT * FROM places")
    }
    ```
    
    The problem is that [raw rows](#row-queries) are not easy to deal with, and you may prefer using a proper `Place` type:
    
    ```swift
    // Dedicated model
    struct Place { ... }
    func fetchPlaces(_ db: Database) throws -> [Place] {
        let rows = try Row.fetchAll(db, "SELECT * FROM places")
        return rows.map { row in
            Place(
                id: row["id"],
                title: row["title"],
                coordinate: CLLocationCoordinate2D(
                    latitude: row["latitude"],
                    longitude: row["longitude"]))
            )
        }
    }
    ```
    
    This code is verbose, and so you define an `init(row:)` initializer:
    
    ```swift
    // Row initializer
    struct Place {
        init(row: Row) {
            id = row["id"]
            ...
        }
    }
    func fetchPlaces(_ db: Database) throws -> [Place] {
        let rows = try Row.fetchAll(db, "SELECT * FROM places")
        return rows.map { Place(row: $0) }
    }
    ```
    
    Now you notice that this code may use a lot of memory when you have many rows: a full array of database rows is created in order to build an array of places. Furthermore, rows that have copied from the database have lost the ability to directly load values from SQLite: that's inefficient. You thus use a [database cursor](#cursors), which is both lazy and efficient:
    
    ```swift
    // Cursor for efficiency
    func fetchPlaces(_ db: Database) throws -> [Place] {
        let rowCursor = try Row.fetchCursor(db, "SELECT * FROM places")
        let placeCursor = rowCursor.map { Place(row: $0) }
        return try Array(placeCursor)
    }
    ```
    
    That's better. And that's what RowConvertible does, with a little performance bonus, and in a single line:
    
    ```swift
    struct Place : RowConvertible {
        init(row: Row) { ... }
    }
    func fetchPlaces(_ db: Database) throws -> [Place] {
        return try Place.fetchAll(db, "SELECT * FROM places")
    }
    ```
    
    RowConvertible is not able to build SQL requests, though. For that, you also need TableMapping:
    
- [TableMapping](#tablemapping-protocol) is able to **build requests without SQL**:
    
    ```swift
    struct Place : TableMapping { ... }
    // SELECT * FROM places ORDER BY title
    let request = Place.order(Column("title"))
    ```
    
    When a type adopts both TableMapping and RowConvertible, it can load from those requests:
    
    ```swift
    struct Place : TableMapping, RowConvertible { ... }
    try dbQueue.inDatabase { db in
        let places = try Place.order(Column("title")).fetchAll(db)
        let paris = try Place.fetchOne(key: 1)
    }
    ```

- [Persistable](#persistable-protocol) is able to **write**: it can create, update, and delete rows in the database:
    
    ```swift
    struct Place : Persistable { ... }
    try dbQueue.inDatabase { db in
        try Place.delete(db, key: 1)
        try Place(...).insert(db)
    }
    ```


## RowConvertible Protocol

**The RowConvertible protocol grants fetching methods to any type** that can be built from a database row:

```swift
protocol RowConvertible {
    /// Row initializer
    init(row: Row)
}
```

**To use RowConvertible**, subclass the [Record](#record-class) class, or adopt it explicitely. For example:

```swift
struct Place {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
}

extension Place : RowConvertible {
    init(row: Row) {
        id = row["id"]
        title = row["title"]
        coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
    }
}
```

Rows also accept keys of type `Column`:

```swift
extension Place : RowConvertible {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }
    
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
    }
}
```

See [column values](#column-values) for more information about the `row[]` subscript.

> :point_up: **Note**: for performance reasons, the same row argument to `init(row:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

**The `init(row:)` initializer can be automatically generated** when your type adopts the standard `Decodable` protocol. See [Codable Records](#codable-records) for more information.

RowConvertible allows adopting types to be fetched from SQL queries:

```swift
try Place.fetchCursor(db, "SELECT ...", arguments:...) // A Cursor of Place
try Place.fetchAll(db, "SELECT ...", arguments:...)    // [Place]
try Place.fetchOne(db, "SELECT ...", arguments:...)    // Place?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll` and `fetchOne` methods. See [StatementArguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html) for more information about the query arguments.


## TableMapping Protocol

**Adopt the TableMapping protocol** on top of [RowConvertible](#rowconvertible-protocol), and you are granted with the full [query interface](#the-query-interface).

```swift
protocol TableMapping {
    static var databaseTableName: String { get }
    static var databaseSelection: [SQLSelectable] { get }
}
```

The `databaseTableName` type property is the name of a database table. `databaseSelection` is optional, and documented in the [Columns Selected by a Request](#columns-selected-by-a-request) chapter.

**To use TableMapping**, subclass the [Record](#record-class) class, or adopt it explicitely. For example:

```swift
extension Place : TableMapping {
    static let databaseTableName = "places"
}
```

Adopting types can be fetched without SQL, using the [query interface](#the-query-interface):

```swift
// SELECT * FROM places WHERE name = 'Paris'
let paris = try Place.filter(nameColumn == "Paris").fetchOne(db)
```

TableMapping can also fetch records by primary key:

```swift
try Player.fetchOne(db, key: 1)              // Player?
try Player.fetchAll(db, keys: [1, 2, 3])     // [Player]

try Country.fetchOne(db, key: "FR")          // Country?
try Country.fetchAll(db, keys: ["FR", "US"]) // [Country]
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// SELECT * FROM documents WHERE rowid = 1
try Document.fetchOne(db, key: 1)            // Document?
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// SELECT * FROM citizenships WHERE playerID = 1 AND countryISOCode = 'FR'
try Citizenship.fetchOne(db, key: ["playerID": 1, "countryISOCode": "FR"]) // Citizenship?
```


## Persistable Protocol

**GRDB provides two protocols that let adopting types create, update, and delete rows in the database:**

```swift
protocol MutablePersistable : TableMapping {
    /// The name of the database table (from TableMapping)
    static var databaseTableName: String { get }
    
    /// Defines the values persisted in the database
    func encode(to container: inout PersistenceContainer)
    
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsert(with rowID: Int64, for column: String?)
}
```

```swift
protocol Persistable : MutablePersistable {
    /// Non-mutating version of the optional didInsert(with:for:)
    func didInsert(with rowID: Int64, for column: String?)
}
```

Yes, two protocols instead of one. Both grant exactly the same advantages. Here is how you pick one or the other:

- *If your type is a struct that mutates on insertion*, choose `MutablePersistable`.
    
    For example, your table has an INTEGER PRIMARY KEY and you want to store the inserted id on successful insertion. Or your table has a UUID primary key, and you want to automatically generate one on insertion.

- Otherwise, stick with `Persistable`. Particularly if your type is a class.

The `encode(to:)` method defines which [values](#values) (Bool, Int, String, Date, Swift enums, etc.) are assigned to database columns.

**`encode(to:)` can be automatically generated** when your type adopts the standard `Encodable` protocol. See [Codable Records](#codable-records) for more information.

The optional `didInsert` method lets the adopting type store its rowID after successful insertion. If your table has an INTEGER PRIMARY KEY column, you are likely to define this method. Otherwise, you can safely ignore it. It is called from a protected dispatch queue, and serialized with all database updates.

**To use those protocols**, subclass the [Record](#record-class) class, or adopt one of them explicitely. For example:

```swift
extension Place : MutablePersistable {
    
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["latitude"] = coordinate.latitude
        container["longitude"] = coordinate.longitude
    }
    
    // Update id upon successful insertion:
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

var paris = Place(
    id: nil,
    title: "Paris",
    coordinate: CLLocationCoordinate2D(latitude: 48.8534100, longitude: 2.3488000))

try paris.insert(db)
paris.id   // some value
```

Persistence containers also accept keys of type `Column`:

```swift
extension Place : MutablePersistable {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
}
```


### Persistence Methods

[Record](#record-class) subclasses and types that adopt [Persistable](#persistable-protocol) are given default implementations for methods that insert, update, and delete:

```swift
// Instance methods
try place.insert(db)               // INSERT
try place.update(db)               // UPDATE
try place.update(db, columns: ...) // UPDATE
try place.save(db)                 // Inserts or updates
try place.delete(db)               // DELETE
place.exists(db)

// Type methods
Place.deleteAll(db)                // DELETE
Place.deleteAll(db, keys:...)      // DELETE
Place.deleteOne(db, key:...)       // DELETE
```

- `insert`, `update`, `save` and `delete` can throw a [DatabaseError](#error-handling) whenever an SQLite integrity check fails.

- `update` can also throw a PersistenceError of type recordNotFound, should the update fail because there is no matching row in the database.
    
    When saving an object that may or may not already exist in the database, prefer the `save` method:

- `save` makes sure your values are stored in the database.

    It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly perfoms an INSERT if the record has no primary key, or a null primary key.
    
    Despite the fact that it may execute two SQL statements, `save` behaves as an atomic operation: GRDB won't allow any concurrent thread to sneak in (see [concurrency](#concurrency)).

- `delete` returns whether a database row was deleted or not.

**All primary keys are supported**, including composite primary keys that span several columns, and the [implicit rowid primary key](#the-implicit-rowid-primary-key).


### Customizing the Persistence Methods

Your custom type may want to perform extra work when the persistence methods are invoked.

For example, it may want to have its UUID automatically set before inserting. Or it may want to validate its values before saving.

When you subclass [Record](#record-class), you simply have to override the customized method, and call `super`:

```swift
class Player : Record {
    var uuid: UUID?
    
    override func insert(_ db: Database) throws {
        if uuid == nil {
            uuid = UUID()
        }
        try super.insert(db)
    }
}
```

If you use the raw [Persistable](#persistable-protocol) protocol, use one of the *special methods* `performInsert`, `performUpdate`, `performSave`, `performDelete`, or `performExists`:

```swift
struct Link : Persistable {
    var url: URL
    
    func insert(_ db: Database) throws {
        try validate()
        try performInsert(db)
    }
    
    func update(_ db: Database, columns: Set<String>) throws {
        try validate()
        try performUpdate(db, columns: columns)
    }
    
    func validate() throws {
        if url.host == nil {
            throw ValidationError("url must be absolute.")
        }
    }
}
```

> :point_up: **Note**: the special methods `performInsert`, `performUpdate`, etc. are reserved for your custom implementations. Do not use them elsewhere. Do not provide another implementation for those methods.
>
> :point_up: **Note**: it is recommended that you do not implement your own version of the `save` method. Its default implementation forwards the job to `update` or `insert`: these are the methods that may need customization, not `save`.


### Conflict Resolution

**Insertions and updates can create conflicts**: for example, a query may attempt to insert a duplicate row that violates a unique index.

Those conflicts normally end with an error. Yet SQLite let you alter the default behavior, and handle conflicts with specific policies. For example, the `INSERT OR REPLACE` statement handles conflicts with the "replace" policy which replaces the conflicting row instead of throwing an error.

The [five different policies](https://www.sqlite.org/lang_conflict.html) are: abort (the default), replace, rollback, fail, and ignore.

**SQLite let you specify conflict policies at two different places:**

- At the table level
    
    ```swift
    // CREATE TABLE players (
    //     id INTEGER PRIMARY KEY,
    //     email TEXT UNIQUE ON CONFLICT REPLACE
    // )
    try db.create(table: "players") { t in
        t.column("id", .integer).primaryKey()
        t.column("email", .text).unique(onConflict: .replace) // <--
    }
    
    // Despite the unique index on email, both inserts succeed.
    // The second insert replaces the first row:
    try db.execute("INSERT INTO players (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute("INSERT INTO players (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```
    
- At the query level:
    
    ```swift
    // CREATE TABLE players (
    //     id INTEGER PRIMARY KEY,
    //     email TEXT UNIQUE
    // )
    try db.create(table: "players") { t in
        t.column("id", .integer).primaryKey()
        t.column("email", .text)
    }
    
    // Again, despite the unique index on email, both inserts succeed.
    try db.execute("INSERT OR REPLACE INTO players (email) VALUES (?)", arguments: ["arthur@example.com"])
    try db.execute("INSERT OR REPLACE INTO players (email) VALUES (?)", arguments: ["arthur@example.com"])
    ```

When you want to handle conflicts at the query level, specify a custom `persistenceConflictPolicy` in your type that adopts the MutablePersistable or Persistable protocol. It will alter the INSERT and UPDATE queries run by the `insert`, `update` and `save` [persistence methods](#persistence-methods):

```swift
protocol MutablePersistable {
    /// The policy that handles SQLite conflicts when records are inserted
    /// or updated.
    ///
    /// This property is optional: its default value uses the ABORT policy
    /// for both insertions and updates, and has GRDB generate regular
    /// INSERT and UPDATE queries.
    static var persistenceConflictPolicy: PersistenceConflictPolicy { get }
}

struct Player : MutablePersistable {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)
}

// INSERT OR REPLACE INTO players (...) VALUES (...)
try player.insert(db)
```

> :point_up: **Note**: the `ignore` policy does not play well at all with the `didInsert` method which notifies the rowID of inserted records. Choose your poison:
>
> - if you specify the `ignore` policy at the table level, don't implement the `didInsert` method: it will be called with some random id in case of failed insert.
> - if you specify the `ignore` policy at the query level, the `didInsert` method is never called.
>
> :warning: **Warning**: [`ON CONFLICT REPLACE`](https://www.sqlite.org/lang_conflict.html) may delete rows so that inserts and updates can succeed. Those deletions are not reported to [transaction observers](#transactionobserver-protocol) (this might change in a future release of SQLite).


## Record Class

**Record** is a class that is designed to be subclassed, and provides the full toolkit in one go: fetching and persistence methods, as well as changes tracking (see the [list of record methods](#list-of-record-methods) for an overview).

Record subclasses inherit their features from the [RowConvertible, TableMapping, and Persistable](#record-protocols-overview) protocols. Check their documentation for more information.

For example, here is a fully functional Record subclass:

```swift
class Place : Record {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
    
    /// The table name
    override class var databaseTableName: String {
        return "places"
    }
    
    /// Initialize from a database row
    required init(row: Row) {
        id = row["id"]
        title = row["title"]
        coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
        super.init(row: row)
    }
    
    /// The values persisted in the database
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["latitude"] = coordinate.latitude
        container["longitude"] = coordinate.longitude
    }
    
    /// Update record ID after a successful insertion
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
```


### Changes Tracking

**The [Record](#record-class) class provides changes tracking.**

The `update()` [method](#persistence-methods) always executes an UPDATE statement. When the record has not been edited, this costly database access is generally useless.

Avoid it with the `hasPersistentChangedValues` property, which returns whether the record has changes that have not been saved:

```swift
// Saves the player if it has changes that have not been saved:
if player.hasPersistentChangedValues {
    try player.save(db)
}
```

The `hasPersistentChangedValues` flag is false after a record has been fetched or saved into the database. Subsequent modifications may set it, or not: `hasPersistentChangedValues` is based on value comparison. **Setting a property to the same value does not set the changed flag**:

```swift
let player = Player(name: "Barbara", score: 750)
player.hasPersistentChangedValues // true

try player.insert(db)
player.hasPersistentChangedValues // false

player.name = "Barbara"
player.hasPersistentChangedValues // false

player.score = 1000
player.hasPersistentChangedValues // true
player.persistentChangedValues    // ["score": 750]
```

For an efficient algorithm which synchronizes the content of a database table with a JSON payload, check [JSONSynchronization.playground](Playgrounds/JSONSynchronization.playground/Contents.swift).


## The Implicit RowID Primary Key

**All SQLite tables have a primary key.** Even when the primary key is not explicit:

```swift
// No explicit primary key
try db.create(table: "events") { t in
    t.column("message", .text)
    t.column("date", .datetime)
}

// No way to define an explicit primary key
try db.create(virtualTable: "books", using: FTS4()) { t in
    t.column("title")
    t.column("author")
    t.column("body")
}
```

The implicit primary key is stored in the hidden column `rowid`. Hidden means that `SELECT *` does not select it, and yet it can be selected and queried: `SELECT *, rowid ... WHERE rowid = 1`.

Some GRDB methods will automatically use this hidden column when a table has no explicit primary key:

```swift
// SELECT * FROM events WHERE rowid = 1
let event = try Event.fetchOne(db, key: 1)

// DELETE FROM books WHERE rowid = 1
try Book.deleteOne(db, key: 1)
```


### Exposing the RowID Column

**By default, a record type that wraps a table without any explicit primary key doesn't know about the hidden rowid column.**

Without primary key, records don't have any identity, and the [persistence method](#persistence-methods) can behave in undesired fashion: `update()` throws errors, `save()` always performs insertions and may break constraints, `exists()` is always false.

When SQLite won't let you provide an explicit primary key (as in [full-text](#full-text-search) tables, for example), you may want to make your record type fully aware of the hidden rowid column:

1. Have the `databaseSelection` static property (from the [TableMapping](#tablemapping-protocol) protocol) return the hidden rowid column:
    
    ```swift
    struct Event : TableMapping {
        static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
    }
    
    // When you subclass Record, you need an override:
    class Book : Record {
        override class var databaseSelection: [SQLSelectable] {
            return [AllColums(), Column.rowID]
        }
    }
    ```
    
    GRDB will then select the `rowid` column by default:
    
    ```swift
    // SELECT *, rowid FROM events
    let events = try Event.fetchAll(db)
    ```

2. Have `init(row:)` from the [RowConvertible](#rowconvertible-protocol) protocol consume the "rowid" column:
    
    ```swift
    struct Event : RowConvertible {
        var id: Int64?
        
        init(row: Row) {
            id = row["rowid"]
        }
    }
    ```
    
    If you prefer using the Column type from the [query interface](#the-query-interface), use the `Column.rowID` constant:
    
    ```swift
    init(row: Row) {
        id = row[.rowID]
    }
    ```
    
    Your fetched records will then know their ids:
    
    ```swift
    let event = try Event.fetchOne(db)!
    event.id // some value
    ```

3. Encode the rowid in `encode(to:)`, and keep it in the `didInsert(with:for:)` method (both from the [Persistable and MutablePersistable](#persistable-protocol) protocols):
    
    ```swift
    struct Event : MutablePersistable {
        var id: Int64?
        
        func encode(to container: inout PersistenceContainer) {
            container[.rowID] = id
            container["message"] = message
            container["date"] = date
        }
        
        mutating func didInsert(with rowID: Int64, for column: String?) {
            id = rowID
        }
    }
    ```
    
    You will then be able to track your record ids, update them, or check for their existence:
    
    ```swift
    let event = Event(message: "foo", date: Date())
    
    // Insertion sets the record id:
    try event.insert(db)
    event.id // some value
    
    // Record can be updated:
    event.message = "bar"
    try event.update(db)
    
    // Record knows if it exists:
    event.exists(db) // true
    ```


## List of Record Methods

This is the list of record methods, along with their required protocols. The [Record Class](#record-class) adopts all these protocols.

| Method | Protocols | Notes |
| ------ | --------- | :---: |
| **Inserting and Updating Records** | | |
| `try record.insert(db)` | [Persistable](#persistable-protocol) | |
| `try record.save(db)` | [Persistable](#persistable-protocol) | |
| `try record.update(db)` | [Persistable](#persistable-protocol) | |
| `try record.update(db, columns: ...)` | [Persistable](#persistable-protocol) | |
| **Checking Record Existence** | | |
| `record.exists(db)` | [Persistable](#persistable-protocol) | |
| **Deleting Records** | | |
| `try record.delete(db)` | [Persistable](#persistable-protocol) | |
| `try Type.deleteOne(db, key: ...)` | [Persistable](#persistable-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `try Type.deleteAll(db)` | [Persistable](#persistable-protocol) | |
| `try Type.deleteAll(db, keys: ...)` | [Persistable](#persistable-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `try Type.filter(...).deleteAll(db)` | [Persistable](#persistable-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Counting Records** | | |
| `Type.fetchCount(db)` | [TableMapping](#tablemapping-protocol) | |
| `Type.filter(...).fetchCount(db)` | [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Record [Cursors](#cursors)** | | |
| `Type.fetchCursor(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetchCursor(db, keys: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchCursor(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchCursor(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchCursor(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Record Arrays** | | |
| `Type.fetchAll(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetchAll(db, keys: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchAll(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchAll(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchAll(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Fetching Individual Records** | | |
| `Type.fetchOne(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | |
| `Type.fetchOne(db, key: ...)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-1">¹</a> |
| `Type.fetchOne(db, sql)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-3">³</a> |
| `Type.fetchOne(statement)` | [RowConvertible](#rowconvertible-protocol) | <a href="#list-of-record-methods-4">⁴</a> |
| `Type.filter(...).fetchOne(db)` | [RowConvertible](#rowconvertible-protocol) & [TableMapping](#tablemapping-protocol) | <a href="#list-of-record-methods-2">²</a> |
| **Changes Tracking** | | |
| `record.hasPersistentChangedValues` | [Record](#record-class) | |
| `record.persistentChangedValues` | [Record](#record-class) | |

<a name="list-of-record-methods-1">¹</a> All unique keys are supported: primary keys (single-column, composite, [implicit RowID](#the-implicit-rowid-primary-key)) and unique indexes:

```swift
try Player.fetchOne(db, key: 1)                               // Player?
try Player.fetchOne(db, key: ["email": "arthur@example.com"]) // Player?
try Country.fetchAll(db, keys: ["FR", "US"])                  // [Country]
```

<a name="list-of-record-methods-2">²</a> See [Fetch Requests](#requests):

```swift
let request = Player.filter(emailColumn != nil).order(nameColumn)
let players = try request.fetchAll(db)  // [Player]
let count = try request.fetchCount(db)  // Int
```

<a name="list-of-record-methods-3">³</a> See [SQL queries](#fetch-queries):

```swift
let player = try Player.fetchOne("SELECT * FROM players WHERE id = ?", arguments: [1]) // Player?
```

<a name="list-of-record-methods-4">⁴</a> See [Prepared Statements](#prepared-statements):

```swift
let statement = try db.makeSelectStatement("SELECT * FROM players WHERE id = ?")
let player = try Player.fetchOne(statement, arguments: [1])  // Player?
```


## Codable Records

[Swift Archival & Serialization](https://github.com/apple/swift-evolution/blob/master/proposals/0166-swift-archival-serialization.md) was introduced with Swift 4.

GRDB provides default implementations for [`RowConvertible.init(row:)`](#rowconvertible-protocol) and [`Persistable.encode(to:)`](#persistable-protocol) for record types that also adopt an archival protocol (`Codable`, `Encodable` or `Decodable`). When all their properties are themselves codable, Swift generates the archiving methods, and you don't need to write them down:

```swift
// This is just enough...
struct Player: RowConvertible, Persistable, Codable {
    static let databaseTableName = "players"
    
    let name: String
    let score: Int
}

// ... so that you can save and fetch players:
try dbQueue.inDatabase { db in
    try Player(name: "Arthur", score: 100).insert(db)
    let players = try Player.fetchAll(db)
}
```

> :point_up: **Note**: Some types have a different way to encode and decode themselves in a standard archive vs. the database. For example, [Date](#date-and-datecomponents) saves itself as a numerical timestamp (archive) or a string (database). When such an ambiguity happens, GRDB always favors customized database encoding and decoding.
