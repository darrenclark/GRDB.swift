Error Handling
==============

GRDB can throw [DatabaseError](#databaseerror), [PersistenceError](#persistenceerror), or crash your program with a [fatal error](#fatal-errors).

Considering that a local database is not some JSON loaded from a remote server, GRDB focuses on **trusted databases**. Dealing with [untrusted databases](#how-to-deal-with-untrusted-inputs) requires extra care.

- [DatabaseError](#databaseerror)
- [PersistenceError](#persistenceerror)
- [Fatal Errors](#fatal-errors)
- [How to Deal with Untrusted Inputs](#how-to-deal-with-untrusted-inputs)
- [Error Log](#error-log)


## DatabaseError

**DatabaseError** are thrown on SQLite errors:

```swift
do {
    try db.execute(
        "INSERT INTO pets (masterId, name) VALUES (?, ?)",
        arguments: [1, "Bobby"])
} catch let error as DatabaseError {
    // The SQLite error code: 19 (SQLITE_CONSTRAINT)
    error.resultCode
    
    // The extended error code: 787 (SQLITE_CONSTRAINT_FOREIGNKEY)
    error.extendedResultCode
    
    // The eventual SQLite message: FOREIGN KEY constraint failed
    error.message
    
    // The eventual erroneous SQL query
    // "INSERT INTO pets (masterId, name) VALUES (?, ?)"
    error.sql
    
    // Full error description:
    // "SQLite error 787 with statement `INSERT INTO pets (masterId, name)
    //  VALUES (?, ?)` arguments [1, "Bobby"]: FOREIGN KEY constraint failed""
    error.description
}
```

**SQLite uses codes to distinguish between various errors:**

```swift
do {
    try ...
} catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
    // foreign key constraint error
} catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
    // any other constraint error
} catch let error as DatabaseError {
    // any other database error
}
```

In the example above, `error.extendedResultCode` is a precise [extended result code](https://www.sqlite.org/rescode.html#extended_result_code_list), and `error.resultCode` is a less precise [primary result code](https://www.sqlite.org/rescode.html#primary_result_code_list). Extended result codes are refinements of primary result codes, as `SQLITE_CONSTRAINT_FOREIGNKEY` is to `SQLITE_CONSTRAINT`, for example. See [SQLite result codes](https://www.sqlite.org/rescode.html) for more information.

As a convenience, extended result codes match their primary result code in a switch statement:

```swift
do {
    try ...
} catch let error as DatabaseError {
    switch error.extendedResultCode {
    case ResultCode.SQLITE_CONSTRAINT_FOREIGNKEY:
        // foreign key constraint error
    case ResultCode.SQLITE_CONSTRAINT:
        // any other constraint error
    default:
        // any other database error
    }
}
```

> :warning: **Warning**: SQLite has progressively introduced extended result codes accross its versions. For example, `SQLITE_CONSTRAINT_FOREIGNKEY` wasn't introduced yet on iOS 8.1. The [SQLite release notes](http://www.sqlite.org/changes.html) are unfortunately not quite clear about that: write your handling of extended result codes with care.


## PersistenceError

**PersistenceError** is thrown by the [Persistable](#persistable-protocol) protocol, in a single case: when the `update` method could not find any row to update:

```swift
do {
    try player.update(db)
} catch PersistenceError.recordNotFound {
    // There was nothing to update
}
```


## Fatal Errors

**Fatal errors notify that the program, or the database, has to be changed.**

They uncover programmer errors, false assumptions, and prevent misuses. Here are a few examples:

- **The code asks for a non-optional value, when the database contains NULL:**
    
    ```swift
    // fatal error: could not convert NULL to String.
    let name: String = row["name"]
    ```
    
    Solution: fix the contents of the database, use [NOT NULL constraints](#create-tables), or load an optional:
    
    ```swift
    let name: String? = row["name"]
    ```

- **The code asks for a Date, when the database contains garbage:**
    
    ```swift
    // fatal error: could not convert "Mom’s birthday" to Date.
    let date: Date? = row["date"]
    ```
    
    Solution: fix the contents of the database, or use [DatabaseValue](#databasevalue) to handle all possible cases:
    
    ```swift
    let dbValue: DatabaseValue = row["date"]
    if dbValue.isNull {
        // Handle NULL
    if let date = Date.fromDatabaseValue(dbValue) {
        // Handle valid date
    } else {
        // Handle invalid date
    }
    ```

- **The database can't guarantee that the code does what it says:**

    ```swift
    // fatal error: table players has no unique index on column email
    try Player.deleteOne(db, key: ["email": "arthur@example.com"])
    ```
    
    Solution: add a unique index to the players.email column, or use the `deleteAll` method to make it clear that you may delete more than one row:
    
    ```swift
    try Player.filter(Column("email") == "arthur@example.com").deleteAll(db)
    ```

- **Database connections are not reentrant:**
    
    ```swift
    // fatal error: Database methods are not reentrant.
    dbQueue.inDatabase { db in
        dbQueue.inDatabase { db in
            ...
        }
    }
    ```
    
    Solution: avoid reentrancy, and instead pass a database connection along.


## How to Deal with Untrusted Inputs

Let's consider the code below:

```swift
let sql = "SELECT ..."

// Some untrusted arguments for the query
let arguments: [String: Any] = ...
let rows = try Row.fetchCursor(db, sql, arguments: StatementArguments(arguments))

while let row = try rows.next() {
    // Some untrusted database value:
    let date: Date? = row[0]
}
```

It has two opportunities to throw fatal errors:

- **Untrusted arguments**: The dictionary may contain values that do not conform to the [DatabaseValueConvertible protocol](#values), or may miss keys required by the statement.
- **Untrusted database content**: The row may contain a non-null value that can't be turned into a date.

In such a situation, you can still avoid fatal errors by exposing and handling each failure point, one level down in the GRDB API:

```swift
// Untrusted arguments
if let arguments = StatementArguments(arguments) {
    let statement = try db.makeSelectStatement(sql)
    try statement.validate(arguments: arguments)
    statement.unsafeSetArguments(arguments)
    
    var cursor = try Row.fetchCursor(statement)
    while let row = try iterator.next() {
        // Untrusted database content
        let dbValue: DatabaseValue = row[0]
        if dbValue.isNull {
            // Handle NULL
        if let date = Date.fromDatabaseValue(dbValue) {
            // Handle valid date
        } else {
            // Handle invalid date
        }
    }
}
```

See [prepared statements](#prepared-statements) and [DatabaseValue](#databasevalue) for more information.


## Error Log

**SQLite can be configured to invoke a callback function containing an error code and a terse error message whenever anomalies occur.**

It is recommended that you setup, early in the lifetime of your application, the error logging callback:

```swift
Database.logError = { (resultCode, message) in
    NSLog("%@", "SQLite error \(resultCode): \(message)")
}
```

See [The Error And Warning Log](https://sqlite.org/errlog.html) for more information.

