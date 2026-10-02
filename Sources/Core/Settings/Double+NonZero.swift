import Foundation

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
