# The fleet's connectivity is Tailscale: one word for its peers. The brew
# formula puts `tailscale` on PATH; the app ships none (and its status
# takes no --short), so fall back to the app binary. `tstat --active` for
# the live peers only.
function tstat --description 'Show the Tailscale peers'
    if command -sq tailscale
        tailscale status $argv
    else
        /Applications/Tailscale.app/Contents/MacOS/Tailscale status $argv
    end
end
