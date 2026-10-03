/// The built-in chart, written out as ranges.json on first launch so it can be edited.
public let defaultChartJSON = #"""
{
  "_readme": [
    "Preflop Coach ranges. No-limit hold'em, roughly 100bb deep. Edit, save, then choose Reload Ranges in the menu.",
    "Positions: EP = the early seats at a 7-9 handed table, LJ = UTG at a 6-max table, then HJ, CO, BTN, SB, BB.",
    "Notation: 22+ (all pairs), JJ-77, ATs+ (ATs to AKs), A5s-A2s, T9s-65s (suited connectors), AK (suited and offsuit).",
    "In every spot 'raise' is checked first, then 'call'. Any hand in neither list is a fold (or a check in the big blind).",
    "vs_open is keyed by YOUR position, then by the position of the player who opened."
  ],

  "open_size_bb": { "default": 2.5, "SB": 3 },

  "rfi": {
    "EP":  "66+, ATs+, A5s-A4s, KTs+, QTs+, JTs, T9s, 98s, AJo+, KQo",
    "LJ":  "55+, A2s+, K9s+, Q9s+, J9s+, T9s, 98s, 87s, 76s, ATo+, KJo+",
    "HJ":  "33+, A2s+, K8s+, Q9s+, J9s+, T8s+, 97s+, 87s, 76s, 65s, ATo+, KJo+, QJo",
    "CO":  "22+, A2s+, K5s+, Q8s+, J8s+, T8s+, 97s+, 86s+, 75s+, 65s, 54s, A9o+, KTo+, QTo+, JTo",
    "BTN": "22+, A2s+, K2s+, Q4s+, J6s+, T6s+, 96s+, 85s+, 75s+, 64s+, 53s+, 43s, A2o+, K8o+, Q9o+, J9o+, T8o+, 98o",
    "SB":  "22+, A2s+, K2s+, Q5s+, J7s+, T7s+, 96s+, 86s+, 75s+, 64s+, 54s, A2o+, K9o+, Q9o+, J9o+, T9o",
    "HU":  "22+, A2s+, K2s+, Q2s+, J2s+, T4s+, 95s+, 85s+, 74s+, 64s+, 53s+, 43s, A2o+, K2o+, Q5o+, J7o+, T7o+, 97o+, 87o, 76o"
  },

  "vs_open": {
    "EP": {
      "EP":  { "raise": "QQ+, AKs, AKo", "call": "JJ-TT, AQs, KQs" }
    },
    "LJ": {
      "EP":  { "raise": "QQ+, AKs, AKo, A5s", "call": "JJ-99, AQs-AJs, KQs" }
    },
    "HJ": {
      "EP":  { "raise": "QQ+, AKs, AKo, A5s", "call": "JJ-99, AQs-AJs, KQs, QJs, JTs" },
      "LJ":  { "raise": "QQ+, AKs, AKo, A5s-A4s, KQs", "call": "JJ-88, AQs-AJs, KJs, QJs, JTs, AQo" }
    },
    "CO": {
      "EP":  { "raise": "QQ+, AKs, AKo, A5s-A4s", "call": "JJ-88, AQs-AJs, KQs, KJs, QJs, JTs, T9s" },
      "LJ":  { "raise": "QQ+, AKs, AKo, A5s-A4s, KQs", "call": "JJ-77, AQs-ATs, KJs, QJs, JTs, T9s, AQo" },
      "HJ":  { "raise": "JJ+, AQs+, AKo, A5s-A4s, KQs, KJs", "call": "TT-66, AJs-ATs, KTs, QJs, JTs, T9s, 98s, AQo, KQo" }
    },
    "BTN": {
      "EP":  { "raise": "QQ+, AKs, AKo, A5s-A4s", "call": "JJ-66, AQs-ATs, KQs-KTs, QJs, JTs, T9s, 98s, AQo" },
      "LJ":  { "raise": "QQ+, AKs, AKo, A5s-A4s, KQs", "call": "JJ-55, AQs-ATs, KJs-KTs, QJs-QTs, JTs, T9s, 98s, 87s, AQo" },
      "HJ":  { "raise": "JJ+, AQs+, AKo, A5s-A3s, KQs, 76s", "call": "TT-44, AJs-A9s, KJs-KTs, QJs-QTs, JTs-J9s, T9s, 98s, 87s, 65s, AQo, AJo, KQo" },
      "CO":  { "raise": "TT+, AQs+, AKo, AQo, A5s-A2s, KJs, K9s, Q9s, 76s, 65s", "call": "99-33, AJs-A6s, KQs, KTs, QJs-QTs, JTs-J9s, T9s-T8s, 98s, 87s, AJo, KQo, KJo" }
    },
    "SB": {
      "EP":  { "raise": "QQ+, AKs, AKo, AQs, A5s", "call": "" },
      "LJ":  { "raise": "JJ+, AQs+, AKo, A5s-A4s, KQs", "call": "" },
      "HJ":  { "raise": "TT+, AJs+, AQo+, A5s-A4s, KQs, KJs, QJs, JTs", "call": "" },
      "CO":  { "raise": "99+, ATs+, AQo+, A5s-A4s, KTs+, QTs+, JTs, T9s", "call": "" },
      "BTN": { "raise": "77+, A8s+, A5s-A2s, K9s+, Q9s+, J9s+, T9s, 98s, 87s, AJo+, KQo", "call": "" }
    },
    "BB": {
      "EP":  { "raise": "QQ+, AKs, AKo, A5s, 65s", "call": "JJ-22, A2s+, K9s+, Q9s+, J9s+, T8s+, 97s+, 86s+, 75s+, 64s+, 54s, AJo+, KQo" },
      "LJ":  { "raise": "QQ+, AKs, AKo, A5s-A4s, 76s, 65s", "call": "JJ-22, A2s+, K8s+, Q9s+, J9s+, T8s+, 97s+, 86s+, 75s+, 64s+, 54s, ATo+, KJo+, QJo" },
      "HJ":  { "raise": "JJ+, AQs+, AKo, A5s-A4s, K9s, 76s, 65s", "call": "TT-22, A2s+, K6s+, Q8s+, J8s+, T8s+, 97s+, 86s+, 75s+, 64s+, 53s+, 43s, ATo+, KTo+, QTo+, JTo" },
      "CO":  { "raise": "TT+, AJs+, AQo+, A5s-A3s, KQs, K9s, 87s, 76s, 65s", "call": "99-22, A2s+, K2s+, Q6s+, J7s+, T7s+, 96s+, 85s+, 75s+, 64s+, 53s+, 43s, A8o+, KTo+, QTo+, JTo, T9o" },
      "BTN": { "raise": "99+, ATs+, AJo+, A5s-A2s, KTs+, KQo, QJs, J9s, T8s, 97s, 65s, 54s", "call": "88-22, A2s+, K2s+, Q2s+, J4s+, T6s+, 95s+, 85s+, 74s+, 63s+, 53s+, 43s, A2o+, K8o+, Q9o+, J9o+, T8o+, 98o, 87o" },
      "SB":  { "raise": "TT+, ATs+, AJo+, A5s-A2s, KTs+, KQo, QTs+, J9s, T8s, 97s, 86s, 54s", "call": "99-22, A2s+, K2s+, Q2s+, J3s+, T5s+, 95s+, 84s+, 74s+, 63s+, 53s+, 43s, A2o+, K7o+, Q8o+, J8o+, T8o+, 97o+, 87o, 76o" }
    }
  },

  "vs_3bet": {
    "EP":  { "raise": "KK+, AKs, A5s", "call": "QQ-TT, AKo, AQs, KQs" },
    "LJ":  { "raise": "QQ+, AKs, AKo, A5s", "call": "JJ-99, AQs-AJs, KQs" },
    "HJ":  { "raise": "QQ+, AKs, AKo, A5s-A4s", "call": "JJ-88, AQs-AJs, KQs, KJs, QJs, JTs" },
    "CO":  { "raise": "QQ+, AKs, AKo, A5s-A4s", "call": "JJ-77, AQs-ATs, KQs-KJs, QJs, JTs, T9s, AQo" },
    "BTN": { "raise": "JJ+, AKs, AKo, A5s-A3s", "call": "TT-55, AQs-A9s, KQs-KTs, QJs-QTs, JTs, T9s, 98s, 87s, AQo, AJo, KQo" },
    "SB":  { "raise": "JJ+, AKs, AKo, A5s-A4s", "call": "TT-66, AQs-ATs, KQs-KTs, QJs, JTs, T9s, AQo" }
  },

  "cold_vs_3bet": { "raise": "KK+, AKs", "call": "QQ, AKo" },

  "vs_4bet":      { "raise": "KK+, AKs", "call": "QQ-JJ, AKo, AQs" },

  "cold_vs_4bet": { "raise": "KK+", "call": "" },

  "vs_5bet":      { "raise": "", "call": "QQ+, AKs, AKo" },

  "vs_limp": {
    "EP":  { "raise": "88+, ATs+, KJs+, QJs, AQo+", "call": "" },
    "LJ":  { "raise": "88+, ATs+, KJs+, QJs, AQo+", "call": "" },
    "HJ":  { "raise": "77+, ATs+, KTs+, QTs+, JTs, AJo+, KQo", "call": "" },
    "CO":  { "raise": "66+, A8s+, A5s-A4s, K9s+, Q9s+, J9s+, T9s, ATo+, KJo+", "call": "55-22, A7s-A6s, A3s-A2s, 98s, 87s, 76s, 65s" },
    "BTN": { "raise": "44+, A2s+, K8s+, Q9s+, J9s+, T8s+, 98s, 87s, A9o+, KTo+, QTo+, JTo", "call": "33-22, K7s-K5s, Q8s, J8s, 97s, 86s, 76s, 75s, 65s, 54s" },
    "SB":  { "raise": "77+, A9s+, KTs+, QTs+, JTs, AJo+, KQo", "call": "66-22, A8s-A2s, K9s-K7s, Q9s-Q8s, J9s-J8s, T9s-T8s, 98s, 87s, 76s, 65s, 54s, ATo-A9o, KJo-KTo, QJo, JTo" },
    "BB":  { "raise": "88+, A9s+, KTs+, QTs+, JTs, AJo+, KQo", "call": "" }
  },

  "bb_vs_sb_limp": { "raise": "77+, A7s+, K9s+, Q9s+, J9s+, T8s+, 97s+, A9o+, KTo+, QTo+, JTo", "call": "" }
}
"""#
