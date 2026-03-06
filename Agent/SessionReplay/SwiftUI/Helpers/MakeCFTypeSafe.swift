#if os(iOS)
import CoreGraphics

private func makeSafe<T: CFTypeRef>(value: T?, expectedTypeID: CFTypeID) -> T? {
    guard let value = value, CFGetTypeID(value)
                                            == expectedTypeID else {
        return nil
    }
    return value
}

internal extension CGColor {
    var safeColor: CGColor? { makeSafe(value: self, expectedTypeID: CGColor.typeID) }
}
#endif
