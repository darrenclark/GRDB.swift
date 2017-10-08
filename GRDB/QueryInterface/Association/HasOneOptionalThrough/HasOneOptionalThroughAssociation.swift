public struct HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOne,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOne,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let middleAssociation: MiddleAssociation
    let rightAssociation: RightAssociation
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneOptionalThroughAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = RightAssociation.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneOptionalThroughAssociation {
        return HasOneOptionalThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation.mapRequest(transform))
    }
}

extension TableMapping {
    public static func hasOne<MiddleAssociation, RightAssociation>(optional rightAssociation: RightAssociation, through middleAssociation: MiddleAssociation)
        -> HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>
        where
        MiddleAssociation.LeftAssociated == Self,
        MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
    {
        return HasOneOptionalThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation)
    }
}
