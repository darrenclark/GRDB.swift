// To run this playground, select and build the GRDBOSX scheme.

import GRDB


var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)

struct Player : RowConvertible, MutablePersistable {
    var id: Int64?
    let name: String
    let score: Int
    
    // GRDB
    
    enum Columns {
        static let id = Column("id").with(keyPath: \Player.id)
        static let name = Column("name").with(keyPath: \Player.name)
        static let score = Column("score").with(keyPath: \Player.score)
    }
    
    static var databaseTableName = "players"
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        score = row[Columns.score]
    }
    
    func encode(to container: inout PersistenceContainer) {
        encode(Columns.id, to: &container)
        encode(Columns.name, to: &container)
        encode(Columns.score, to: &container)
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}


try! dbQueue.inDatabase { db in
    try db.create(table: "players") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text)
        t.column("score", .integer)
    }
    
    var player = Player(row: ["id": 1, "name": "Arthur", "score": 1000])
    try player.insert(db)
    
    try print(Player.filter(Player.Columns.id == 1).fetchOne(db)!.name)
//    try print(Player.filter(Player.Columns.score >= 1000).fetchOne(db)!.name)
}
