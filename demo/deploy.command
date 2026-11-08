#!/bin/bash
# Double-click this file to deploy the buffer-overflow demo onto the
# Kali VM. You will be asked for the Kali password ONCE.
#
#   Target VM : kamal@192.168.64.12
#   Target dir: /home/kamal/workspace/exploits-turotial

HOST="kamal@192.168.64.12"
DIR="/home/kamal/workspace/exploits-turotial"
SRC="/Users/kamal/kamal-Drive/Github/tum-slides/demo/setup.sh"
CP="/tmp/km_ctl_$$"
OPTS="-o ControlMaster=auto -o ControlPath=$CP -o ControlPersist=120 -o StrictHostKeyChecking=accept-new"

echo "=== Deploying overflow demo to $HOST:$DIR ==="
echo "You'll be asked for the Kali password once."
echo

if ! ssh $OPTS "$HOST" "mkdir -p '$DIR'"; then
    echo
    echo "!! Could not connect to $HOST. Is the Kali VM running and reachable?"
    echo "Press Return to close."; read _; exit 1
fi

scp -o ControlPath="$CP" "$SRC" "$HOST:$DIR/" || { echo "scp failed"; read _; exit 1; }

echo
echo "=== Running setup on the VM ==="
ssh -o ControlPath="$CP" "$HOST" "cd '$DIR' && sh setup.sh"

# close the shared connection
ssh -O exit -o ControlPath="$CP" "$HOST" 2>/dev/null

echo
echo "=== Done. The demo lives in $DIR on the VM. ==="
echo "To run it again:  ssh $HOST  then  cd $DIR && ./exploit.sh"
echo
echo "Press Return to close this window."
read _
