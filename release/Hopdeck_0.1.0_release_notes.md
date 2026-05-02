## Hopdeck 0.1.0

First local-first macOS release for Hopdeck, an SSH jump workspace built with Rust, Tauri, and React.

### Highlights

- Tree-based host and folder navigation.
- Double-click host connect flow with embedded terminal tabs.
- Password and key-based SSH connection support, including jump chains.
- Local plain vault support for saved password auto-login.
- Packaged builds now include the Tauri capabilities needed for terminal output and exit listeners.
- Auto-login can now answer password prompts across jump chains in order.
- Terminal output is replayed when tabs attach, so active sessions keep their visible history.
- Terminal selection can be copied automatically without pressing Cmd+C.
- Settings import/export and SSH config import.
- Light, dark, and system appearance modes with built-in terminal color palettes.
- iTerm2 theme import for terminal colors, font, opacity, and blur.
- Custom Hopdeck app icon and macOS app bundle packaging.

### Download

- `Hopdeck_0.1.0_aarch64.app.zip` for Apple Silicon Macs.
- SHA256: `faef615fc8c949455b5ee22661b4a7756c0eb659bffdac1291646545e2027782`

### Notes

- The app is not notarized yet, so macOS may require right-click Open on first launch.
- DMG packaging is deferred because the local Tauri DMG helper currently fails during the Finder/AppleScript layout step.
