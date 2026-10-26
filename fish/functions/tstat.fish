# The fleet's connectivity is Tailscale: one word for its peers. The macOS
# app ships no `tailscale` command (and its status takes no --short), so
# drive the app binary directly: `tstat --active` for the live peers only.
function tstat --description 'Show the Tailscale peers'
    /Applications/Tailscale.app/Contents/MacOS/Tailscale status $argv
end
