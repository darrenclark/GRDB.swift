/// An array of database values, also called "row value"
///
/// See https://sqlite.org/rowvalue.html
///
/// TODO: consider enhanced support for this type when
/// SQLite ~> 3.15.0 https://sqlite.org/changes.html#version_3_15_0
/// or iOS >= 10.3.1+ https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
struct RowValue {
    // TODO: hide this array
    let dbValues : [DatabaseValue]
    
    var count: Int {
        return dbValues.count
    }
    
    var containsNonNullValue: Bool {
        return dbValues.contains { !$0.isNull }
    }
    
    init(_ dbValues : [DatabaseValue]) {
        self.dbValues = dbValues
    }
}

extension RowValue : Hashable {
    var hashValue: Int {
        return dbValues.reduce(0) { $0 ^ $1.hashValue }
    }
    
    static func == (lhs: RowValue, rhs: RowValue) -> Bool {
        if lhs.dbValues.count != rhs.dbValues.count { return false }
        for (lhs, rhs) in zip(lhs.dbValues, rhs.dbValues) {
            if lhs != rhs { return false }
        }
        return true
    }
}
