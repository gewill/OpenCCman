// Same reduced reproducer, with the initializer in the primary declaration (#6949).
public struct ProbeColor {
    public var stringRepresentation: String
    fileprivate var storage: (any Sendable)?

    private init(stringRepresentation: String, underlyingStorage: (any Sendable)?) {
        self.stringRepresentation = stringRepresentation
        self.storage = underlyingStorage
    }
}

extension ProbeColor {
    public init(stringRepresentation: String) throws {
        self.init(stringRepresentation: stringRepresentation, underlyingStorage: nil)
    }
}

func constructProbe() throws -> ProbeColor {
    try ProbeColor(stringRepresentation: "#ffffff")
}
