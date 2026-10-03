import Foundation

private let ranks: [Character] = Array("23456789TJQKA")

/// 0 for a deuce up to 12 for an ace.
public func rankValue(_ rank: Character) -> Int? {
    ranks.firstIndex(of: rank)
}

func rankChar(_ value: Int) -> Character {
    ranks[value]
}

public struct Card: Equatable {
    public let rank: Character
    public let suit: Character

    /// Accepts "As", "td", "10h", "K♠".
    public init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard let last = s.last else { return nil }
        let suit: Character
        switch last {
        case "s", "S", "♠", "♤": suit = "s"
        case "h", "H", "♥", "♡": suit = "h"
        case "d", "D", "♦", "♢": suit = "d"
        case "c", "C", "♣", "♧": suit = "c"
        default: return nil
        }
        s.removeLast()
        s = s.uppercased()
        if s == "10" { s = "T" }
        guard s.count == 1, let rank = s.first, rankValue(rank) != nil else { return nil }
        self.rank = rank
        self.suit = suit
    }

    public var pretty: String {
        let symbol: String
        switch suit {
        case "s": symbol = "♠"
        case "h": symbol = "♥"
        case "d": symbol = "♦"
        default: symbol = "♣"
        }
        return "\(rank)\(symbol)"
    }
}

public struct HoleCards: Equatable {
    public let high: Card
    public let low: Card

    public init?(_ a: Card, _ b: Card) {
        guard a != b, let va = rankValue(a.rank), let vb = rankValue(b.rank) else { return nil }
        if va >= vb {
            high = a
            low = b
        } else {
            high = b
            low = a
        }
    }

    /// The chart cell this hand belongs to: "AKs", "TT", "72o".
    public var key: String {
        if high.rank == low.rank { return "\(high.rank)\(low.rank)" }
        return "\(high.rank)\(low.rank)\(high.suit == low.suit ? "s" : "o")"
    }

    public var pretty: String {
        "\(high.pretty) \(low.pretty)"
    }
}
