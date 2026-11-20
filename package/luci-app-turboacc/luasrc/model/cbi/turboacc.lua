local kernel_version = luci.sys.exec("echo -n $(uname -r)")

m = Map("turboacc")
m.title	= translate("Turbo ACC Acceleration Settings")
m.description = translate("Opensource Flow Offloading driver (Fast Path or Hardware NAT)")

m:append(Template("turboacc/turboacc_status"))

s = m:section(TypedSection, "turboacc", "")
s.addremove = false
s.anonymous = true

-- NSS hardware offload: the new ipq50xx stack is driven by the 'nss'
-- service and the nss.general uci flags, not by a kernel module here.
if nixio.fs.access("/etc/init.d/nss") then
nss_enabled = s:option(Flag, "nss_enabled", translate("NSS 硬件卸载"))
nss_enabled.default = 1
nss_enabled.description = translate("使用 NSS 数据面卸载（有线 + Wi-Fi）。开启后会强制关闭：软件流量分载（Software flow offloading）、硬件/Shortcut-FE 流卸载、全锥形 NAT（含 IPv6），这些选项在本页不可选；SQM 的队列脚本与 Qdisc 只能选 nss-edma。修改后需重启生效。")
end

-- nftables: nft_flow_offload is built-in mod
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/nft_flow_offload.ko") then
sw_flow = s:option(Flag, "sw_flow", translate("Software flow offloading"))
sw_flow.default = 0
sw_flow.description = translate("Software based offloading for routing/NAT")
sw_flow:depends("sfe_flow", 0)
sw_flow:depends("nss_enabled", 0)
end

if luci.sys.call("cat /etc/openwrt_release | grep -Eq 'filogic|mt762' ") == 0 then
hw_flow = s:option(Flag, "hw_flow", translate("Hardware flow offloading"))
hw_flow.default = 0
hw_flow.description = translate("Requires hardware NAT support, implemented at least for mt762x")
hw_flow:depends("sw_flow", 1)
hw_flow:depends("nss_enabled", 0)
end

if luci.sys.call("cat /etc/openwrt_release | grep -Eq 'mediatek' ") == 0 then
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/mt7915e.ko") then
hw_wed = s:option(Flag, "hw_wed", translate("MTK WED WO offloading"))
hw_wed.default = 0
hw_wed.description = translate("Requires hardware support, implemented at least for Filogic 8x0")
hw_wed:depends("hw_flow", 1)
end
end

if nixio.fs.access("/lib/modules/" .. kernel_version .. "/shortcut-fe-cm.ko")
or nixio.fs.access("/lib/modules/" .. kernel_version .. "/fast-classifier.ko")
then
sfe_flow = s:option(Flag, "sfe_flow", translate("Shortcut-FE flow offloading"))
sfe_flow.default = 0
sfe_flow.description = translate("Shortcut-FE based offloading for routing/NAT")
sfe_flow:depends("sw_flow", 0)
sfe_flow:depends("nss_enabled", 0)
end

-- nftables
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/nft_fullcone.ko") then
fullcone_nat = s:option(Flag, "fullcone_nat", translate("FullCone NAT"))
fullcone_nat.default = 0
fullcone_nat.description = translate("Using FullCone NAT can improve gaming performance effectively")
fullcone_nat:depends("nss_enabled", 0)
fullcone6 = s:option(Flag, "fullcone6", translate("IPv6 Full Cone NAT"))
fullcone6.default = 0
fullcone6.description = translate("Enabling IPv6 Full Cone NAT adds an extra layer of NAT to IPv6. In IPv6, if you obtain an IPv6 prefix through IPv6 Prefix Delegation, each device can be assigned a public IPv6 address, eliminating the need for IPv6 Full Cone NAT.")
fullcone6:depends("fullcone_nat", 1)
fullcone6:depends("nss_enabled", 0)
end

if nixio.fs.access("/lib/modules/" .. kernel_version .. "/tcp_bbr.ko") then
bbr_cca = s:option(Flag, "bbr_cca", translate("BBR CCA"))
bbr_cca.default = 0
bbr_cca.description = translate("Using BBR CCA can improve TCP network performance effectively")
end

return m
