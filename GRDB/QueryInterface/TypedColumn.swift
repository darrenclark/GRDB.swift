public struct TypedColumn<Root, Value> {
    public let column: Column
    let keyPath: KeyPath<Root, Value>
    
    public init(_ name: String, _ keyPath: KeyPath<Root, Value>) {
        self.column = Column(name)
        self.keyPath = keyPath
    }
}

extension Row {
    public subscript<Root, Value>(_ column: TypedColumn<Root, Value>) -> Value where Value: DatabaseValueConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: TypedColumn<Root, Value>) -> Value where Value: DatabaseValueConvertible & StatementColumnConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: TypedColumn<Root, Value>) -> Value._Wrapped? where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible {
        return self[column.column]
    }
    
    public subscript<Root, Value>(_ column: TypedColumn<Root, Value>) -> Value._Wrapped? where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible& StatementColumnConvertible {
        return self[column.column]
    }
    
    // TODO: dataNoCopy
}

extension MutablePersistable {
    public func encode<Value>(_ column: TypedColumn<Self, Value>, to container: inout PersistenceContainer) where Value: DatabaseValueConvertible {
        container[column.column] = self[keyPath: column.keyPath]
    }
    
    public func encode<Value>(_ column: TypedColumn<Self, Value>, to container: inout PersistenceContainer) where Value: _OptionalProtocol, Value._Wrapped: DatabaseValueConvertible {
        if let v = self[keyPath: column.keyPath] as? DatabaseValueConvertible {
            container[column.column] = v
        } else {
            container[column.column] = nil
        }
    }
}

extension TypedColumn : SQLTypedExpression {
    public typealias SQLValueType = Value
    public var sqlExpression: SQLExpression { return column }
}
