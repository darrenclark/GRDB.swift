public struct HasOneAssociation<Left, Right> : Association, AssociationToOne, AssociationToOneNonOptional where
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

extension HasOneAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<Right>
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneAssociation {
        return HasOneAssociation(
            joinMappingRequest: joinMappingRequest,
            rightRequest: transform(self.rightRequest))
    }
}

extension TableMapping {
    public static func hasOne<Right>(_ right: Right.Type) -> HasOneAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName)
        return HasOneAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func hasOne<Right>(_ right: Right.Type, from originColumns: String...) -> HasOneAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName,
            originColumns: originColumns)
        return HasOneAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func hasOne<Right>(_ right: Right.Type, from originColumns: [String], to destinationColumns: [String]) -> HasOneAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName,
            originColumns: originColumns,
            destinationColumns: destinationColumns)
        return HasOneAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
}
