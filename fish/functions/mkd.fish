# mkdir -p + cd in one word: the "make a directory and work in it" pattern.
function mkd --description 'Make a directory and move into it'
    mkdir -p $argv; and cd $argv
end
