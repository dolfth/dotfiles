# Which process owns a port. The omlx/splash servers live on fixed ports
# (8080/8000/8100), so this is the first thing to try when one misbehaves.
function port --description 'Show what is listening on a port'
    if test -z "$argv"
        echo "usage: port <port>" >&2
        return 1
    end
    lsof -nP -iTCP:$argv -sTCP:LISTEN
end
