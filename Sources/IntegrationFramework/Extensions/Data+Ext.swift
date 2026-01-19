import Foundation

/// Extension providing JSON formatting utilities for Data.
extension Data {
    /// Returns a pretty-printed JSON string representation of the data.
    ///
    /// Attempts to parse the data as JSON and format it with indentation
    /// for better readability.
    ///
    /// - Returns: A formatted JSON string, or `nil` if the data is not valid JSON.
    var prettyPrintedJSONString: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return prettyPrintedString
    }
    
    /// Prints the data as pretty-formatted JSON to the console.
    ///
    /// If the data cannot be formatted as JSON, prints an error message instead.
    func prettyPrint() {
        if let string = prettyPrintedJSONString {
            print(string)
        } else {
            print("Failed to pretty print JSON data")
        }
    }
}
