import Foundation

public struct RangeError: Error, CustomStringConvertible {
    public let token: String
    public var description: String { "can't read range entry \"\(token)\"" }
}

/// Parses standard range notation into the set of hand classes it covers.
///
///     22+            every pair
///     JJ-77          pairs from sevens to jacks
///     ATs+           ATs, AJs, AQs, AKs
///     A5s-A2s        suited wheel aces
///     T9s-65s        suited connectors from 65s up to T9s
///     AK             both AKs and AKo
public func parseRange(_ text: String) throws -> Set<String> {
    var hands = Set<String>()
    for raw in text.split(separator: ",") {
        let token = raw.trimmingCharacters(in: .whitespaces)
        if token.isEmpty { continue }
        try hands.formUnion(expand(token))
    }
    return hands
}

/// How many of the 1326 starting combos a range covers.
public func comboCount(_ hands: Set<String>) -> Int {
    hands.reduce(0) { total, hand in
        if hand.count == 2 { return total + 6 }
        return total + (hand.hasSuffix("s") ? 4 : 12)
    }
}

private struct Shape {
    let high: Int
    let low: Int
    /// "s", "o", or "" for both (pairs are always "").
    let kind: String
}

private func shape(_ text: String, token: String) throws -> Shape {
    let chars = Array(text)
    guard chars.count == 2 || chars.count == 3,
          let a = rankValue(Character(chars[0].uppercased())),
          let b = rankValue(Character(chars[1].uppercased()))
    else { throw RangeError(token: token) }
    var kind = ""
    if chars.count == 3 {
        kind = chars[2].lowercased()
        guard (kind == "s" || kind == "o"), a != b else { throw RangeError(token: token) }
    }
    return Shape(high: max(a, b), low: min(a, b), kind: kind)
}

private func names(high: Int, low: Int, kind: String) -> [String] {
    let base = "\(rankChar(high))\(rankChar(low))"
    if high == low { return [base] }
    return kind.isEmpty ? [base + "s", base + "o"] : [base + kind]
}

private func expand(_ token: String) throws -> Set<String> {
    var out = Set<String>()

    if token.hasSuffix("+") {
        let s = try shape(String(token.dropLast()), token: token)
        if s.high == s.low {
            for v in s.high...12 { out.formUnion(names(high: v, low: v, kind: "")) }
        } else {
            for low in s.low..<s.high { out.formUnion(names(high: s.high, low: low, kind: s.kind)) }
        }
        return out
    }

    let parts = token.split(separator: "-").map(String.init)
    if parts.count == 2 {
        let a = try shape(parts[0], token: token)
        let b = try shape(parts[1], token: token)
        guard a.kind == b.kind else { throw RangeError(token: token) }
        let aPair = a.high == a.low
        let bPair = b.high == b.low
        if aPair && bPair {
            for v in min(a.high, b.high)...max(a.high, b.high) { out.formUnion(names(high: v, low: v, kind: "")) }
        } else if !aPair && !bPair && a.high == b.high {
            for low in min(a.low, b.low)...max(a.low, b.low) { out.formUnion(names(high: a.high, low: low, kind: a.kind)) }
        } else if !aPair && !bPair && a.high - a.low == b.high - b.low {
            let gap = a.high - a.low
            for high in min(a.high, b.high)...max(a.high, b.high) {
                out.formUnion(names(high: high, low: high - gap, kind: a.kind))
            }
        } else {
            throw RangeError(token: token)
        }
        return out
    }

    guard parts.count == 1 else { throw RangeError(token: token) }
    let s = try shape(token, token: token)
    return Set(names(high: s.high, low: s.low, kind: s.kind))
}
