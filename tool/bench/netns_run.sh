#!/bin/bash
# usage: netns_run.sh <one-way-delay-ms | 0 | none> <label>
# Box-only benchmark: two processes in two network namespaces (veth).
# REPO=<checkout> runs another checkout; E2E_NATIVE_HASH=1 simulates the
# Android native-hash path (see test/e2e_native_hash.dart).
D=$1; L=$2
cd "${REPO:-/workspace/isekai-drop}"
export PATH=/home/box/tools/flutter/bin:$PATH
sudo -n ip netns del isekai-e2e 2>/dev/null
sudo -n ip link del ie2e-h 2>/dev/null
rm -rf /tmp/e2e /tmp/e2e-client; mkdir -p /tmp/e2e /tmp/e2e-client
sudo -n ip netns add isekai-e2e
sudo -n ip link add ie2e-h type veth peer name ie2e-p
sudo -n ip link set ie2e-p netns isekai-e2e
sudo -n ip addr add 10.77.0.1/24 dev ie2e-h
sudo -n ip link set ie2e-h up
sudo -n ip netns exec isekai-e2e ip addr add 10.77.0.2/24 dev ie2e-p
sudo -n ip netns exec isekai-e2e ip link set ie2e-p up
sudo -n ip netns exec isekai-e2e ip link set lo up
sudo -n ip netns exec isekai-e2e sudo -n -u box env HOME=/home/box PATH=/home/box/tools/flutter/bin:/usr/bin:/bin E2E_PEER=1 E2E_NATIVE_HASH=${E2E_NATIVE_HASH:-0} E2E_DIR=/tmp/e2e E2E_WAIT=600 E2E_EXPECT=to-peer.bin E2E_SEND_HOST=10.77.0.1 E2E_SEND_PORT=47830 E2E_SEND_FILE=/tmp/e2e-files/to-client.bin flutter test --no-pub test/e2e_peer_test.dart > /tmp/bench/peer-$L.log 2>&1 &
sleep 25
# <one-way-ms> = none: no proxy (direct over the veth pair).
if [ "$D" = none ]; then VIA=; PX=; else
python3 "$(dirname "$0")/delay_proxy.py" 10.77.0.1 47900 10.77.0.2 47820 ${D} & PX=$!
VIA=10.77.0.1:47900; fi
env E2E_CLIENT=1 E2E_MODE=classic ${VIA:+E2E_VIA=$VIA} E2E_DIR=/tmp/e2e-client E2E_PORT=47830 E2E_SEND_FILE=/tmp/e2e-files/to-peer.bin flutter test --no-pub test/e2e_client_test.dart > /tmp/bench/client-$L.log 2>&1
[ -n "$PX" ] && kill $PX; wait
grep -E "SPEED|SEND RESULT|RECEIVED|passed|failed" /tmp/bench/client-$L.log | sed 's/^.*Z //'
sudo -n ip netns del isekai-e2e
