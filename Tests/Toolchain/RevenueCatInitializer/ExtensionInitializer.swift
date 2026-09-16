// Reduced reproducer of RevenueCat #6949; no RevenueCat or Apple framework dependency.
public struct ProbeColor {
    public var stringRepresentation: String
    fileprivate var storage: (any Sendable)?
}

extension ProbeColor {
    public init(stringRepresentation: String) throws {
        self.init(stringRepresentation: stringRepresentation, underlyingStorage: nil)
    }
}

private extension ProbeColor {
    init(stringRepresentation: String, underlyingStorage: (any Sendable)?) {
        self.stringRepresentation = stringRepresentation
        self.storage = underlyingStorage
    }
}

func constructProbe() throws -> ProbeColor {
    try ProbeColor(stringRepresentation: "#ffffff")
}
