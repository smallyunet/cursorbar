# CursorBar

A lightweight macOS menu bar app that shows your Cursor plan usage and how much you have left this billing cycle.

No browser tab, no manual cookie paste — CursorBar reads your session from the local Cursor IDE database and fetches usage from Cursor's dashboard API.

![CursorBar dropdown showing remaining monthly quota, billing-cycle countdown, agent status, and plan details](docs/screenshot.png)

## Features

- **Remaining monthly quota** — menu bar shows the original quota pill and the remaining included percentage (`68%`)
- **Countdown meters** — dropdown pairs remaining monthly quota with time left until the billing-cycle reset so the two remaining bars can be compared
- **Agents** — dropdown lists inferred local and cloud agent counts, plus agents needing input; click an agent to open it in Cursor
- **Usage details** — structured Cursor Models / Other Models percentages and monetary values only when Cursor reports their matching API fields; missing values stay unavailable rather than being inferred
- **Billing cycle reset** — remaining duration uses the server-provided cycle start and end; missing dates show Unavailable rather than an assumed month
- **Auto-refresh** — on launch and every 5 minutes
- **Manual refresh** — click Refresh in the dropdown anytime
- **Manual update checks** — checks this repository's GitHub releases only when requested and opens the release page

## Requirements

- macOS 14 (Sonoma) or later
- [Cursor IDE](https://cursor.com) installed and signed in on this Mac
- Swift 6 — only needed if [building from source](#build-from-source)

## Install

### GitHub Releases (recommended)

Download the latest universal ZIP from
[GitHub Releases](https://github.com/smallyunet/cursorbar/releases/latest), unzip it,
and move `CursorBar.app` to `/Applications`. Open it from Applications or run:

```bash
open -a CursorBar
```

### Build from source

```bash
git clone https://github.com/smallyunet/cursorbar.git
cd cursorbar
bash scripts/install.sh
```

This builds CursorBar locally, installs it to `/Applications/CursorBar.app`, and opens it.

### Launch later

```bash
open -a CursorBar
```

Or, if you built from source:

```bash
bash scripts/launch.sh
```

## Usage

| Menu bar | Click to open dropdown |
|----------|------------------------|
| `68%` | Remaining monthly quota, billing-cycle countdown, agent details, refresh & quit |

The menu bar percentage is remaining included quota, not usage consumed. Unlimited plans show `∞`.

Agent status is read from local Cursor IDE data (transcripts and `state.vscdb`). Cloud agent status and plan/input flags can lag the UI by a minute or two because the IDE debounces writes to disk. Click an agent under **Needs input** to focus it in the Cursor app.

The two dropdown progress bars are remaining-state meters: monthly quota remaining, and time remaining until billing reset. They use a neutral fill so the two countdowns can be compared without color-coded “used” gauges.

**Auto-refresh:** immediately on launch, then every **5 minutes** while the app is running.

**Errors:** if something goes wrong, the menu bar shows `!` — open the dropdown for details.

## Troubleshooting

Check that CursorBar can read your account:

```bash
/Applications/CursorBar.app/Contents/MacOS/CursorBar --status
```

Expected output: `OK 50% remaining` (your percentage will differ).

Common issues:

| Problem | Fix |
|---------|-----|
| `!` in menu bar | Make sure Cursor is installed and you're signed in, then click **Refresh** |
| App won't open from Finder | Run `bash scripts/launch.sh` — it clears Gatekeeper quarantine flags |
| `Swift is not installed` | Run `xcode-select --install` |
| `No auth token found` | Sign out and back into Cursor, then relaunch CursorBar |

## How it works

1. Reads `cursorAuth/accessToken` from Cursor's local SQLite database  
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
2. Derives a session cookie from the JWT
3. Calls `GET https://cursor.com/api/usage-summary`

The token is read fresh on every refresh and is **never stored** by CursorBar.

## Development

```bash
git clone https://github.com/smallyunet/cursorbar.git
cd cursorbar

# Build only
bash scripts/package.sh

# Run tests and verify the app bundle
bash scripts/verify.sh

# Build, install to /Applications, and launch
bash scripts/package.sh --install --open

# Verify API access
.build/release/CursorBar --status
```

Project layout:

```
Sources/CursorBar/
  App.swift           # MenuBarExtra UI
  AgentMonitor.swift  # Live agent count & needs-input detection
  TokenProvider.swift # Read auth from Cursor IDE DB
  CursorAPI.swift     # Fetch usage-summary
  UsageStore.swift    # Refresh timer & display state
  UsageRemaining.swift # Remaining quota and billing-cycle countdown
  UpdateChecker.swift # Manual GitHub release checks
scripts/
  install.sh          # One-step install
  launch.sh           # Start the app
  package.sh          # Build .app bundle
  verify.sh           # Contracts, tests, build, and bundle checks
  release.sh          # Universal ZIP + SHA-256 release artifact
```

## Limitations

- Uses Cursor's **undocumented** dashboard API — may break without notice
- Agent status is inferred from local IDE files — may lag the UI or miss edge cases
- Individual Cursor accounts only (reads your local IDE session)
- Not signed with an Apple Developer ID — first launch may require right-click → Open, or use `scripts/launch.sh`

## Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

This is an independently maintained distribution of
[`c-johannesen/cursorbar`](https://github.com/c-johannesen/cursorbar).
Contributions to this distribution should target `smallyunet/cursorbar`.

## License

MIT — see [LICENSE](LICENSE).
