# The fleet's connectivity is Tailscale: one word for its peers
# (`tstat --short` for the one-line list).
function tstat --description 'Show the Tailscale peers'
    tailscale status $argv
end
