#!/bin/sh
# Egress policy for the Hermes sandbox network (docker network "hermes-sbx", 172.30.0.0/24).
# Blocks private/link-local/CGNAT destinations (LAN, other containers, cloud metadata); internet stays open.
# Idempotent. Usage: hermes-sandbox-egress.sh start|stop
SUBNET=172.30.0.0/24
CHAIN=HERMES-SBX-EGRESS
case "$1" in
  start)
    iptables -N "$CHAIN" 2>/dev/null || iptables -F "$CHAIN"
    for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10; do
      iptables -A "$CHAIN" -d "$net" -j REJECT
    done
    iptables -A "$CHAIN" -j RETURN
    iptables -C DOCKER-USER -s "$SUBNET" -j "$CHAIN" 2>/dev/null || iptables -I DOCKER-USER 1 -s "$SUBNET" -j "$CHAIN"
    ;;
  stop)
    iptables -D DOCKER-USER -s "$SUBNET" -j "$CHAIN" 2>/dev/null
    iptables -F "$CHAIN" 2>/dev/null
    iptables -X "$CHAIN" 2>/dev/null
    ;;
  *) echo "usage: $0 start|stop" >&2; exit 2;;
esac
exit 0
