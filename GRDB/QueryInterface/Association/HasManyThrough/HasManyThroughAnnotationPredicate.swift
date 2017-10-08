public struct HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where
    MiddleAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: Association,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let annotation: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>
    let predicate: (SQLExpression) -> SQLExpression
    
    func map(_ transform: @escaping (SQLExpression) -> SQLExpression) -> HasManyThroughAnnotationPredicate {
        return HasManyThroughAnnotationPredicate(
            annotation: annotation,
            predicate: { transform(self.predicate($0)) })
    }
}

extension HasManyThroughAnnotation {
    func having(_ predicate: @escaping (SQLExpression) -> SQLExpression) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> {
        return HasManyThroughAnnotationPredicate(
            annotation: self,
            predicate: predicate)
    }
}

public prefix func ! <MiddleAssociation, RightAssociation, Annotation>(value: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation>) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> {
    return value.map { !$0 }
}

public func == <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation?) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 == rhs }
}

public func != <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation?) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 != rhs }
}

public func === <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation?) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 === rhs }
}

public func !== <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation?) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 !== rhs }
}

public func < <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 < rhs }
}

public func <= <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 <= rhs }
}

public func > <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 > rhs }
}

public func >= <MiddleAssociation, RightAssociation, Annotation>(lhs: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>, rhs: Annotation) -> HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 >= rhs }
}
