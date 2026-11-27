#!/bin/sh
# Shared helpers for the NX54 WAN-VLAN scripts.  The VLAN id lives in
# nss.general.wan_vlan_id so the helper, the boot cleanup and the two hotplug
# handlers cannot drift apart; default stays 35.

nx54_vid() {
	local v
	v=$(uci -q get nss.general.wan_vlan_id) || v=""
	case "$v" in
	''|*[!0-9]*) v=35 ;;
	esac
	[ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 4094 ] 2>/dev/null || v=35
	echo "$v"
}

# WAN interface section: prefer "wan", otherwise the first section that
# looks like a WAN (same rule autoconf uses), so a renamed section still
# works for S18 and the hotplugs.
nx54_wan_section() {
	local s
	if [ -n "$(uci -q get network.wan.proto)" ]; then
		echo wan
		return 0
	fi
	for s in $(uci -q show network 2>/dev/null | sed -n "s/^network\.\([^.]*\)\.proto='[^']*'$/\1/p"); do
		[ "$s" = loopback ] && continue
		case "$(uci -q get "network.$s.proto")" in
		none|static|dhcp|pppoe|ppp|dslite|map) echo "$s"; return 0 ;;
		esac
	done
	uci -q get network.wan >/dev/null && { echo wan; return 0; }
	return 1
}

# Companion IPv6 section (config_generate names it "<sec>6").  On DHCP/static
# WAN it is created with an explicit device=<wan>, so moving wan's device is
# not enough: without this, IPv6 keeps running on the bare gmac0 (and SQM only
# ever sees the IPv4 side on br-wan.<vid>).
nx54_wan6_section() {
	local sec=$1
	[ -n "$(uci -q get "network.${sec}6")" ] && { echo "${sec}6"; return 0; }
	return 1
}

# Device the WAN L3 currently runs on (empty when there is no WAN section).
nx54_wan_device() {
	local sec dev
	sec=$(nx54_wan_section) || sec=wan
	dev=$(uci -q get "network.$sec.device") || dev=""
	[ -n "$dev" ] || { dev=$(uci -q get "network.$sec.ifname"); dev=${dev:-}; }
	echo "$dev"
}

# PID-based lock directory: a killed process must not block the next boot /
# hotplug for a fixed grace period.  A live PID means the owner is still
# running; a dead one means the lock is stale and is removed immediately.
nx54_lock_take() {
	local dir="/var/run/$1" pid start cur
	if ! mkdir "$dir" 2>/dev/null; then
		read -r pid start < "$dir/pid" 2>/dev/null
		if [ -z "$pid" ]; then
			# Owner may be between mkdir and writing its pid; give it a
			# moment and re-read before declaring the lock stale.
			sleep 1
			read -r pid start < "$dir/pid" 2>/dev/null
		fi
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			# Same PID can be reused by an unrelated process after a
			# SIGKILL; compare the kernel start time to be sure.
			cur=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)
			[ -n "$cur" ] && [ "$cur" = "$start" ] && return 1
		fi
		rm -rf "$dir"
		mkdir "$dir" 2>/dev/null || return 1
	fi
	start=$(awk '{print $22}' "/proc/$$/stat" 2>/dev/null)
	echo "$$ ${start:-0}" > "$dir/pid"
	return 0
}

nx54_lock_drop() {
	rm -rf "/var/run/$1"
}

# Name of the VLAN L3 device.
nx54_wdev() {
	echo "br-wan.$(nx54_vid)"
}


# Create br-wan (vlan_filtering, wan as untagged PVID port) and br-wan.<vid>.
# Idempotent.  netifd does not own any of this; it only sees br-wan.<vid>.
nx54_bridge_up() {
	local vid wdev
	vid=$(nx54_vid)
	wdev="br-wan.$vid"
	command -v bridge >/dev/null 2>&1 || return 1
	[ -e /sys/class/net/wan ] || return 1

	if [ ! -e /sys/class/net/br-wan ]; then
		ip link add name br-wan type bridge vlan_filtering 1 \
			vlan_default_pvid 0 || return 1
	else
		# A bridge left over from an older boot may predate vlan_filtering.
		ip link set br-wan type bridge vlan_filtering 1 \
			vlan_default_pvid 0 2>/dev/null
	fi
	ip link set wan master br-wan 2>/dev/null
	# Drop the kernel's automatic VLAN 1; only the WAN VID may exist.
	bridge vlan del dev wan vid 1 2>/dev/null
	bridge vlan add dev wan vid "$vid" pvid untagged 2>/dev/null
	# Keep VLAN 1 out of the bridge's own table too.  The self entry for
	# the WAN VID is added *after* br-wan.<vid> exists: creating the VLAN
	# device already registers the VID on the bridge and adding it earlier
	# can make the ip link add fail with EEXIST.
	bridge vlan del dev br-wan vid 1 self 2>/dev/null
	if [ ! -e "/sys/class/net/$wdev" ]; then
		ip link add link br-wan name "$wdev" type vlan id "$vid" || {
			nx54_bridge_down
			return 1
		}
	fi
	bridge vlan add dev br-wan vid "$vid" self 2>/dev/null
	# If this was a pre-existing bridge, setting vlan_default_pvid=0 may
	# have failed while VLAN 1 was still the PVID.  Now that VID <vid> is
	# the port PVID, drop VLAN 1 again so only the WAN VID remains.
	bridge vlan del dev wan vid 1 2>/dev/null
	bridge vlan del dev br-wan vid 1 self 2>/dev/null
	ip link set br-wan up 2>/dev/null
	ip link set "$wdev" up 2>/dev/null

	# Verify what the kernel accepted: a silently rejected PVID or a missing
	# VLAN device would leave the WAN on a bridge that cannot pass traffic.
	if [ ! -e "/sys/class/net/$wdev" ]; then
		nx54_bridge_down
		return 1
	fi
	if ! bridge vlan show dev wan 2>/dev/null |
		awk -v v="$vid" '{for (i = 1; i <= NF; i++) if ($i == v) { ok = 1 }} END { exit !ok }'; then
		# A silently rejected PVID would leave wan enslaved with no L3;
		# undo the partial bridge so the caller can keep bare wan.
		nx54_bridge_down
		return 1
	fi
	if ! bridge vlan show dev br-wan 2>/dev/null |
		awk -v v="$vid" '{for (i = 1; i <= NF; i++) if ($i == v) { ok = 1 }} END { exit !ok }'; then
		# Without the self entry locally-terminated VID 35 traffic is not
		# delivered to br-wan.<vid>; fall back rather than break the WAN.
		nx54_bridge_down
		return 1
	fi
	# Marker: the bridge is expected to exist.  The netdev-remove handler
	# uses it to distinguish an external removal (recreate) from our own
	# intentional teardown (ignore), with no timing heuristic involved.
	: > /var/run/nx54-wan-vlan.expected
	return 0
}

nx54_bridge_down() {
	rm -f /var/run/nx54-wan-vlan.expected
	ip link set wan nomaster 2>/dev/null
	ip link del br-wan 2>/dev/null
	return 0
}

