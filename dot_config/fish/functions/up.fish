function up --description 'Update Command Line Tools, Homebrew and App Store apps'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    set -l omlx_before (brew list --versions omlx 2>/dev/null)
    brew update; and brew upgrade
    # App Store auto-updates are off (com.apple.commerce AutoUpdate).
    type -q mas; and mas upgrade

    # A running omlx keeps the old version until it is restarted.
    set -l omlx_after (brew list --versions omlx 2>/dev/null)
    set -l agent gui/(id -u)/com.dolfth.omlx
    if test "$omlx_before" != "$omlx_after"; and launchctl print $agent >/dev/null 2>&1
        launchctl kickstart -k $agent
    end
end
