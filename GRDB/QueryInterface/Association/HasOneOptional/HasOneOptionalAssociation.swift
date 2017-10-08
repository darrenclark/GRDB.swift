public struct HasOneOptionalAssociation<Left, Right> : Association, AssociationToOne where
    Left: TableMapping,
    Right: TableMapping
{
    // Association
    public typealias LeftAssociated = Left
    public typealias RightAssociated = Right

    let joinMappingRequest: JoinMappingRequest
    public let rightRequest: WrappedRequest
    
    public func mapping(_ db: Database) throws -> [(left: String, right: String)] {
        return try joinMappingRequest
            .fetchMapping(db)
            .map { (left: $0.destination, right: $0.origin) }
    }
}

extension HasOneOptionalAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<Right>
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneOptionalAssociation {
        return HasOneOptionalAssociation(
            joinMappingRequest: joinMappingRequest,
            rightRequest: transform(self.rightRequest))
    }
}

extension TableMapping {
    public static func hasOne<Right>(optional right: Right.Type) -> HasOneOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName)
        return HasOneOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func hasOne<Right>(optional right: Right.Type, from originColumns: String...) -> HasOneOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName,
            originColumns: originColumns)
        return HasOneOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func hasOne<Right>(optional right: Right.Type, from originColumns: [String], to destinationColumns: [String]) -> HasOneOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName,
            originColumns: originColumns,
            destinationColumns: destinationColumns)
        return HasOneOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
}
