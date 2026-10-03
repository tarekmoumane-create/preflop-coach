import Foundation

/// What the vision model reports about a screenshot. Field names match the JSON schema
/// sent with the request (see `TableRead.schema`).
public struct TableRead: Decodable {
    public struct Player: Decodable {
        public var isHero: Bool
        public var folded: Bool
        public var bet: Double
        public var stack: Double

        enum CodingKeys: String, CodingKey {
            case isHero = "is_hero"
            case folded, bet, stack
        }

        public init(isHero: Bool = false, folded: Bool = false, bet: Double = 0, stack: Double = 0) {
            self.isHero = isHero
            self.folded = folded
            self.bet = bet
            self.stack = stack
        }
    }

    public var pokerTableVisible: Bool
    public var street: String
    public var heroCards: [String]
    public var heroToAct: Bool
    public var bigBlind: Double
    /// Everyone dealt into the hand, clockwise starting with the button.
    public var players: [Player]
    public var numRaises: Int
    public var lastRaiserIndex: Int
    public var heroHasRaised: Bool
    public var confidence: String

    enum CodingKeys: String, CodingKey {
        case pokerTableVisible = "poker_table_visible"
        case street
        case heroCards = "hero_cards"
        case heroToAct = "hero_to_act"
        case bigBlind = "big_blind"
        case players
        case numRaises = "num_raises"
        case lastRaiserIndex = "last_raiser_index"
        case heroHasRaised = "hero_has_raised"
        case confidence
    }

    public init(pokerTableVisible: Bool = true, street: String = "preflop", heroCards: [String], heroToAct: Bool = true,
                bigBlind: Double = 0, players: [Player], numRaises: Int = 0, lastRaiserIndex: Int = -1,
                heroHasRaised: Bool = false, confidence: String = "high") {
        self.pokerTableVisible = pokerTableVisible
        self.street = street
        self.heroCards = heroCards
        self.heroToAct = heroToAct
        self.bigBlind = bigBlind
        self.players = players
        self.numRaises = numRaises
        self.lastRaiserIndex = lastRaiserIndex
        self.heroHasRaised = heroHasRaised
        self.confidence = confidence
    }
}

public enum Reading {
    case noTable
    case noHand
    case postflop(String)
    /// Hero has folded, or the cards couldn't be read.
    case noCards
    case unclear(String)
    case ready(Situation)
}

/// Turns the raw read into a chart lookup, working out limpers, callers and bet sizes
/// from the chips in front of each player rather than trusting the model to count them.
public func interpret(_ read: TableRead) -> Reading {
    guard read.pokerTableVisible else { return .noTable }
    guard read.street == "preflop" else {
        return read.street == "none" ? .noHand : .postflop(read.street)
    }
    guard read.heroCards.count == 2,
          let first = Card(read.heroCards[0]), let second = Card(read.heroCards[1]),
          let hole = HoleCards(first, second)
    else { return .noCards }

    let players = read.players
    let n = players.count
    guard (2...10).contains(n) else { return .unclear("couldn't read the seats") }
    let heroSeats = players.indices.filter { players[$0].isHero }
    guard heroSeats.count == 1, let hero = heroSeats.first else { return .unclear("couldn't tell which seat is yours") }
    if players[hero].folded { return .noCards }

    let bigBlindSeat = n == 2 ? 1 : 2
    let smallBlindSeat = n == 2 ? 0 : 1
    let bigBlind = read.bigBlind > 0 ? read.bigBlind : players[bigBlindSeat].bet
    let knowsBlind = bigBlind > 0
    let topBet = players.map(\.bet).max() ?? 0
    func hasMatched(_ seat: Int, _ amount: Double) -> Bool {
        !players[seat].folded && players[seat].bet >= amount * 0.99
    }

    var raises = max(0, read.numRaises)
    var lastRaiser: Int? = players.indices.contains(read.lastRaiserIndex) ? read.lastRaiserIndex : nil
    let biggest = players.indices.first { players[$0].bet == topBet }
    // A bet of two big blinds or more is a raise even if the model reported none.
    if raises == 0, knowsBlind, topBet >= bigBlind * 2 { raises = 1 }
    if raises > 0, lastRaiser == nil { lastRaiser = biggest }
    if raises == 0 { lastRaiser = nil }

    var limpers = 0
    var onlySmallBlindLimped = false
    var callers = 0
    if raises == 0, knowsBlind {
        let limped = players.indices.filter { $0 != hero && $0 != bigBlindSeat && hasMatched($0, bigBlind) }
        limpers = limped.count
        onlySmallBlindLimped = limped == [smallBlindSeat]
    } else if raises > 0, topBet > 0 {
        callers = players.indices.filter { $0 != hero && $0 != lastRaiser && hasMatched($0, topBet) }.count
    }

    return .ready(Situation(
        hero: hole,
        players: n,
        heroSeat: hero,
        raises: raises,
        lastRaiserSeat: lastRaiser,
        heroHasRaised: read.heroHasRaised,
        limpers: limpers,
        onlySmallBlindLimped: onlySmallBlindLimped,
        callers: callers,
        facingBB: raises > 0 && knowsBlind && topBet > 0 ? topBet / bigBlind : nil,
        bigBlindChips: knowsBlind ? bigBlind : nil,
        heroStackBB: knowsBlind && players[hero].stack > 0 ? (players[hero].stack + players[hero].bet) / bigBlind : nil
    ))
}

extension TableRead {
    /// Instructions for the vision model. It only transcribes the table; the chart decides.
    public static let instructions = """
    You transcribe screenshots of online No-Limit Hold'em poker tables into structured data. \
    You report only what is visible on screen. You never give strategy advice.

    "Hero" is the player whose two hole cards are shown face up, usually at the bottom centre of the table.

    Fields:
    - poker_table_visible: true only if a poker table with seats is on screen.
    - street: "preflop" when a hand is in progress and no community cards are dealt; "flop", "turn" or "river" \
    for 3, 4 or 5 community cards; "none" if no hand is in progress.
    - hero_cards: hero's two hole cards, each as rank then suit. Ranks: 2 3 4 5 6 7 8 9 T J Q K A. \
    Suits: s h d c. Example: ["As", "Td"]. Some tables use four-colour decks (clubs green, diamonds blue): \
    read the suit from the symbol's shape. Return an empty list if hero has no cards, has folded, or you \
    cannot read both cards with certainty. Never guess a card.
    - hero_to_act: true if it is hero's turn, shown by action buttons such as Fold / Call / Raise / Check or by \
    hero's timer running.
    - big_blind: the big blind amount in the same units the table uses for bets. If the table shows amounts in \
    big blinds, use 1. Use 0 if you cannot tell.
    - players: every player dealt into the current hand, including players who have already folded this hand, \
    and excluding empty seats and players sitting out. List them in clockwise order starting with the player \
    who has the dealer button, so the next entry is the small blind and the one after is the big blind \
    (heads-up, the button is the small blind). For each: is_hero; folded (has folded this hand); bet (chips in \
    front of them this betting round including a posted blind, 0 if none); stack (chips behind, 0 if unreadable).
    - num_raises: how many raises have been made preflop, not counting the blinds. 0 means nobody has raised \
    (blinds and limps only), 1 an open raise, 2 a raise and a re-raise (3-bet), 3 a 4-bet, and so on.
    - last_raiser_index: index in players (0 = the button) of whoever made the most recent raise, -1 if none.
    - hero_has_raised: true if hero made any of the raises in this preflop round.
    - confidence: "high", "medium" or "low" for the read as a whole. Use "low" if cards or the button were hard to see.

    Ignore everything outside the poker table, including the menu bar and other windows.
    """

    /// JSON schema for the structured response.
    public static let schemaJSON = #"""
    {
      "type": "object",
      "properties": {
        "poker_table_visible": { "type": "boolean" },
        "street": { "type": "string", "enum": ["preflop", "flop", "turn", "river", "none"] },
        "hero_cards": { "type": "array", "items": { "type": "string" } },
        "hero_to_act": { "type": "boolean" },
        "big_blind": { "type": "number" },
        "players": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "is_hero": { "type": "boolean" },
              "folded": { "type": "boolean" },
              "bet": { "type": "number" },
              "stack": { "type": "number" }
            },
            "required": ["is_hero", "folded", "bet", "stack"],
            "additionalProperties": false
          }
        },
        "num_raises": { "type": "integer" },
        "last_raiser_index": { "type": "integer" },
        "hero_has_raised": { "type": "boolean" },
        "confidence": { "type": "string", "enum": ["high", "medium", "low"] }
      },
      "required": [
        "poker_table_visible", "street", "hero_cards", "hero_to_act", "big_blind", "players",
        "num_raises", "last_raiser_index", "hero_has_raised", "confidence"
      ],
      "additionalProperties": false
    }
    """#

    public static var schema: Any {
        (try? JSONSerialization.jsonObject(with: Data(schemaJSON.utf8))) ?? [String: Any]()
    }
}
