# Dumpster iOS

iOS companion to the [Dumpster](https://github.com/inaayat/dumpster) macOS app. A personal thought dumpster — capture everything, sort later.

## Features

- **Daily Dump** — bullet journal with auto-formatting and magic tags
- **Items** — categorized tasks (Actions, Brainstorms, Resources) with priority and due dates
- **Tags** — auto-created from #hashtags, with sub-tag hierarchy
- **Master Docs** — living documents per tag, append with #save
- **Guide** — in-app reference for all features

## Deploy to iPhone (Free, No Developer Account Required)

### One-Time Setup

1. **Install Xcode** from the Mac App Store
2. **Open the project** — `open dumpsteriOS.xcodeproj`
3. **Add your Apple ID to Xcode** — Xcode → Settings → Accounts → + → Apple ID
4. **Select your team** — in the project's Signing & Capabilities tab, set Team to "Your Name (Personal Team)"

### Install on iPhone

1. **Enable Developer Mode on iPhone** — Settings → Privacy & Security → Developer Mode → toggle on (phone restarts)
2. **Plug iPhone into Mac** via USB/USB-C
3. **Select your iPhone** in Xcode's device picker (top of window)
4. **Run (⌘R)** — Xcode builds and installs the app
5. **Trust the developer certificate on iPhone** — Settings → General → VPN & Device Management → tap your Apple ID → Trust
6. **Run again (⌘R)** — the app launches on your phone

### Wireless Setup (One-Time, So You Never Need the Cable Again)

1. **Plug your iPhone in** one more time
2. In Xcode: **Window → Devices and Simulators** → select your iPhone → check **"Connect via network"**
3. **Unplug** — your iPhone will stay visible in Xcode's device picker over Wi-Fi (both devices must be on the same network)

### Weekly Re-deploy (Free Tier Expires Every 7 Days)

The free provisioning profile expires after 7 days. To refresh wirelessly:

1. Open the project in Xcode
2. Select your iPhone from the device picker
3. Hit **⌘R** — rebuilds and re-deploys wirelessly in ~15 seconds

### Troubleshooting

- **"Untrusted Developer" on iPhone** — Settings → General → VPN & Device Management → Trust
- **"Developer Mode disabled"** — Settings → Privacy & Security → Developer Mode → enable
- **"No profiles found"** — make sure Signing & Capabilities has your Personal Team selected and "Automatically manage signing" is checked
- **Can't see iPhone in Xcode** — try unplugging and re-plugging, or restart Xcode
- **Keychain password prompt** — this is your Mac login password (used to access signing certificates)

## Architecture

- **Swift + SwiftUI** targeting iOS 18+
- **GRDB** for local SQLite database (same schema as macOS app, separate local DB)
- **No cloud sync** — data lives on-device only
- Inter font family for consistent design with macOS app

## macOS-Only Features (Not on iOS)

- AI analysis (analyze dumps, synthesize docs)
- Wins tab
- Quick Dump floating panel (Ctrl+Opt+N hotkey)
- Menu bar icon
- Drag-and-drop tag merging
- Export to Markdown
- Bro mode (dark theme toggle — iOS follows system dark mode)
