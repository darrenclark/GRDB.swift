/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column {
    /// The hidden rowID column
    public static let rowID = Column("rowid")
    
    /// The name of the column
    public let name: String
    
    /// Creates a column given its name.
    public init(_ name: String) {
        self.name = name
    }
}

extension Column : SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return name.quotedDatabaseIdentifier
    }
}

public class ColumnedPartialKeyPath<Root> {
    let column: Column
    var keyPath: PartialKeyPath<Root> {
        return _keyPath
    }
    let _keyPath: PartialKeyPath<Root>
    
    init(column: Column, keyPath: PartialKeyPath<Root>) {
        self.column = column
        self._keyPath = keyPath
    }
}

public class ColumnedKeyPath<Root, Value> : ColumnedPartialKeyPath<Root> {
    override var keyPath: KeyPath<Root, Value> {
        return super.keyPath as! KeyPath<Root, Value>
    }
    
    init(column: Column, keyPath: KeyPath<Root, Value>) {
        super.init(column: column, keyPath: keyPath)
    }
}

//public class ColumnedWritableKeyPath<Root, Value> : ColumnedKeyPath<Root, Value> {
//    override var keyPath: WritableKeyPath<Root, Value> {
//        return super.keyPath as! WritableKeyPath<Root, Value>
//    }
//
//    init(column: Column, keyPath: WritableKeyPath<Root, Value>) {
//        super.init(column: column, keyPath: keyPath)
//    }
//}

extension Column {
    public func with<Root, Value>(keyPath: KeyPath<Root, Value>) -> ColumnedKeyPath<Root, Value> {
        return ColumnedKeyPath(column: self, keyPath: keyPath)
    }

//    public func with<Root, Value>(keyPath: WritableKeyPath<Root, Value>) -> ColumnedWritableKeyPath<Root, Value> {
//        return ColumnedWritableKeyPath(column: self, keyPath: keyPath)
//    }
}

extension Row {
    public subscript<Root, Value>(_ column: ColumnedKeyPath<Root, Value>) -> Value where Value: DatabaseValueConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: ColumnedKeyPath<Root, Value>) -> Value where Value: DatabaseValueConvertible & StatementColumnConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: ColumnedKeyPath<Root, Value>) -> Value._Wrapped? where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: ColumnedKeyPath<Root, Value>) -> Value._Wrapped? where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible& StatementColumnConvertible {
        return self[column.column]
    }
    
    // TODO: dataNoCopy
}

extension MutablePersistable {
    public func encode<Value>(_ column: ColumnedKeyPath<Self, Value>, to container: inout PersistenceContainer) where Value: DatabaseValueConvertible {
        container[column.column] = self[keyPath: column.keyPath]
    }

    public func encode<Value>(_ column: ColumnedKeyPath<Self, Value>, to container: inout PersistenceContainer) where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible {
        if let v = self[keyPath: column.keyPath] as? DatabaseValueConvertible {
            container[column.column] = v
        } else {
            container[column.column] = nil
        }
    }
}

extension ColumnedPartialKeyPath : SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return column.expressionSQL(&arguments)
    }
}
