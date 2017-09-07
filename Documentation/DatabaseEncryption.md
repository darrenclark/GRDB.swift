Database Encryption
===================

**GRDB can encrypt your database with [SQLCipher](http://sqlcipher.net) v3.4.1.**

You can use [CocoaPods](http://cocoapods.org/) (version 1.2 or higher), and specify in your `Podfile`:

```ruby
use_frameworks!
pod 'GRDBCipher'
```

Alternatively, perform a manual installation of GRDB and SQLCipher:

1. Clone the GRDB git repository, checkout the latest tagged version, and download SQLCipher sources:
    
    ```sh
    cd [GRDB directory]
    git checkout v1.3.0
    git submodule update --init SQLCipher/src
    ```
    
2. Embed the `GRDB.xcodeproj` project in your own project.

3. Add the `GRDBCipherOSX` or `GRDBCipheriOS` target in the **Target Dependencies** section of the **Build Phases** tab of your application target.

4. Add the `GRDBCipher.framework` from the targetted platform to the **Embedded Binaries** section of the **General**  tab of your target.


**You create and open an encrypted database** by providing a passphrase to your [database connection](#database-connections):

```swift
import GRDBCipher

var configuration = Configuration()
configuration.passphrase = "secret"
let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
```

**You can change the passphrase** of an already encrypted database:

```swift
try dbQueue.change(passphrase: "newSecret")
```

Providing a passphrase won't encrypt a clear-text database that already exists, though. SQLCipher can't do that, and you will get an error instead: `SQLite error 26: file is encrypted or is not a database`.

**To encrypt an existing clear-text database**, create a new and empty encrypted database, and copy the content of the clear-text database in it. The technique to do that is [documented](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868/1) by SQLCipher. With GRDB, it gives:

```swift
// The clear-text database
let clearDBQueue = try DatabaseQueue(path: "/path/to/clear.db")

// The encrypted database, at some distinct location:
var configuration = Configuration()
configuration.passphrase = "secret"
let encryptedDBQueue = try DatabaseQueue(path: "/path/to/encrypted.db", configuration: config)

try clearDBQueue.inDatabase { db in
    try db.execute("ATTACH DATABASE ? AS encrypted KEY ?", arguments: [encryptedDBQueue.path, "secret"])
    try db.execute("SELECT sqlcipher_export('encrypted')")
    try db.execute("DETACH DATABASE encrypted")
}

// Now the copy is done, and the clear-text database can be deleted.
```

