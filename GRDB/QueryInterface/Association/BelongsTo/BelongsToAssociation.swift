public struct BelongsToAssociation<Left, Right> : Association, AssociationToOne, AssociationToOneNonOptional where
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
            .map { (left: $0.origin, right: $0.destination) }
    }
}

extension BelongsToAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<Right>
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> BelongsToAssociation {
        return BelongsToAssociation(
            joinMappingRequest: joinMappingRequest,
            rightRequest: transform(self.rightRequest))
    }
}

extension TableMapping {
    public static func belongsTo<Right>(_ right: Right.Type) -> BelongsToAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName)
        return BelongsToAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func belongsTo<Right>(_ right: Right.Type, from originColumns: String...) -> BelongsToAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName,
            originColumns: originColumns)
        return BelongsToAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func belongsTo<Right>(_ right: Right.Type, from originColumns: [String], to destinationColumns: [String]) -> BelongsToAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName,
            originColumns: originColumns,
            destinationColumns: destinationColumns)
        return BelongsToAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
}
