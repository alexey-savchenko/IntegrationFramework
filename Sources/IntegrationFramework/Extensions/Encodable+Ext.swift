import Foundation

extension Encodable {
    var prettyPrintedJSONString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    func prettyPrint() {
        if let string = prettyPrintedJSONString {
            print(string)
        } else {
            print("Failed to pretty print Encodable")
        }
    }
}
