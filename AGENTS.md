# Repository Guidelines

## Project Structure & Module Organization

This repository provides Campus Connecte Wi-Fi configuration and reconnection scripts for UMP Oujda.

- `windows/`: main configurator (`campus_wifi.ps1`), reconnect watchdog, elevated `.bat` launcher, optional `campus_config.json`, 802.1X XML profile, and network notes.
- `android/`: Termux Bash assistant (`wifi_watchdog.sh`) and platform setup guide.
- `README.md`: Windows usage and campus network mapping. Keep it aligned with platform documentation.
- Root screenshots are reference material; image extensions are ignored by `.gitignore`. There is no dedicated asset or test directory.

## Build, Test, and Development Commands

Scripts run directly; there is no build system or package manifest. Run these from the repository root unless stated otherwise:

- `.\windows\Lancer_Campus_Wifi.bat`: launch the Windows configurator with UAC elevation.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\wifi_watchdog.ps1`: run Windows reconnection monitoring.
- `bash android/wifi_watchdog.sh`: open the Android menu in Termux.
- `bash android/wifi_watchdog.sh --watchdog`: start Android monitoring.
- `bash -n android/wifi_watchdog.sh`: check Bash syntax without executing networking operations.
- `Get-Content windows/campus_config.json -Raw | ConvertFrom-Json | Out-Null`: validate JSON in PowerShell.

In Termux, install dependencies with `pkg install termux-api jq inetutils`; the Termux:API Android app is also required.

## Coding Style & Naming Conventions

Match existing formatting: four-space function bodies in PowerShell and Bash, two-space JSON indentation. Use PowerShell `Verb-Noun` functions, Bash `snake_case` functions, and uppercase shell configuration constants. Preserve French user-facing messages and comments. Keep platform-specific changes within their respective folders. No formatter or linter configuration is currently present.

## Testing Guidelines

There is no automated test framework or coverage threshold. Validate syntax and configuration before manual testing. On the affected platform, exercise DHCP success, static-IP fallback, connectivity checks, watchdog reconnection, and DHCP restoration when relevant. Record platform, scenario, and observed results. Live runs modify network settings; use a controlled device and record its original configuration.

## Commit & Pull Request Guidelines

History uses concise `fix:`, `feat(android):`, and `refactor:` subjects, often in French. Follow that pattern and scope commits to one change. PRs should explain the problem, affected platforms, validation performed, and any configuration changes; link related issues and include screenshots for menu changes.

## Configuration & Sensitive Data

Keep faculty ranges consistent across JSON, script defaults, and documentation. Do not add personal credentials or unredacted connection logs and screenshots.