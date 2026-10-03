import Foundation

public struct ChartError: Error, CustomStringConvertible {
    public let description: String
}

/// One spot on the chart: hands that raise, hands that call. Everything else folds.
public struct Spot {
    public let raise: Set<String>
    public let call: Set<String>

    public static let empty = Spot(raise: [], call: [])
}

private struct RawSpot: Decodable {
    let raise: String?
    let call: String?
}

private struct RawChart: Decodable {
    let openSizeBB: [String: Double]?
    let rfi: [String: String]
    let vsOpen: [String: [String: RawSpot]]
    let vs3bet: [String: RawSpot]
    let coldVs3bet: RawSpot
    let vs4bet: RawSpot
    let coldVs4bet: RawSpot
    let vs5bet: RawSpot
    let vsLimp: [String: RawSpot]
    let bbVsSbLimp: RawSpot

    // Explicit keys: a snake-case decoding strategy would also rewrite the position names.
    enum CodingKeys: String, CodingKey {
        case openSizeBB = "open_size_bb"
        case rfi
        case vsOpen = "vs_open"
        case vs3bet = "vs_3bet"
        case coldVs3bet = "cold_vs_3bet"
        case vs4bet = "vs_4bet"
        case coldVs4bet = "cold_vs_4bet"
        case vs5bet = "vs_5bet"
        case vsLimp = "vs_limp"
        case bbVsSbLimp = "bb_vs_sb_limp"
    }
}

public struct Chart {
    public let openSizeBB: [String: Double]
    public let rfi: [String: Set<String>]
    public let vsOpen: [String: [String: Spot]]
    public let vs3bet: [String: Spot]
    public let coldVs3bet: Spot
    public let vs4bet: Spot
    public let coldVs4bet: Spot
    public let vs5bet: Spot
    public let vsLimp: [String: Spot]
    public let bbVsSbLimp: Spot

    public static let builtIn: Chart = {
        do {
            return try Chart(json: Data(defaultChartJSON.utf8))
        } catch {
            fatalError("built-in chart is invalid: \(error)")
        }
    }()

    public init(json: Data) throws {
        let raw: RawChart
        do {
            raw = try JSONDecoder().decode(RawChart.self, from: json)
        } catch let error as DecodingError {
            throw ChartError(description: "ranges file isn't valid: \(Chart.describe(error))")
        }

        func spot(_ r: RawSpot, _ place: String) throws -> Spot {
            do {
                return Spot(raise: try parseRange(r.raise ?? ""), call: try parseRange(r.call ?? ""))
            } catch let error as RangeError {
                throw ChartError(description: "\(place): \(error.description)")
            }
        }
        func spots(_ d: [String: RawSpot], _ place: String) throws -> [String: Spot] {
            var out: [String: Spot] = [:]
            for (key, value) in d { out[key] = try spot(value, "\(place) → \(key)") }
            return out
        }

        openSizeBB = raw.openSizeBB ?? [:]
        var rfi: [String: Set<String>] = [:]
        for (position, text) in raw.rfi {
            do {
                rfi[position] = try parseRange(text)
            } catch let error as RangeError {
                throw ChartError(description: "rfi → \(position): \(error.description)")
            }
        }
        self.rfi = rfi
        var vsOpen: [String: [String: Spot]] = [:]
        for (hero, openers) in raw.vsOpen { vsOpen[hero] = try spots(openers, "vs_open → \(hero)") }
        self.vsOpen = vsOpen
        vs3bet = try spots(raw.vs3bet, "vs_3bet")
        coldVs3bet = try spot(raw.coldVs3bet, "cold_vs_3bet")
        vs4bet = try spot(raw.vs4bet, "vs_4bet")
        coldVs4bet = try spot(raw.coldVs4bet, "cold_vs_4bet")
        vs5bet = try spot(raw.vs5bet, "vs_5bet")
        vsLimp = try spots(raw.vsLimp, "vs_limp")
        bbVsSbLimp = try spot(raw.bbVsSbLimp, "bb_vs_sb_limp")
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "missing section \"\(key.stringValue)\""
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "wrong kind of value at \(context.codingPath.map(\.stringValue).joined(separator: " → "))"
        case .dataCorrupted(let context):
            return "not valid JSON (\(context.debugDescription))"
        @unknown default: return "\(error)"
        }
    }
}
