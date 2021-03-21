CONTAINER_JQ_PATTERN=".[0] | { Id, Image: .Config.Image, Status: .State.Status, Workdir: .Config.WorkingDir, EntryPoint: .Config.Entrypoint,Cmd: .Config.Cmd, Binds: .HostConfig.Binds, Ports: .NetworkSettings.Ports, Mounts, Networks: .NetworkSettings.Networks }"
CONTAINER_PREVIEW="--preview=docker inspect {1} | jq -C '$CONTAINER_JQ_PATTERN'"
DOCKER_OPTS="rm\nstart\nstop\nrename\ninspect\ntag\nlogs"


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
    local cmd=$(echo $DOCKER_OPTS | fzf --header="Select command" \
    --preview="docker container {1} --help | less" \
    --preview-window="down:70%")

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
