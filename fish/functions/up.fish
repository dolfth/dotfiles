function up --description 'Upgrade macOS software: CLT, brew (the Brewfiles), App Store, mise tools'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    set -l brew_prefix (brew --prefix 2>/dev/null)

    # The dev.mise.* agents run from their keg, so an upgraded keg keeps its old version
    # loaded until restart: record each keg's target (the "/" sentinel keeps an absent
    # keg index-aligned) and kick the one that moved -- the launchctl print guard no-ops
    # where the agent is absent.
    # A keg maps to the agent whose restart re-executes from it: splash has no
    # agent of its own anymore (llama-swap starts the engines), so a moved splash
    # keg restarts the front door, which reloads its engines on demand.
    set -l servers omlx splash llama-swap syncthing
    set -l agents omlx llama-swap llama-swap syncthing
    set -l kegs_before
    if test -n "$brew_prefix"
        for s in $servers
            set -l link (readlink $brew_prefix/opt/$s 2>/dev/null)
            set -a kegs_before "$link/"
        end
    end

    # brew owns the brew-ecosystem packages (README "Why brew + mise"): one upgrade path
    # for everything installed, including tap formulae current mise cannot evaluate.
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
                and launchctl print gui/(id -u)/dev.mise.$agents[$i] >/dev/null 2>&1
                launchctl kickstart -k gui/(id -u)/dev.mise.$agents[$i]
            end
        end
    end

    # mise owns the declared tool versions (language runtimes and friends):
    # upgrade them; a no-op on a host whose modules declare no tools.
    mise upgrade
end
