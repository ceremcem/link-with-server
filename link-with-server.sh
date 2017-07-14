#!/bin/bash

# Author : Cerem Cem ASLAN cem@aktos.io
# Date   : 30.05.2014

# Use "help" as an argument to get usage

set_dir () { DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"; }
safe_source () { source $1; set_dir; }
set_dir

safe_source $DIR/aktos-bash-lib/basic-functions.sh
safe_source $DIR/aktos-bash-lib/ssh-functions.sh

SSH_USER="mobmac2"
SSH_HOST="aktos.io"
SSH_PORT=443
#SSH_KEY_FILE="$DIR/ssh_keys/test_id"
SSH_KEY_FILE="$HOME/.ssh/id_rsa"

RENDEZVOUS_SSHD_PORT=7100

get_socket_file () {
    local SSH_SOCKET_FILE="/tmp/ssh-$SSH_USER@$SSH_HOST:$SSH_PORT.sock"
    printf "%q" $SSH_SOCKET_FILE
}

ssh_pid=
start_port_forwarding () {
    # DONT USE -f OPTION, $ssh_pid is changing after a few seconds otherwise.
    $SSH $SSH_USER@$SSH_HOST -p $SSH_PORT -i $SSH_KEY_FILE -N \
        -R $RENDEZVOUS_SSHD_PORT:localhost:22 \
        -L 2222:localhost:$RENDEZVOUS_SSHD_PORT \
        -M -S $(get_socket_file) &
    ssh_pid=$!
}

ssh_run_via_socket () {
    $SSH -N -S $(get_socket_file) $SSH_HOST $@ &
}

is_port_forward_working () {
    # maybe we could try something like `ssh localhost -p 2222 exit 0`
    # in the future
    local nc_timeout=10
    local proxied=$(echo | timeout $nc_timeout nc localhost 2222 2> /dev/null)
    local orig=$(echo | timeout $nc_timeout nc localhost 22 2> /dev/null)

    #echo "proxied: $proxied, orig: $orig"
    if [[ "$proxied" == "" ]]; then
        #echo "no answer, tunnel is broken."
        return 55
    else
        if [[ "$proxied" == "$orig" ]]; then
            #echo "tunnel is working."
            return 0
        else
            #echo "ssh server responses differs!"
            return 1
        fi
    fi
}

cleanup () {
    echo_stamp "cleaning up..."
    if [ $ssh_pid ]; then
        #echo "SSH pid found ($ssh_pid), killing."
        kill $ssh_pid 2> /dev/null
    fi
}

trap cleanup EXIT

reconnect () {
    start_port_forwarding
    echo -n $(echo_stamp "starting port forward (pid: $ssh_pid)")
    for max_retry in {60..1}; do
        if ! is_port_forward_working; then
            #echo_yellow "!! Broken port forward !! retry: $max_retry"
            echo -n "."
        else
            echo
            echo_green $(echo_stamp "Port forward is working")
            return 0
        fi
        sleep 1s
    done
    return 1
}

echo_stamp () {
  local MESSAGE="$(date +'%F %H:%M:%S') - $@"
  echo $MESSAGE
}


echo_green "using socket file: $(get_socket_file)"
while :; do
    reconnect
    if [ $? == 0 ]; then
        echo_stamp "waiting for tunnel to break..."
        # run "on-connection" scripts here
        while IFS= read -r file; do
            echo_green $(echo_stamp "running: ${file#"$DIR/"}")
            safe_source $file
        done < <(find $DIR/on-connect/ -type f)
    else
        echo_stamp "....unable to create a tunnel."
    fi
    while :; do
        if ! is_port_forward_working; then
            break
        fi
        sleep 5
    done
    echo_stamp "tunnel seems broken. cleaning up."
    cleanup
    while IFS= read -r file; do
        echo_yellow $(echo_stamp "running: ${file#"$DIR/"}")
        safe_source $file
    done < <(find $DIR/on-disconnect/ -type f)
    reconnect_delay=2
    echo_stamp "reconnecting in $reconnect_delay seconds..."
    sleep $reconnect_delay
done


generate_ssh_id () {
	# usage:
	#   generate_ssh_id /path/to/ssh_id_file
	local SSH_ID_FILE=$1
	local SSH_ID_DIR=$(dirname "$SSH_ID_FILE")

	#debug
	#echo "SSH ID FILE: $SSH_ID_FILE"
	#echo "DIRNAME: $SSH_ID_DIR"
	#exit

	if [ ! -f "$SSH_ID_FILE" ]; then
		echolog "Generating SSH ID Key..."
		mkdir -p "$SSH_ID_DIR"
		ssh-keygen -N "" -f "$SSH_ID_FILE"
	else
		echolog "SSH ID Key exists, continue..."
	fi
}


get_ssh_id_fingerprint() {
  local FINGERPRINT="$(ssh-keygen -E md5 -lf "$SSH_ID_FILE" 2> /dev/null | awk '{print $2}' | sed 's/^MD5:\(.*\)$/\1/')"
  if [[ "$FINGERPRINT" == "" ]]; then
    FINGERPRINT="$(ssh-keygen -lf "$SSH_ID_FILE" | awk '{print $2}')"
  fi
  echo $FINGERPRINT
}
