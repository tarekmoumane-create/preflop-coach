# Preflop Coach

A macOS menu bar app that watches a poker table on your screen, reads your hole cards,
position and the action so far, and tells you what a standard preflop chart says to do.

Built for private games with friends and for study. Real-money sites ban real-time
assistance and will close your account for it, so don't use it there.

## How it works

1. Every few seconds it takes a screenshot (whole screen, or one app's window).
2. The screenshot goes to Claude, which transcribes the table into JSON: your cards,
   who has the button, who has bet what, how many raises so far.
3. A local chart (`ranges.json`) turns that into an action: `RAISE to 2.5bb`, `3-BET to
   7.5bb`, `CALL`, `FOLD`, `CHECK`, `ALL-IN`.
4. The answer shows in the menu bar (♠︎) and in a draggable always-on-top overlay box.

The chart is the decision maker; the model only reads the screen.

## Install

**Download:** grab `Preflop-Coach.zip` from the
[latest release](https://github.com/tarekmoumane-create/preflop-coach/releases/latest),
unzip it, and drag **Preflop Coach** into your Applications folder.

The app isn't notarized with Apple (that needs a paid developer account), so the first
time you open it macOS will say it "could not verify" the app. To get past that:

1. Double-click the app once; dismiss the warning.
2. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**
   next to the Preflop Coach message. Confirm.

Or, from Terminal: `xattr -dr com.apple.quarantine "/Applications/Preflop Coach.app"`.

**Build it yourself** instead (macOS 13+, Xcode Command Line Tools via `xcode-select --install`):

```bash
./build.sh install     # builds, copies to /Applications, launches
```

## Setup

You need your own Anthropic API key (console.anthropic.com → API Keys). Every read is
billed to it; see Cost below.

Click ♠︎ in the menu bar:

- **Turn On** – asks for the API key and for Screen Recording permission. After
  switching the permission on in System Settings, quit and reopen the app, then Turn On
  again. If the ♠︎ doesn't appear, your menu bar may be full: hold ⌘ and drag an icon
  you don't need off the bar to make room.
- **Watch** – pick the poker app or browser. One window is more accurate and cheaper
  than the whole screen.
- **Check** – how often to look (every 2–10 s) or only when you press ⌃⌥P.
- **Model** – Opus 5.5 (default, most accurate), Sonnet 5.5, or Haiku 4.5 (cheapest).
- **Edit Ranges…** – opens `~/Library/Application Support/PreflopCoach/ranges.json`.
  **Reload Ranges** applies your changes.
- **Show Log** – `~/Library/Logs/PreflopCoach.log`, with every read and reply.

The API key is stored in `~/Library/Application Support/PreflopCoach/api-key`
(readable by your user only). It is never part of this repository.

## Cost

Each read is one API call billed to your key. With Opus 5.5 a read is about 2 cents;
at one read every 3 seconds on a busy table that can add up to a few dollars an hour.
The app only sends a new screenshot when the screen has changed, slows down when no
table is visible or the hand is postflop, and the menu shows a running session total.

## The chart

`ranges.json` covers, for roughly 100bb no-limit hold'em:

- opening ranges by position (`rfi`), including heads-up
- facing an open (`vs_open`), by your position and the opener's
- facing a 3-bet after you opened (`vs_3bet`), or cold (`cold_vs_3bet`)
- facing a 4-bet (`vs_4bet`, `cold_vs_4bet`) and 5-bets (`vs_5bet`)
- limped pots (`vs_limp`, `bb_vs_sb_limp`)

Positions: `EP` (early seats at 7–9 handed), `LJ` (UTG at 6-max), `HJ`, `CO`, `BTN`,
`SB`, `BB`. Notation is the usual `22+`, `ATs+`, `A5s-A2s`, `T9s-65s`. In each spot
`raise` is checked before `call`; anything else folds (or checks in the big blind).

## Layout

```
Sources/PreflopCore    range parser, chart, decision engine, table interpretation
Sources/PreflopCoach   the menu bar app: capture, Claude API client, overlay, menu
Sources/corecheck      self-checks for the core (run by build.sh)
build.sh               builds with plain swiftc, no Xcode project needed
```

`build.sh` signs with a local certificate named "Preflop Coach Local Signing" if one
exists in your keychain, so macOS keeps the Screen Recording permission across rebuilds;
otherwise it signs ad hoc and you may need to re-grant the permission after updating.
