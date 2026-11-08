function mkd --description 'Make a directory and move into it'
    mkdir -p $argv; and cd $argv
end
