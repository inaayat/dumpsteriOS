# Dumpster iOS

A personal thought dumpster — capture everything, sort later. Daily brain dump with AI-powered organization, rich text Master Docs, and smart tagging.

## Features

### Daily Dump
- Bullet journal with auto-formatting (`* ` or `• ` to start a bullet)
- **Inline bullet editing** — tap any bullet from today to edit it in place
- Magic tags auto-categorize bullets: `#action`, `#brainstorm`, `#resource`, `#save`, `#win`
- `#save` files a bullet directly into the relevant Master Doc
- URL bullets auto-create resource items
- Voice bullet — tap the Home Screen widget or Control Center button to record a voice note

### Items
- Categorized tasks: Actions, Brainstorms, Resources
- Priority levels, due dates, notes
- Complete/reopen directly from Tags view and Master Doc view
- Swipe-to-complete in every list view

### Tags
- Auto-created from `#hashtags` in your dump
- Drag-and-drop merge tags
- Rename tags — updates across all items and dump content
- Sub-tag hierarchy
- Tag detail view shows all linked items and dump bullets with inline completion circles

### Master Docs
- Rich text documents that aggregate content from one or more tags
- **Multi-tag docs** — assign multiple `#tags`; all tagged content flows into the inbox
- **Inbox** — unincorporated items with `+` to add them with AI-suggested heading placement
- **AI placement** — on-device AI suggests which heading each item belongs under; confirm or change
- **Sort Trash** — batch-adds all inbox items under their correct headings
- **Outline editor** — add/reorder/delete headings manually
- **Re-incorporate** — items already in the doc can be added again under a different heading
- Complete action/brainstorm items directly from the All Items tab
- Merge docs — move all tags and content from one doc into another
- Legacy markdown docs auto-convert to rich text on first open

### Backup & Restore
- Full JSON export/import via the share sheet
- Covers all items, tags, dumps, Master Docs, and tag assignments
- Export before a clean reinstall to preserve all data

### Widgets
- **Home Screen widget** — dumpster icon; tap to open app and start voice recording
- **Control Center button** — add via Settings → Control Center; tap for instant voice capture
- **Lock Screen widget** — circular and rectangular variants

### On-Device AI (Apple Intelligence)
- Runs entirely on-device — no API keys, no data leaves your phone
- **Requires iPhone 15 Pro or later** with Apple Intelligence enabled (iOS 26+)
- All features work without AI — AI buttons are hidden on unsupported devices

| Feature | With AI | Without AI |
|---|---|---|
| Sort Trash | Places each item under the correct heading | Not available |
| Add from Inbox | Suggests heading, you confirm or change | Manual heading picker |
| #save magic tag | Places bullet under correct heading | Appended as plain bullet |
| Bullet rewrite | Cleans up grammar when adding to doc | Original text used |
| Analyze Dump | Extracts items and suggests tags | Not available |

## Architecture

- **Swift + SwiftUI** targeting iOS 18+
- **GRDB** for local SQLite with versioned migrations (v1–v5)
- **Apple Foundation Models** for on-device AI (iOS 26+, iPhone 15 Pro+)
- **WidgetKit** for Home Screen, Lock Screen, and Control Center widgets
- **Speech framework** for voice capture
- RTF storage for Master Doc rich text (NSAttributedString round-trip)
- No cloud sync — all data is on-device only
- Inter font family throughout

## Deploy to iPhone (Free, No Developer Account Required)

### One-Time Setup

1. **Install Xcode** from the Mac App Store
2. **Open the project** — `open dumpsteriOS.xcodeproj`
3. **Add your Apple ID** — Xcode → Settings → Accounts → + → Apple ID
4. **Select your team** — Signing & Capabilities tab → Team → "Your Name (Personal Team)"

### Install on iPhone

1. **Enable Developer Mode** — Settings → Privacy & Security → Developer Mode → on (phone restarts)
2. Plug iPhone into Mac via USB
3. Select your iPhone in Xcode's device picker
4. **Run (⌘R)** — builds and installs
5. **Trust the certificate** — Settings → General → VPN & Device Management → tap your Apple ID → Trust
6. Run again (⌘R) — app launches

### Wireless (One-Time Setup)

1. Plug iPhone in once, then: Window → Devices and Simulators → select iPhone → check **"Connect via network"**
2. Unplug — iPhone stays in device picker over Wi-Fi

### Re-deploy (Free tier expires every 7 days)

Open project → select iPhone → **⌘R** — done in ~15 seconds wirelessly.

### Troubleshooting

- **"Untrusted Developer"** — Settings → General → VPN & Device Management → Trust
- **"Developer Mode disabled"** — Settings → Privacy & Security → Developer Mode → enable
- **"No profiles found"** — check Signing & Capabilities has Personal Team and auto-signing enabled
- **Keychain prompt** — enter your Mac login password
