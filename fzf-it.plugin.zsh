CONTAINER_JQ_PATTERN=".[0] | { Id, Image: .Config.Image, Status: .State.Status, Workdir: .Config.WorkingDir, EntryPoint: .Config.Entrypoint,Cmd: .Config.Cmd, Binds: .HostConfig.Binds, Ports: .NetworkSettings.Ports, Mounts, Networks: .NetworkSettings.Networks }"
CONTAINER_PREVIEW="--preview=docker inspect {1} | jq -C '$CONTAINER_JQ_PATTERN'"


function dkl() {
    # https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
    local args=$@;
    local cid_array=("${(@f)$(docker ps $args -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
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

function dcpl() {
    # https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
    local args=$@;
    local cid_array=("${(@f)$(docker compose ps $args --services -a \
        | fzf $CONTAINER_PREVIEW \
        --bind "ctrl-y:execute-silent(echo -n {1} | xclip -selection clipboard )+abort" \
        --bind "alt-i:execute(docker inspect {1} | jq -C . | less -R > /dev/tty)" \
        --header="Select container(s) " \
        --preview="docker compose ps --format json {1} | jq -C . | less -R" \
        --preview-window="right:80%" \
         -m | awk '{print $1}')}")

    if [ "${cid_array[1]}" -eq "" 2> /dev/null ]; then
        echo "Aborted"
        return
    fi
    local cmd=$(docker compose --help | awk '/^Commands/{flag=1} flag == 1 {print $0}; flag == 1 && length($0) == 0 {exit}' | fzf \
    --header-lines=1 \
    --preview="docker compose {1} --help | less" \
    --preview-window="down:70%" | awk '{print $1}')

    if [ "$cmd" = "" 2> /dev/null ]; then
        echo "Not command selected"
        return
    fi

    local opts="--follow --tail 100 --since 30s "
    vared -p "Options: " opts
    print -z docker compose "$cmd" "$opts" ${cid_array[@]}

}


function dke() {
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
        [ -n "$cmd" ] && print -z docker exec "$opts" "$cname" "$cmd" || echo "No command selected"
        # [ -n "$cmd" ] && docker exec "$opts" "$cname" "$cmd" || echo "No command provided"
    else
    echo "No container selected"
    fi
}

function dkgu() {
    # https://unix.stackexchange.com/questions/29724/how-to-properly-collect-an-array-of-lines-in-zsh
    local args=$@;
    local cid_array=("${(@f)$(docker ps $args -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
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

    print -z "docker container stop ${cid_array[@]}; docker container rm -f ${cid_array[@]}"
  }

function jqit() { # jq interactive filtering
JQ_PREFIX=" cat $@ | jq -C "
INITIAL_QUERY=""
FZF_DEFAULT_COMMAND="$JQ_PREFIX '$INITIAL_QUERY'" fzf \
    --bind "change:reload:$JQ_PREFIX {q} || true" \
    --bind "ctrl-r:reload:$JQ_PREFIX ." \
    --ansi --phony
}

function rgit() { # rg interactive filtering
  RG_OPTS=$(echo ${@} | grep -Eo '(^-\w+|\s-\w+)' | awk '{print}' ORS='')
  FILES=$(echo ${@} | grep -Eo '(^|\s)([A-Za-z0-9_]+[_.-]*[A-Za-z0-9])+' | awk '{print}' ORS='')
  FZF_DEFAULT_COMMAND="echo Type to searching in files: $FILES" fzf \
    --bind "change:reload:rg $RG_OPTS -pe {q} $FILES || true" \
    --bind "ctrl-r:reload:rg $RG_OPTS -pe '^$' $FILES" \
    --bind "alt-l:reload:rg  $RG_OPTS -lpe {q} $FILES" \
    --bind "ctrl-s:execute-silent(rg -pe {q} $FILES | sed -r 's/\x1b\[[^@-~]*[@-~]//g' > rgit-{q})+abort" \
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
