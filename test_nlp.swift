import Foundation
let text = "select 21 and 25 of june"
if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
    let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
    for match in matches {
        print("Match:", (text as NSString).substring(with: match.range))
        if let date = match.date {
            print("Found date:", date)
        }
    }
}
