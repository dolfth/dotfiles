function up --description 'Upgrade macOS software: CLT, brew (the Brewfiles), App Store, mise tools'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    set -l brew_prefix (brew --prefix 2>/dev/null)

    # The dev.mise.* agents run from their keg, so an upgraded keg keeps its
    # old version loaded until the agent restarts: record each keg's target
    # (the "/" sentinel keeps an absent keg a list element, so the two
    # snapshots stay index-aligned) and kick the one that moved -- the
    # launchctl print guard no-ops where the agent is absent.
    set -l servers omlx splash syncthing
    set -l kegs_before
    if test -n "$brew_prefix"
        for s in $servers
            set -l link (readlink $brew_prefix/opt/$s 2>/dev/null)
            set -a kegs_before "$link/"
        end
    end

    # brew owns the brew-ecosystem packages (the Brewfiles, README "Why
    # brew + mise"): one upgrade path for everything installed, including
    # the tap formulae the current mise release cannot evaluate itself.
    brew update; and brew upgrade

    # App Store auto-updates are off (com.apple.commerce AutoUpdate).
    type -q mas; and mas upgrade

    if test -n "$brew_prefix"
        set -l kegs_after
        for s in $servers
            set -l link (readlink $brew_prefix/opt/$s 2>/dev/null)
            set -a kegs_after "$link/"
        end
        for i in (seq (count $servers))
            if test "$kegs_before[$i]" != "$kegs_after[$i]"
                and launchctl print gui/(id -u)/dev.mise.$servers[$i] >/dev/null 2>&1
                launchctl kickstart -k gui/(id -u)/dev.mise.$servers[$i]
            end
        end
    end

    # mise owns the declared tool versions (language runtimes and friends):
    # upgrade them; a no-op on a host whose modules declare no tools.
    mise upgrade
end
