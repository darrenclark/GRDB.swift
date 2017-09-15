// To run this playground, select and build the GRDBOSX scheme.

@testable import GRDB


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
    
    _ = try Player.select((Player.Columns.id == 1) && Player.Columns.score > 1000).fetchOne(db)
//    _ = try Player.select(Player.Columns.id).fetchOne(db)
//    _ = try Player.order(Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(1 == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int64>(sqlExpression: 1.databaseValue) == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int64?>(sqlExpression: 1.databaseValue) == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64>(sqlExpression: 1.databaseValue)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64?>(sqlExpression: 1.databaseValue)).fetchOne(db)
//    _ = try Player.filter(nil == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int64>(sqlExpression: DatabaseValue.null) == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int64?>(sqlExpression: DatabaseValue.null) == Player.Columns.id).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == nil).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64>(sqlExpression: DatabaseValue.null)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64?>(sqlExpression: DatabaseValue.null)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.id == Player.Columns.id).fetchOne(db)
//
//    _ = try Player.select(Player.Columns.score).fetchOne(db)
//    _ = try Player.order(Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(1 == Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int>(sqlExpression: 1.databaseValue) == Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int?>(sqlExpression: 1.databaseValue) == Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int>(sqlExpression: 1.databaseValue)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int?>(sqlExpression: 1.databaseValue)).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int>(sqlExpression: DatabaseValue.null) == Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(AnyTypedExpression<Int?>(sqlExpression: DatabaseValue.null) == Player.Columns.score).fetchOne(db)
//    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int>(sqlExpression: DatabaseValue.null)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int?>(sqlExpression: DatabaseValue.null)).fetchOne(db)
//    _ = try Player.filter(Player.Columns.score == Player.Columns.score).fetchOne(db)
    
//    try Player.filter(Player.Columns.id == Player.Columns.score).fetchOne(db)
//    try Player.filter(Player.Columns.score >= 1000).fetchOne(db)
}
