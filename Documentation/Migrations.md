Migrations
==========

**Migrations** are a convenient way to alter your database schema over time in a consistent and easy way.

Migrations run in order, once and only once. When a user upgrades your application, only non-applied migrations are run.

Inside each migration, you typically [define and update your database tables](#database-schema) according to your evolving application needs:

```swift
var migrator = DatabaseMigrator()

// v1 database
migrator.registerMigration("v1") { db in
    try db.create(table: "players") { t in ... }
    try db.create(table: "books") { t in ... }
    try db.create(index: ...)
}

// v2 database
migrator.registerMigration("v2") { db in
    try db.alter(table: "players") { t in ... }
}

// Migrations for future versions will be inserted here:
//
// // v3 database
// migrator.registerMigration("v3") { db in
//     ...
// }
```

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrator.migrate(dbQueue)`.

**The memory of applied migrations is stored in the database itself** (in a reserved table).

You migrate the database up to the latest version with the `migrate(_:)` method:

```swift
try migrator.migrate(dbQueue) // or migrator.migrate(dbPool)
```

To migrate a database up to a specific version, use `migrate(_:upTo:)`:

```swift
try migrator.migrate(dbQueue, upTo: "v2")
```

Migrations can only run forward:

```swift
try migrator.migrate(dbQueue, upTo: "v2")
try migrator.migrate(dbQueue, upTo: "v1")
// fatal error: database is already migrated beyond migration "v1"
```


## Advanced Database Schema Changes

SQLite does not support many schema changes, and won't let you drop a table column with "ALTER TABLE ... DROP COLUMN ...", for example.

Yet any kind of schema change is still possible. The SQLite documentation explains in detail how to do so: https://www.sqlite.org/lang_altertable.html#otheralter. This technique requires the temporary disabling of foreign key checks, and is supported by the `registerMigrationWithDeferredForeignKeyCheck` function:

```swift
// Add a NOT NULL constraint on players.name:
migrator.registerMigrationWithDeferredForeignKeyCheck("AddNotNullCheckOnName") { db in
    try db.create(table: "new_players") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text).notNull()
    }
    try db.execute("INSERT INTO new_players SELECT * FROM players")
    try db.drop(table: "players")
    try db.rename(table: "new_players", to: "players")
}
```

While your migration code runs with disabled foreign key checks, those are re-enabled and checked at the end of the migration, regardless of eventual errors.
