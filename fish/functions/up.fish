function up --description 'Upgrade macOS software: CLT, brew (the Brewfiles), App Store, mise tools'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    # The version a running server was started with, from the opt link.
    set -l omlx_before (string trim (readlink /opt/homebrew/opt/omlx 2>/dev/null))
    set -l splash_before (string trim (readlink /opt/homebrew/opt/splash 2>/dev/null))
    set -l syncthing_before (string trim (readlink /opt/homebrew/opt/syncthing 2>/dev/null))

    # brew owns the brew-ecosystem packages (the Brewfiles, see README "Why
    # brew + mise"): one upgrade path for all of them -- the 18 shared
    # formulae and 3 casks both Macs get, the laptop's GUI apps, the
    # desktop's omlx, splash and omp -- including the three tap formulae the
    # current mise release cannot evaluate itself. `brew upgrade` covers
    # every installed formula, whether or not it is in the Brewfiles.
    brew update; and brew upgrade

    # App Store auto-updates are off (com.apple.commerce AutoUpdate).
    type -q mas; and mas upgrade

    # A running omlx or splash keeps the old version until it is restarted:
    # kickstart the dev.mise.* agent whose keg changed.
    set -l omlx_after (string trim (readlink /opt/homebrew/opt/omlx 2>/dev/null))
    if test "$omlx_before" != "$omlx_after"; and launchctl print gui/(id -u)/dev.mise.omlx >/dev/null 2>&1
        launchctl kickstart -k gui/(id -u)/dev.mise.omlx
    end
    set -l splash_after (string trim (readlink /opt/homebrew/opt/splash 2>/dev/null))
    if test "$splash_before" != "$splash_after"; and launchctl print gui/(id -u)/dev.mise.splash >/dev/null 2>&1
        launchctl kickstart -k gui/(id -u)/dev.mise.splash
    end
    # Syncthing, laptop only: now a dev.mise launchd agent, so an upgraded
    # keg needs the same kick; the guard no-ops where it is not installed.
    set -l syncthing_after (string trim (readlink /opt/homebrew/opt/syncthing 2>/dev/null))
    if test "$syncthing_before" != "$syncthing_after"; and launchctl print gui/(id -u)/dev.mise.syncthing >/dev/null 2>&1
        launchctl kickstart -k gui/(id -u)/dev.mise.syncthing
    end

    # mise owns the declared tool versions (language runtimes and friends):
    # upgrade them; a no-op on a host whose modules declare no tools.
    mise upgrade
end
