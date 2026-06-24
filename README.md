# Dumpster iOS — Version 2

iOS companion to the [Dumpster](https://github.com/inaayat/dumpster) macOS app. A personal thought dumpster — capture everything, sort later.

## What's New in Version 2

**On-Device AI (Apple Intelligence)**
- **Sort Trash** — AI reorganizes your Master Docs into well-structured documents with headings and sections
- **Smart #save** — when you use `#save` in your dump, AI places the bullet into the correct section of the Master Doc (not just appended at the bottom)
- **Analyze Dump** — AI extracts action items and suggests tags from your daily dump
- Runs entirely on-device via Apple's Foundation Models framework — no API keys, no data leaves your phone
- **Requires iPhone 15 Pro or later** with Apple Intelligence enabled (iOS 26+)
- **The app works fully without AI** — older devices get all features except smart placement and Sort Trash; `#save` appends bullets as a list instead

**Rich Text Master Doc Editor**
- Full Notes-app-style editing: bold, italic, underline, strikethrough
- Headings (Title, Heading, Subheading, Body)
- Bullet and numbered lists with auto-continuation on Return
- Indent/outdent with hanging indents and per-level bullet markers (•, ◦, ▪)
- Backspace on empty bullet outdents or exits the list
- Formatting toolbar above the keyboard (inputAccessoryView)
- RTF persistence — formatting survives save/reload

**Tag Management**
- Drag-and-drop merge tags in the Tags tab
- Rename tags across all items and dump content
- Add/remove tags on items and individual dump bullets
- MasterDocs consolidate correctly during tag merges

**Item Editing**
- Edit item text inline (pencil icon in detail view)
- Create linked resources directly from action/brainstorm items
- Complete/reopen brainstorm items (not just actions)
- Swipe-to-complete and swipe-to-reopen in every view

**UX Improvements**
- Auto-expanding "Add a bullet" text field
- URL bullets auto-create resource items with `[bracket]` title support
- Reduced tag spacing in Tags tab

## Features

- **Daily Dump** — bullet journal with auto-formatting and magic tags
- **Items** — categorized tasks (Actions, Brainstorms, Resources) with priority and due dates
- **Tags** — auto-created from #hashtags, drag-drop merge, rename, sub-tag hierarchy
- **Master Docs** — rich text documents per tag, AI-sorted with #save
- **On-Device AI** — Sort Trash, smart insert, dump analysis (iPhone 15 Pro+ only)
- **Guide** — in-app reference for all features including AI availability status

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

- **Swift + SwiftUI** targeting iOS 26+
- **GRDB** for local SQLite database (same schema as macOS app, separate local DB)
- **Apple Foundation Models** for on-device AI (iOS 26+, iPhone 15 Pro+)
- **No cloud sync** — data lives on-device only
- Inter font family for consistent design with macOS app

## AI Compatibility

| Device | AI Features | Everything Else |
|--------|------------|-----------------|
| iPhone 15 Pro / Pro Max or later | Full AI (Sort Trash, smart #save, analyze) | All features |
| iPhone 15 / 14 / older | Not available — buttons hidden | All features work normally |

The app detects Apple Intelligence availability at runtime and hides AI UI on unsupported devices. No features are lost — `#save` simply appends as a bullet list, and the Sort Trash button doesn't appear.
