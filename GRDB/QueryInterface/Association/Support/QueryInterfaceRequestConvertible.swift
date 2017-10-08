public protocol QueryInterfaceRequestConvertible {
    associatedtype RowDecoder
    var queryInterfaceRequest: QueryInterfaceRequest<RowDecoder> { get }
}

extension QueryInterfaceRequest : QueryInterfaceRequestConvertible {
    public var queryInterfaceRequest: QueryInterfaceRequest<RowDecoder> { return self }
}
