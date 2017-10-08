public struct HasOneThroughAssociation<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOneNonOptional,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOneNonOptional,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let middleAssociation: MiddleAssociation
    let rightAssociation: RightAssociation
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneThroughAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = RightAssociation.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneThroughAssociation {
        return HasOneThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation.mapRequest(transform))
    }
}

extension TableMapping {
    public static func hasOne<MiddleAssociation, RightAssociation>(_ rightAssociation: RightAssociation, through middleAssociation: MiddleAssociation)
        -> HasOneThroughAssociation<MiddleAssociation, RightAssociation>
        where
        MiddleAssociation: AssociationToOneNonOptional,
        MiddleAssociation.LeftAssociated == Self,
        MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated,
        RightAssociation: AssociationToOneNonOptional
    {
        return HasOneThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation)
    }
}
