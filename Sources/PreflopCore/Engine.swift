import Foundation

public struct Position: Equatable {
    /// The chart key: EP, LJ, HJ, CO, BTN, SB or BB.
    public let key: String
    /// What to show: at a 6-max table the LJ seat is called UTG.
    public let name: String
}

/// `seat` counts clockwise from the button (0 = button) among the `players` dealt in.
public func position(seat: Int, players n: Int) -> Position {
    if n == 2 {
        return seat == 0 ? Position(key: "SB", name: "BTN/SB") : Position(key: "BB", name: "BB")
    }
    switch seat {
    case 0: return Position(key: "BTN", name: "BTN")
    case 1: return Position(key: "SB", name: "SB")
    case 2: return Position(key: "BB", name: "BB")
    default:
        let firstToAct = seat == 3
        switch n - seat {
        case 1: return Position(key: "CO", name: "CO")
        case 2: return Position(key: "HJ", name: "HJ")
        case 3: return Position(key: "LJ", name: firstToAct ? "UTG" : "LJ")
        default: return Position(key: "EP", name: firstToAct ? "UTG" : "UTG+\(seat - 3)")
        }
    }
}

/// Everything the chart needs to know about the hand so far.
public struct Situation {
    public var hero: HoleCards
    public var players: Int
    public var heroSeat: Int
    /// Raises so far, not counting the blinds: 1 = an open, 2 = a 3-bet, 3 = a 4-bet.
    public var raises: Int
    public var lastRaiserSeat: Int?
    public var heroHasRaised: Bool
    public var limpers: Int
    public var onlySmallBlindLimped: Bool
    /// Players other than hero who have called the current bet.
    public var callers: Int
    /// The bet hero is facing, in big blinds, when it could be read.
    public var facingBB: Double?
    /// Chips per big blind, for showing sizes in table units.
    public var bigBlindChips: Double?
    public var heroStackBB: Double?

    public init(hero: HoleCards, players: Int, heroSeat: Int, raises: Int = 0, lastRaiserSeat: Int? = nil,
                heroHasRaised: Bool = false, limpers: Int = 0, onlySmallBlindLimped: Bool = false,
                callers: Int = 0, facingBB: Double? = nil, bigBlindChips: Double? = nil, heroStackBB: Double? = nil) {
        self.hero = hero
        self.players = players
        self.heroSeat = heroSeat
        self.raises = raises
        self.lastRaiserSeat = lastRaiserSeat
        self.heroHasRaised = heroHasRaised
        self.limpers = limpers
        self.onlySmallBlindLimped = onlySmallBlindLimped
        self.callers = callers
        self.facingBB = facingBB
        self.bigBlindChips = bigBlindChips
        self.heroStackBB = heroStackBB
    }
}

public struct Advice: Equatable {
    public enum Kind: String {
        case fold, check, call, raise, allIn, wait
    }

    public let kind: Kind
    /// "RAISE to 2.5bb", "FOLD", "3-BET to 7.5bb".
    public let headline: String
    /// Which part of the chart produced it: "CO · folded to you".
    public let spot: String
    public var note: String?
}

public func advise(_ s: Situation, chart: Chart) -> Advice {
    let n = s.players
    let pos = position(seat: s.heroSeat, players: n)
    let hand = s.hero.key
    let headsUp = n == 2

    // Later to act after the flop means in position. The button is last, the small blind first.
    func postflopOrder(_ seat: Int) -> Int { seat == 0 ? n : seat }
    func inPosition(against seat: Int?) -> Bool {
        guard let seat else { return pos.key == "BTN" || headsUp && s.heroSeat == 0 }
        return postflopOrder(s.heroSeat) > postflopOrder(seat)
    }

    func size(_ bb: Double) -> String {
        let rounded = (bb * 2).rounded() / 2
        var text = rounded == rounded.rounded() ? "\(Int(rounded))bb" : "\(rounded)bb"
        if let chips = s.bigBlindChips, chips > 0, chips != 1 {
            let amount = rounded * chips
            let shown = amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2f", amount)
            text += " (\(shown))"
        }
        return text
    }

    func finish(_ kind: Advice.Kind, _ headline: String, _ spot: String) -> Advice {
        var note: String?
        if let stack = s.heroStackBB, stack > 0, stack < 30 {
            note = "Short stack (~\(Int(stack))bb): the chart assumes about 100bb."
        }
        return Advice(kind: kind, headline: headline, spot: "\(hand) · \(spot)", note: note)
    }

    func decide(_ spot: Spot, raise: String, call: String = "CALL", otherwise: Advice.Kind = .fold,
                raiseKind: Advice.Kind = .raise, _ place: String) -> Advice {
        if spot.raise.contains(hand) { return finish(raiseKind, raise, place) }
        if spot.call.contains(hand) { return finish(.call, call, place) }
        return finish(otherwise, otherwise == .check ? "CHECK" : "FOLD", place)
    }

    if let last = s.lastRaiserSeat, last == s.heroSeat, s.raises > 0 {
        return finish(.wait, "WAIT", "\(pos.name) · you made the last raise")
    }

    switch s.raises {
    case 0:
        if s.limpers == 0 {
            if pos.key == "BB" {
                return finish(.check, "CHECK", "BB · nobody raised")
            }
            let range = chart.rfi[headsUp ? "HU" : pos.key] ?? chart.rfi[pos.key] ?? []
            let standard = chart.openSizeBB["default"] ?? 2.5
            let open = headsUp ? standard : chart.openSizeBB[pos.key] ?? standard
            let kind: Advice.Kind = range.contains(hand) ? .raise : .fold
            return finish(kind, kind == .raise ? "RAISE to \(size(open))" : "FOLD", "\(pos.name) · folded to you")
        }
        let who = s.limpers == 1 ? "1 limper" : "\(s.limpers) limpers"
        let outOfPosition = pos.key == "SB" || pos.key == "BB"
        let iso = "RAISE to \(size(3 + Double(s.limpers) + (outOfPosition ? 1 : 0)))"
        if pos.key == "BB" {
            let spot = s.onlySmallBlindLimped ? chart.bbVsSbLimp : chart.vsLimp["BB"] ?? .empty
            return decide(spot, raise: iso, otherwise: .check, "BB · \(s.onlySmallBlindLimped ? "small blind limped" : who)")
        }
        return decide(chart.vsLimp[pos.key] ?? .empty, raise: iso,
                      call: pos.key == "SB" ? "CALL (complete)" : "CALL (limp behind)", "\(pos.name) · \(who)")

    case 1:
        let opener = s.lastRaiserSeat.map { position(seat: $0, players: n) }
        let spot = openSpot(chart, hero: pos.key, opener: opener?.key)
        let multiple = inPosition(against: s.lastRaiserSeat) ? 3.0 : 4.0
        var raise = "3-BET to \(multiple == 3 ? "3x" : "4x")"
        if let facing = s.facingBB {
            raise = "3-BET to \(size(facing * (multiple + Double(s.callers))))"
        }
        var place = "\(pos.name) vs \(opener?.name ?? "an") open"
        if s.callers > 0 { place += " + \(s.callers) caller\(s.callers == 1 ? "" : "s")" }
        return decide(spot, raise: raise, place)

    case 2:
        let multiple = inPosition(against: s.lastRaiserSeat) ? 2.2 : 2.5
        var raise = "4-BET to \(multiple)x"
        if let facing = s.facingBB { raise = "4-BET to \(size(facing * multiple))" }
        if s.heroHasRaised {
            let key = headsUp && pos.key == "SB" ? "BTN" : pos.key
            return decide(chart.vs3bet[key] ?? chart.coldVs3bet, raise: raise, "\(pos.name) open, facing a 3-bet")
        }
        return decide(chart.coldVs3bet, raise: raise, "\(pos.name) · open and 3-bet before you")

    case 3:
        if s.heroHasRaised {
            return decide(chart.vs4bet, raise: "ALL-IN", raiseKind: .allIn, "\(pos.name) · facing a 4-bet")
        }
        return decide(chart.coldVs4bet, raise: "ALL-IN", raiseKind: .allIn, "\(pos.name) · 4-bet before you")

    default:
        let spot = s.heroHasRaised ? chart.vs5bet : chart.coldVs4bet
        return decide(Spot(raise: [], call: spot.raise.union(spot.call)), raise: "", call: "CALL (all-in)",
                      "\(pos.name) · facing a 5-bet or shove")
    }
}

/// The spot for hero facing a single raise. Falls back to the nearest opener the chart
/// does cover, preferring an earlier (tighter) one.
private func openSpot(_ chart: Chart, hero: String, opener: String?) -> Spot {
    let fallback = Spot(raise: (try? parseRange("QQ+, AKs, AKo")) ?? [], call: [])
    guard let table = chart.vsOpen[hero], !table.isEmpty else { return fallback }
    let order = ["EP", "LJ", "HJ", "CO", "BTN", "SB"]
    guard let opener, let index = order.firstIndex(of: opener) else {
        return order.lazy.compactMap { table[$0] }.first ?? fallback
    }
    if let exact = table[opener] { return exact }
    let earlier = order[..<index].reversed().lazy.compactMap { table[$0] }.first
    let later = order[(index + 1)...].lazy.compactMap { table[$0] }.first
    return earlier ?? later ?? fallback
}
