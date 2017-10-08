public struct HasManyThroughAssociation<MiddleAssociation, RightAssociation> where
    MiddleAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: Association,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let middleAssociation: MiddleAssociation
    let rightAssociation: RightAssociation
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasManyThroughAssociation : RequestDerivableWrapper {
    public typealias WrappedRequest = RightAssociation.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasManyThroughAssociation {
        return HasManyThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation.mapRequest(transform))
    }
}

extension TableMapping {
    public static func hasMany<MiddleAssociation, RightAssociation>(_ rightAssociation: RightAssociation, through middleAssociation: MiddleAssociation)
        -> HasManyThroughAssociation<MiddleAssociation, RightAssociation>
        where
        MiddleAssociation.LeftAssociated == Self,
        MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
    {
        return HasManyThroughAssociation(
            middleAssociation: middleAssociation,
            rightAssociation: rightAssociation)
    }
}
