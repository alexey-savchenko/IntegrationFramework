import Foundation

/// Extension providing JSON formatting utilities for Encodable types.
extension Encodable {
    /// Returns a pretty-printed JSON string representation of the object.
    ///
    /// Encodes the object to JSON with pretty printing formatting
    /// for better readability.
    ///
    /// - Returns: A formatted JSON string, or `nil` if encoding fails.
    var prettyPrintedJSONString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Prints the object as pretty-formatted JSON to the console.
    ///
    /// If the object cannot be encoded to JSON, prints an error message instead.
    func prettyPrint() {
        if let string = prettyPrintedJSONString {
            print(string)
        } else {
            print("Failed to pretty print Encodable")
        }
    }
}
