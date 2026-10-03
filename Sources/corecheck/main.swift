import Foundation
import PreflopCore

// Self-checks for the core. Run with: swift run corecheck

var failures = 0

func expect<T: Equatable>(_ got: T, _ want: T, _ label: String) {
    if got == want { return }
    failures += 1
    print("FAIL \(label): got \(got), want \(want)")
}

func hole(_ text: String) -> HoleCards {
    let parts = text.split(separator: " ").map(String.init)
    return HoleCards(Card(parts[0])!, Card(parts[1])!)!
}

let chart = Chart.builtIn

// --- Cards -----------------------------------------------------------------
expect(hole("Kd As").key, "AKo", "hand key orders high card first")
expect(hole("Th 9h").key, "T9s", "suited key")
expect(hole("7c 7d").key, "77", "pair key")
expect(Card("10h")?.rank, "T", "ten written as 10")
expect(Card("K♠")?.suit, "s", "suit symbol")
expect(Card("1x") == nil, true, "bad card rejected")
expect(HoleCards(Card("As")!, Card("As")!) == nil, true, "duplicate card rejected")

// --- Range notation --------------------------------------------------------
expect(try! parseRange("22+").count, 13, "22+")
expect(try! parseRange("JJ-77"), ["JJ", "TT", "99", "88", "77"], "pair span")
expect(try! parseRange("ATs+"), ["ATs", "AJs", "AQs", "AKs"], "suited plus")
expect(try! parseRange("A5s-A2s"), ["A5s", "A4s", "A3s", "A2s"], "kicker span")
expect(try! parseRange("T9s-87s"), ["T9s", "98s", "87s"], "connector ladder")
expect(try! parseRange("AK"), ["AKs", "AKo"], "no suffix means both")
expect(try! parseRange("T8s+"), ["T8s", "T9s"], "gapper plus")
expect(try! parseRange(""), [], "empty range")
expect((try? parseRange("AXs")) == nil, true, "bad rank rejected")
expect((try? parseRange("77s")) == nil, true, "suited pair rejected")
expect(comboCount(try! parseRange("22+, AKs, AKo")), 78 + 4 + 12, "combo count")

// --- Positions -------------------------------------------------------------
expect(position(seat: 3, players: 6).name, "UTG", "6-max first seat shows as UTG")
expect(position(seat: 3, players: 6).key, "LJ", "6-max first seat uses the LJ range")
expect(position(seat: 5, players: 6).key, "CO", "6-max cutoff")
expect(position(seat: 3, players: 9).key, "EP", "9-max UTG is early position")
expect(position(seat: 5, players: 9).name, "UTG+2", "9-max UTG+2")
expect(position(seat: 6, players: 9).key, "LJ", "9-max lojack")
expect(position(seat: 0, players: 2).key, "SB", "heads-up button is the small blind")
expect(position(seat: 3, players: 4).key, "CO", "4-handed first seat is the cutoff")

// --- Engine ----------------------------------------------------------------
func play(_ cards: String, players: Int = 6, seat: Int, raises: Int = 0, raiser: Int? = nil, heroRaised: Bool = false,
          limpers: Int = 0, sbLimp: Bool = false, callers: Int = 0, facing: Double? = nil) -> String {
    advise(Situation(hero: hole(cards), players: players, heroSeat: seat, raises: raises, lastRaiserSeat: raiser,
                     heroHasRaised: heroRaised, limpers: limpers, onlySmallBlindLimped: sbLimp, callers: callers,
                     facingBB: facing), chart: chart).headline
}

expect(play("As Kd", seat: 3), "RAISE to 2.5bb", "AKo opens UTG")
expect(play("7h 2c", seat: 0), "FOLD", "72o folds the button")
expect(play("9s 8s", seat: 3), "RAISE to 2.5bb", "98s opens UTG 6-max")
expect(play("9s 8s", players: 9, seat: 3), "RAISE to 2.5bb", "98s opens UTG 9-max")
expect(play("Kc 9c", players: 9, seat: 3), "FOLD", "K9s folds UTG 9-max")
expect(play("Kc 5c", seat: 5), "RAISE to 2.5bb", "K5s opens the cutoff")
expect(play("Kc 4c", seat: 5), "FOLD", "K4s folds the cutoff")
expect(play("Qd 5d", seat: 1), "RAISE to 3bb", "small blind opens to 3bb")
expect(play("9d 4c", seat: 2), "CHECK", "big blind checks when nobody raised")
expect(play("Jd 3c", players: 2, seat: 0), "FOLD", "heads-up J3o folds")
expect(play("Jd 7c", players: 2, seat: 0), "RAISE to 2.5bb", "heads-up opens wide at 2.5bb")

expect(play("Ad Ac", seat: 0, raises: 1, raiser: 5, facing: 2.5), "3-BET to 7.5bb", "button 3-bets in position to 3x")
expect(play("Ad Ac", seat: 1, raises: 1, raiser: 5, facing: 2.5), "3-BET to 10bb", "small blind 3-bets to 4x")
expect(play("Ad Ac", seat: 0, raises: 1, raiser: 5, callers: 1, facing: 2.5), "3-BET to 10bb", "squeeze adds a caller")
expect(play("8d 8c", seat: 0, raises: 1, raiser: 5, facing: 2.5), "CALL", "button flats 88 vs cutoff")
expect(play("8d 8c", seat: 1, raises: 1, raiser: 3, facing: 2.5), "FOLD", "small blind folds 88 vs UTG")
expect(play("7d 6d", seat: 2, raises: 1, raiser: 3, facing: 2.5), "3-BET to 10bb", "big blind 3-bets 76s vs UTG")
expect(play("Jd 9c", seat: 2, raises: 1, raiser: 0, facing: 2.5), "CALL", "big blind defends J9o vs button")
expect(play("Jd 9c", seat: 2, raises: 1, raiser: 3, facing: 2.5), "FOLD", "big blind folds J9o vs UTG")
expect(play("Ad Ac", seat: 0, raises: 1, raiser: nil), "3-BET to 3x", "unknown opener and size still gives a multiple")
expect(play("Ad Qd", seat: 0, raises: 1, raiser: nil), "CALL", "unknown opener falls back to the tightest row")

expect(play("Qd Qc", seat: 5, raises: 2, raiser: 0, heroRaised: true, facing: 7.5), "4-BET to 19bb", "QQ 4-bets out of position")
expect(play("Td Tc", seat: 5, raises: 2, raiser: 0, heroRaised: true, facing: 7.5), "CALL", "TT calls a 3-bet")
expect(play("Ad Jc", seat: 5, raises: 2, raiser: 0, heroRaised: true, facing: 7.5), "FOLD", "AJo folds to a 3-bet")
expect(play("Qd Qc", seat: 0, raises: 2, raiser: 5, facing: 9), "CALL", "QQ flats an open and 3-bet cold")
expect(play("Jd Jc", seat: 0, raises: 2, raiser: 5, facing: 9), "FOLD", "JJ folds to an open and 3-bet cold")
expect(play("Kd Kc", seat: 0, raises: 3, raiser: 5, heroRaised: true), "ALL-IN", "KK shoves over a 4-bet")
expect(play("Qd Qc", seat: 0, raises: 3, raiser: 5, heroRaised: true), "CALL", "QQ calls a 4-bet")
expect(play("Ad Kc", seat: 0, raises: 4, raiser: 5, heroRaised: true), "CALL (all-in)", "AKo calls a 5-bet shove")
expect(play("Ad Kc", seat: 0, raises: 4, raiser: 5), "FOLD", "AKo folds cold to a 5-bet")
expect(play("Ad Kc", seat: 5, raises: 1, raiser: 5, heroRaised: true), "WAIT", "hero made the last raise")

expect(play("Ad Qc", seat: 0, limpers: 2), "RAISE to 5bb", "button isolates two limpers")
expect(play("6d 5d", seat: 0, limpers: 1), "CALL (limp behind)", "button limps behind with 65s")
expect(play("4d 4c", seat: 1, limpers: 1), "CALL (complete)", "small blind completes 44")
expect(play("Ad Jc", seat: 2, limpers: 1, sbLimp: true), "RAISE to 5bb", "big blind raises a small blind limp")
expect(play("8d 3c", seat: 2, limpers: 2), "CHECK", "big blind checks junk behind limpers")

// --- Reading a table -------------------------------------------------------
typealias P = TableRead.Player

func headline(_ read: TableRead) -> String {
    if case .ready(let situation) = interpret(read) { return advise(situation, chart: chart).headline }
    return "not ready"
}

// 6-max 50/100. Hero in the cutoff, folded to them.
var seats = [P(), P(bet: 50), P(bet: 100), P(folded: true), P(folded: true), P(isHero: true, stack: 10000)]
expect(headline(TableRead(heroCards: ["Ah", "Jh"], bigBlind: 100, players: seats)), "RAISE to 2.5bb (250)", "sizes shown in chips")

// UTG opens to 250, hero on the button with pocket fives.
seats = [P(isHero: true, stack: 9000), P(bet: 50), P(bet: 100), P(bet: 250), P(folded: true), P(folded: true)]
expect(headline(TableRead(heroCards: ["5h", "5d"], bigBlind: 100, players: seats, numRaises: 1, lastRaiserIndex: 3)), "CALL", "flat 55 on the button")

// The model missed the raise: a 250 bet with a 100 big blind still counts as one.
expect(headline(TableRead(heroCards: ["7h", "2d"], bigBlind: 100, players: seats)), "FOLD", "raise inferred from bet size")

// Limp detection: UTG limps, hero in the big blind with kings.
seats = [P(folded: true), P(folded: true), P(isHero: true, bet: 100), P(bet: 100), P(folded: true), P(folded: true)]
expect(headline(TableRead(heroCards: ["Kh", "Kd"], bigBlind: 100, players: seats)), "RAISE to 5bb (500)", "big blind isolates a limper")

// Big blind unreadable: fall back to the big blind seat's bet.
seats = [P(), P(bet: 1), P(bet: 2), P(isHero: true)]
if case .ready(let s) = interpret(TableRead(heroCards: ["Ah", "Ad"], players: seats)) {
    expect(s.bigBlindChips, 2, "big blind taken from the big blind seat")
    expect(position(seat: s.heroSeat, players: s.players).name, "CO", "4-handed hero is the cutoff")
} else {
    expect("not ready", "ready", "4-handed read")
}

if case .postflop = interpret(TableRead(street: "flop", heroCards: ["Ah", "Ad"], players: seats)) {} else {
    expect("other", "postflop", "flop is not a chart spot")
}
if case .noCards = interpret(TableRead(heroCards: [], players: seats)) {} else {
    expect("other", "noCards", "no cards")
}
if case .unclear = interpret(TableRead(heroCards: ["Ah", "Ad"], players: [P(), P(bet: 1), P(bet: 2)])) {} else {
    expect("other", "unclear", "no hero seat")
}

// The schema's field names must decode into TableRead.
let sample = #"{"poker_table_visible":true,"street":"preflop","hero_cards":["As","Kd"],"hero_to_act":true,"big_blind":2,"players":[{"is_hero":true,"folded":false,"bet":0,"stack":200},{"is_hero":false,"folded":false,"bet":1,"stack":199},{"is_hero":false,"folded":false,"bet":2,"stack":198}],"num_raises":0,"last_raiser_index":-1,"hero_has_raised":false,"confidence":"high"}"#
if let decoded = try? JSONDecoder().decode(TableRead.self, from: Data(sample.utf8)) {
    expect(headline(decoded), "RAISE to 2.5bb (5)", "decoded read")
} else {
    expect("decode failed", "decoded", "sample JSON")
}
expect((TableRead.schema as? [String: Any])?["required"] != nil, true, "schema parses")

// --- Chart sanity ----------------------------------------------------------
print("Opening ranges:")
for key in ["EP", "LJ", "HJ", "CO", "BTN", "SB", "HU"] {
    let combos = comboCount(chart.rfi[key] ?? [])
    print("  \(key.padding(toLength: 4, withPad: " ", startingAt: 0)) \(String(format: "%5.1f", Double(combos) / 13.26))%")
}
let widths = ["EP", "LJ", "HJ", "CO", "BTN"].map { comboCount(chart.rfi[$0] ?? []) }
expect(widths, widths.sorted(), "opening ranges widen toward the button")

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
