CONTAINER_JQ_PATTERN=".[0] | { Id, Image: .Config.Image, Status: .State.Status, Workdir: .Config.WorkingDir, EntryPoint: .Config.Entrypoint,Cmd: .Config.Cmd, Binds: .HostConfig.Binds, Ports: .NetworkSettings.Ports, Mounts, Networks: .NetworkSettings.Networks }"
CONTAINER_PREVIEW="--preview=docker inspect {1} | jq -C '$CONTAINER_JQ_PATTERN'"


function dcl() {
    # https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
    local args=$@;
    local cid_array=("${(@f)$(docker ps $args -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
        | fzf $CONTAINER_PREVIEW \
        --bind "ctrl-y:execute-silent(echo -n {1} | xclip -selection clipboard )+abort" \
        --bind "alt-i:execute(docker inspect {1} | jq -C . | less -R > /dev/tty)" \
        --header="Select container(s) " \
        --preview-window="down:70%" \
        --header-lines=1 -m | awk '{print $1}')}")

    if [ "${cid_array[1]}" -eq "" 2> /dev/null ]; then
        echo "Aborted"
        return
    fi
    local cmd=$(docker container --help | sed 1,5d | fzf \
    --header-lines=1 \
    --preview="docker container {1} --help | less" \
    --preview-window="down:70%" | awk '{print $1}')

    if [ "$cmd" -eq "" 2> /dev/null ]; then
        echo "Not command selected"
        return
    fi

    print -z docker container $cmd ${cid_array[@]}
}


function dce() {
    local cname opts
    read cname <<< $(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" \
        | fzf $CONTAINER_PREVIEW \
        --bind "alt-i:execute(docker inspect {1} | jq -C . | less -R > /dev/tty)" \
        --preview-window="down:70%" \
        --header="Exec command in running container" \
        --header-lines=1 | awk '{print $1}')
    opts="-it"
    if [[ $cname != '' ]]; then
        echo "Docker container:" $cname
        vared -p "Options: " opts
        read 'cmd?Command: '
        # [ -n "$cmd" ] && print -z docker exec "$opts" "$cname" "$cmd" || echo "No command selected"
        [ -n "$cmd" ] && docker exec "$opts" "$cname" "$cmd" || echo "No command provided"
    else
    echo "No container selected"
    fi
}

function jqit() { # jq interactive filtering
JQ_PREFIX=" cat $1 | jq -C "
INITIAL_QUERY=""
FZF_DEFAULT_COMMAND="$JQ_PREFIX '$INITIAL_QUERY'" fzf \
    --bind "change:reload:$JQ_PREFIX {q} || true" \
    --bind "ctrl-r:reload:$JQ_PREFIX ." \
    --ansi --phony
}

function rgit() { # jq interactive filtering
RG_OPTS=${@:2:#}
FZF_DEFAULT_COMMAND="rg $RG_OPTS -pe '\b\B' $1" fzf \
    --bind "change:reload:rg $RG_OPTS -pe {q} $1 || true" \
    --bind "ctrl-r:reload:rg $RG_OPTS -pe '^$' $1" \
    --bind "ctrl-s:execute-silent(rg -pe {q} $1 > rgit-$(date --iso-8601=seconds))+abort" \
    --preview="echo {} | bat" \
    --preview-window="down:30%:wrap" \
    --ansi --phony
}


function dil() { #docker image list insteractive 
    # https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
    local cid_array=("${(@f)$(docker image ls $@ | fzf \
        --preview="docker inspect {3} | jq -C ." \
        --preview-window="down:70%" \
        --bind "ctrl-y:execute-silent(echo -n {3} | xclip -selection clipboard )+abort" \
        --bind "alt-i:execute(docker inspect {3} | jq -C . | less -R > /dev/tty)" \
        --header="Docker image list " \
        --header-lines=1 -m | awk '{print $3}')}")

    if [ "${cid_array[1]}" -eq "" 2> /dev/null ]; then
        echo "Aborted"
        return
    fi

    local cmd=$(docker image --help | sed 1,5d | fzf \
    --header-lines=1 \
    --preview="docker image {1} --help | less" \
    --preview-window="down:60%" | awk '{print $1}')

    if [ "$cmd" -eq "" 2> /dev/null ]; then
        echo "Not command selected"
        return
    fi

    print -z docker image $cmd ${cid_array[@]}
}
