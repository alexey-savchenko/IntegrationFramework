import Foundation

/// Extension providing safe array access utilities.
extension Array {
    /// Safely accesses an element at the specified index.
    ///
    /// Returns `nil` if the index is out of bounds instead of crashing.
    ///
    /// ## Usage
    /// ```swift
    /// let array = [1, 2, 3]
    /// print(array[safe: 1])  // Optional(2)
    /// print(array[safe: 10]) // nil
    /// ```
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: The element at the specified index, or `nil` if out of bounds.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
