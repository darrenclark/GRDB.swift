public struct HasManyAnnotationPredicate<Left, Right, Annotation> where
    Left: TableMapping,
    Right: TableMapping
{
    let annotation: HasManyAnnotation<Left, Right, Annotation>
    let predicate: (SQLExpression) -> SQLExpression
    
    func map(_ transform: @escaping (SQLExpression) -> SQLExpression) -> HasManyAnnotationPredicate {
        return HasManyAnnotationPredicate(
            annotation: annotation,
            predicate: { transform(self.predicate($0)) })
    }
}

extension HasManyAnnotation {
    func having(_ predicate: @escaping (SQLExpression) -> SQLExpression) -> HasManyAnnotationPredicate<Left, Right, Annotation> {
        return HasManyAnnotationPredicate(
            annotation: self,
            predicate: predicate)
    }
}

public prefix func ! <Left, Right, Annotation>(value: HasManyAnnotationPredicate<Left, Right, Annotation>) -> HasManyAnnotationPredicate<Left, Right, Annotation> {
    return value.map { !$0 }
}

public func == <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation?) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 == rhs }
}

public func != <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation?) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 != rhs }
}

public func === <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation?) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 === rhs }
}

public func !== <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation?) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 !== rhs }
}

public func < <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 < rhs }
}

public func <= <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 <= rhs }
}

public func > <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 > rhs }
}

public func >= <Left, Right, Annotation>(lhs: HasManyAnnotation<Left, Right, Annotation>, rhs: Annotation) -> HasManyAnnotationPredicate<Left, Right, Annotation> where Annotation: SQLExpressible {
    return lhs.having { $0 >= rhs }
}
