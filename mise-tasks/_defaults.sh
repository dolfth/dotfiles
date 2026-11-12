# shellcheck shell=bash
# Shared defaults domain list. Source from defaults-snapshot and system-check
# so the list stays in one place.
_UI_DOMAINS=(
  com.apple.dock com.apple.spaces com.apple.WindowManager
  com.apple.finder com.apple.menuextra.clock NSGlobalDomain
  com.apple.NetworkBrowser com.apple.LaunchServices
  com.apple.print.PrintingPrefs
  com.apple.HIToolbox com.apple.driver.AppleBluetoothMultitouch.trackpad
  com.apple.desktopservices com.apple.screencapture
  com.apple.ActivityMonitor com.apple.ImageCapture
  com.apple.TimeMachine com.apple.commerce
  com.apple.mail com.apple.TextEdit
  com.apple.Displays-Settings.extension
)

# Export the UI domains to stdout; defaults-snapshot hashes this BEFORE
# bootstrap writes the declarative defaults and system-check hashes it AFTER:
# equal hashes mean nothing bootstrap wrote changes what the UI reads, so no
# Dock/Finder/... restart is warranted. controlcenter and the per-host
# NSGlobalDomain live under -currentHost.
snap() {
  for d in "${_UI_DOMAINS[@]}"; do
    defaults export "$d" - 2>/dev/null || true
  done
  defaults -currentHost export com.apple.controlcenter - 2>/dev/null || true
  defaults -currentHost export NSGlobalDomain - 2>/dev/null || true
}
