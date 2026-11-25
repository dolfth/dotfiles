# The LuxMini pin. Homebrew 7 loads casks by name only and upstream publishes
# no tap -- this is the draft cask from the app repo (packaging/homebrew/)
# bumped to the current release -- so the luxmini task reads the version and
# sha256 from here and installs the DMG itself. If upstream ever ships the
# tap, this file is the drop-in and the task retires.
# Bump: version and DMG sha256 from the release page's SHA256SUMS.txt --
# https://github.com/bastiencantet/luxmini-public/releases
# The app self-updates via Sparkle; the task never downgrades an install that
# moved ahead of the pin. pin-check probes this version's asset URL weekly, so
# a release asset removed upstream is announced before a bootstrap eats it.
cask "luxmini" do
  version "0.5.4"
  sha256 "a293408a2ce21101e2526a19515e40f8323d7d0d2e5046a984558362929d3532"

  url "https://github.com/bastiencantet/luxmini-public/releases/download/v#{version}/LuxMini-#{version}.dmg"
  name "LuxMini"
  desc "Turn off, dim, or schedule your Mac's front LED"
  homepage "https://luxmini.bastiencantet.com"

  auto_updates true

  app "LuxMini.app"
end
