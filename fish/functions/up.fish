function up --description 'Upgrade mise packages, Homebrew leftovers and App Store apps'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    # The version a running server was started with, from the opt link.
    # readlink works whether the keg is brew- or mise-managed; brew's
    # `list --versions` would miss kegs mise poured.
    set -l omlx_before (string trim (readlink /opt/homebrew/opt/omlx 2>/dev/null))
    set -l splash_before (string trim (readlink /opt/homebrew/opt/splash 2>/dev/null))

    # Everything mise manages (mise-tasks/packages-upgrade: every resolvable
    # formula of the Mac modules; the omlx, splash and omp tap definitions
    # the current mise release cannot evaluate stay out of the named list).
    mise run packages-upgrade

    # omlx, splash and omp on a machine that has Homebrew: mise cannot
    # evaluate their tap definitions (omlx and splash: formula constructs
    # its metadata shim lacks, see mise-tasks/omlx-splash; omp: its with_env
    # install step is rejected by mise's source-build shim), so their kegs
    # stay Homebrew-managed. omlx and splash upgrade in place; omp has no
    # bottle, so a reinstall is how it picks up new versions (a no-op when
    # current). A fresh machine has no Homebrew, where mise owns the
    # omlx/splash kegs (omlx-splash task) and omp stays at its installed
    # version until mise supports with_env.
    if type -q brew
        brew update; and brew upgrade omlx splash
        brew install can1357/homebrew-tap/omp 2>/dev/null; or echo "up: 'brew install can1357/homebrew-tap/omp' failed; run it manually"
    end

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
end
