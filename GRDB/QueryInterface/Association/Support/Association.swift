public protocol Association {
    associatedtype LeftAssociated: TableMapping
    associatedtype RightAssociated: TableMapping

    var rightRequest: QueryInterfaceRequest<RightAssociated> { get }
    func mapping(_ db: Database) throws -> [(left: String, right: String)]
}

extension Association {
    func reversedMapping(_ db: Database) throws -> [(left: String, right: String)] {
        return try mapping(db).map { (left: $0.right, right: $0.left ) }
    }
}

public protocol AssociationToOne : Association { }

public protocol AssociationToOneNonOptional : AssociationToOne { }
