function up --description 'Upgrade macOS software: CLT, brew (the Brewfiles), App Store, mise tools'
    # macOS never installs Command Line Tools updates by itself, and brew
    # refuses to build from source with outdated ones.
    for label in (softwareupdate -l 2>/dev/null | string match -r '(?<=Label: )Command Line Tools.*')
        sudo softwareupdate -i $label
    end

    set -l brew_prefix (brew --prefix 2>/dev/null)

    # The dev.mise.* agents keep their old keg loaded until restart: record
    # each keg's target (the "/" sentinel keeps absent kegs index-aligned) and
    # kickstart the ones that moved. splash has no agent of its own -- a moved
    # splash keg restarts llama-swap, which reloads its engines on demand.
    set -l servers omlx splash llama-swap syncthing
    set -l agents omlx llama-swap llama-swap syncthing
    set -l kegs_before
    if test -n "$brew_prefix"
        for s in $servers
            set -l link (readlink $brew_prefix/opt/$s 2>/dev/null)
            set -a kegs_before "$link/"
        end
    end

    # brew owns the brew ecosystem (README, "Packages (the Brewfiles)").
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

    # mise owns the declared tool versions; no-op where modules declare none.
    mise upgrade

    # Only reinstalls when the pin moved ahead of the Sparkle-updated app;
    # no-op off gza.
    mise run luxmini
end
