import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct HasOneThrough_BelongsTo_HasOne_Fixture {
    
    // Book -> Library <- LibraryAddress
    struct LibraryAddress : Codable, TableMapping, RowConvertible, Persistable {
        static let databaseTableName = "libraryAddresses"
        let city: String
        let libraryId: Int
    }
    
    struct Library : Codable, TableMapping, RowConvertible, Persistable {
        static let databaseTableName = "libraries"
        static let address = hasOne(LibraryAddress.self)
        let id: Int64
        let name: String
    }
    
    struct Book : Codable, TableMapping, RowConvertible, Persistable {
        static let databaseTableName = "books"
        static let library = belongsTo(Library.self)
        static let libraryAddress = hasOne(Library.address, through: library)
        static let optionalLibrary = belongsTo(optional: Library.self)
        static let optionalLibraryAddress = hasOne(optional: Library.address, through: optionalLibrary)
        let isbn: String
        let title: String
        let libraryId: Int64?
    }
    
    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("fixtures") { db in
            try db.create(table: "libraries") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            
            let library1 = Library(row: ["id": 1, "name": "Public Library"])
            try library1.insert(db)
            let library2 = Library(row: ["id": 2, "name": "Secret Library"])
            try library2.insert(db)
            let library3 = Library(row: ["id": 3, "name": "Youth Library"])
            try library3.insert(db)
            let library4 = Library(row: ["id": 4, "name": "Lost Library"])
            try library4.insert(db)
            
            try db.create(table: "libraryAddresses") { t in
                t.column("city", .text)
                t.column("libraryId", .integer).unique().references("libraries")
            }
            
            try LibraryAddress(row: ["city": "Paris", "libraryId": library1.id]).insert(db)
            try LibraryAddress(row: ["city": "London", "libraryId": library2.id]).insert(db)
            try LibraryAddress(row: ["city": "Barcelona", "libraryId": library3.id]).insert(db)
            
            try db.create(table: "books") { t in
                t.column("isbn", .text).primaryKey()
                t.column("title", .text)
                t.column("libraryId", .integer).references("libraries")
            }
            
            try Book(row: ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil]).insert(db)
            try Book(row: ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": library1.id]).insert(db)
            try Book(row: ["isbn": "book3", "title": "Walden", "libraryId": library1.id]).insert(db)
            try Book(row: ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": library1.id]).insert(db)
            try Book(row: ["isbn": "book5", "title": "Querelle de Brest", "libraryId": library2.id]).insert(db)
            try Book(row: ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": library2.id]).insert(db)
            try Book(row: ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": library3.id]).insert(db)
            try Book(row: ["isbn": "book8", "title": "Necronomicon", "libraryId": library4.id]).insert(db)
        }
        
        return migrator
    }
}
