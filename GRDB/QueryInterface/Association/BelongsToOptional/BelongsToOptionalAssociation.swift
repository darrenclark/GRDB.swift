public struct BelongsToOptionalAssociation<Left, Right> : Association, AssociationToOne where
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

extension BelongsToOptionalAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<Right>
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> BelongsToOptionalAssociation {
        return BelongsToOptionalAssociation(
            joinMappingRequest: joinMappingRequest,
            rightRequest: transform(self.rightRequest))
    }
}

extension TableMapping {
    public static func belongsTo<Right>(optional right: Right.Type) -> BelongsToOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName)
        return BelongsToOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func belongsTo<Right>(optional right: Right.Type, from originColumns: String...) -> BelongsToOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName,
            originColumns: originColumns)
        return BelongsToOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
    
    public static func belongsTo<Right>(optional right: Right.Type, from originColumns: [String], to destinationColumns: [String]) -> BelongsToOptionalAssociation<Self, Right> where Right: TableMapping {
        let joinMappingRequest = JoinMappingRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName,
            originColumns: originColumns,
            destinationColumns: destinationColumns)
        return BelongsToOptionalAssociation(joinMappingRequest: joinMappingRequest, rightRequest: Right.all())
    }
}
