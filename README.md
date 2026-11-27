# ImmortalWrt for H3C Magic NX54（NSS 硬件卸载）

本仓库是 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)（master，Linux 6.18）的一个分支，
为 **H3C Magic NX54（VER.A）** 加入 **NSS 硬件卸载**支持：有线、2.4 GHz 和 5 GHz 都由 NSS 固件转发。

数据面不是 OpenWrt 常见的 `qca-ssdk` + `qca-nss-dp` 组合，而是采用
[`kuncy7/openwrt-nss-edma`](https://github.com/kuncy7/openwrt-nss-edma) 的路线：

- 有线：内核 `stmmac/dwmac-ipq5018` + **DSA `qca8k`**（QCA8337 交换机）
- NSS：通过 **claim API** 把 GMAC 的 DMA 交给 NSS 固件（`qca-dwmac-nss`、`nss-tools-dwmac`）
- Wi-Fi：ath11k 的 NSS wifili 卸载补丁（`qca-nss-drv` 14.0 + 12.x 固件）

## 状态

| 功能 | 状态 |
|---|---|
| 有线 LAN/WAN（QCA8337，1 Gbps） | ✅ 已验证 |
| 2.4 GHz（IPQ5018 内置，NSS 卸载） | ✅ 已验证 |
| 5 GHz（QCN9074 PCIe，NSS 卸载） | ✅ 已验证 |
| CPU 频率（1008 / 1296 MHz） | ✅ LuCI 可切换 |
| NSS ECM / VLAN / PPPoE / SQM | ✅ 已集成 |
| WAN 本地 VLAN（NSS 下载整形） | ✅ 自动配置（S18 + hotplug） |
| SSH / SFTP（Dropbear + OpenSSH SFTP subsystem） | ✅ 已集成 |
| LuCI 中文、Argon 主题、TurboACC、UPnP、DDNS | ✅ 已集成 |
| 长时间满负载稳定性 | ⚠️ 未进行稳定性验证 |

## 硬件

| 项 | 规格 |
|---|---|
| SoC | Qualcomm IPQ5018（2×Cortex-A53） |
| 内存 | 512 MB DDR3 |
| 闪存 | 128 MB SPI-NAND（实机 ESMT F50D1G41LB，ECC 4-bit） |
| 交换 | QCA8337（3×LAN + 1×WAN） |
| 5 GHz | QCN9074（PCIe，4×4） |
| 2.4 GHz | IPQ5018 内置 |

## 软件版本

| 组件 | 版本 |
|---|---|
| ImmortalWrt | master（基线 `6003f6b`），Linux 6.18 |
| `qca-nss-drv` | 14.0（QSDK） |
| `qca-nss-ecm` | 14.0 |
| `qca-nss-clients` | 12.5 |
| NSS 固件版本 | `12.2-156`（`NSS.FW.12.2-156-MP.R`，`NSS_FIRMWARE_VERSION_12_2`） |
| ath11k 内存档 | 1G profile（`ATH11K_MEM_PROFILE_1G`） |
| NSS 内存档 | MEDIUM |

> 12.2 固件是为规避 12.5-210 对部分 802.11ac 客户端的 payload buffer 泄漏；
> 切回 12.5 时 `qca-nss-drv` 必须按 12.5 重编（peer 统计布局不同）。

### 镜像包含的软件

除内核模块与共享库外，镜像内包含以下软件/工具（`apk add` 可再装其它包）：

**基础系统**

- `busybox`（提供 `sh`、`sed`、`awk`、`grep`、`vi`、`tar`、`nc`、`ifconfig` 等 applet）、`bash`
- `procd`、`ubus`、`uci`、`netifd`、`logd`、`rpcd`、`uhttpd`、`block-mount`、`fstools`、`mtd`、`ubi-utils`、`uboot-envtools`、`e2fsprogs`、`automount`、`cpufreq`、`usign`、`urngd`、`jsonfilter`、`jshn`、`resolveip`、`shellsync`、`getrandom`

**命令行工具**

- 文本/编辑：`vim`、`nano`、`less`、`jq`、`findutils`（`find`/`locate`/`xargs`）、`logrotate`
- 压缩/归档：`tar`（GNU）、`xz`、`xz-utils`、`zstd`、`unzip`、`bzip2`、`pv`
- 系统：`htop`、`procps-ng`、`screen`、`lsof`、`socat`、`rsync`、`flock`、`coreutils-timeout`
- 网络：`curl`、`wget-ssl`、`uclient-fetch`、`openssl-util`、`ca-bundle`、`mtr-nojson`、`ethtool`、`ip-full`、`ip-bridge`、`tc-full`、`iw`

**网络服务**

- `dnsmasq-full`、`odhcpd-ipv6only`、`odhcp6c`、`firewall4`、`nftables-json`、`ppp`、`ppp-mod-pppoe`、`dropbear`
- `wpad-openssl`、`hostapd-common`、`wifi-scripts`、`wireless-regdb`
- SSH：`dropbear`；SFTP 子系统：`openssh-sftp-server`（不安装完整 `openssh-server`）
- `miniupnpd-nftables`、`ddns-scripts`、`ddns-scripts-services`、`ddns-scripts-dnspod-starsunyzl`、`bind-host`（提供 `host` DNS 查询工具，支持 DDNS Glue Record 检测及 DNS over TCP）

**NSS 相关**

- `nss-firmware`、`nss-firmware-ipq50xx`、`nss-tools-dwmac`、`nssinfo`、`sqm-scripts`、`sqm-scripts-nss`
- 内核侧：`kmod-qca-nss-drv`、`kmod-qca-nss-ecm`、`kmod-qca-dwmac-nss`、`kmod-qca-dsa-nss` 等

**LuCI / 界面**

- `luci`（含 `luci-base`、`luci-mod-*`）、`luci-app-firewall`、`luci-app-package-manager`、`luci-app-sqm`、`luci-app-turboacc`、`luci-app-upnp`、`luci-app-ddns`
- `luci-theme-argon`、`luci-theme-bootstrap`、`luci-compat`

**固件与工具**

- `ath11k-firmware-ipq5018-qcn6122`、`ath11k-firmware-qcn9074`、`ipq-wifi-h3c_magic-nx54`
- `dumpimage`、`apk-openssl`、`openwrt-keyring`

> 这些工具会增大只读 rootfs，相应压缩 overlay (rootfs_data) 空间。
> 当前镜像刷入后 overlay 可用约 12 MB（以设备上 df -h /overlay 为准）。

## 动态 DNS（DDNS）

固件预装完整的 LuCI DDNS 基础组件：

- `luci-app-ddns` 与简体中文界面：在 **网络 → 动态 DNS** 中管理服务。
- `ddns-scripts`、`ddns-scripts-services`：提供 IPv4/IPv6 动态地址检测、常见 DDNS 服务商定义、更新与日志功能。
- `ddns-scripts-dnspod-starsunyzl`：集成 [starsunyzl/ddns-scripts-dnspod](https://github.com/starsunyzl/ddns-scripts-dnspod)，使用腾讯云 API 3.0 更新 DNSPod 记录，支持 IPv4、IPv6 和多条同类型记录。
- `bind-host`：提供 BIND 的 `host` 查询命令，启用 Glue Record 检测及强制 DNS over TCP 等需要 BIND host 的功能。
- `curl`、`wget-ssl`、`ca-bundle`：为服务商 API、HTTPS 更新和证书验证提供基础支持。

进入 **网络 → 动态 DNS**，新增服务并选择 `dnspod`，分别配置 IPv4/IPv6 服务。`Username` 填腾讯云 API `SecretId`，`Password` 填 `SecretKey`；`Domain` 填 `主机记录@主域名`（例如 `www@example.com`，根域名可填 `@example.com`）；`Lookup Hostname` 填用于检测的完整域名。一个主机记录存在多条同类型记录时，在 `Optional Encoded Parameter` 中填写对应 `RecordId`；留空时插件仅在匹配到唯一记录时自动选择。腾讯云 API 3.0 要求设备系统时间与标准时间误差不超过 5 分钟。需要 Glue Record 检测或 DNS over TCP 时，由预装的 `bind-host` 提供支持。

## SSH / SFTP 文件传输

固件使用 **Dropbear** 提供 SSH 服务，并通过独立的 `openssh-sftp-server` 提供 SFTP 子系统。
Dropbear 的 `CONFIG_DROPBEAR_SFTPSERVER` 已启用；构建配置同时选中
`CONFIG_PACKAGE_openssh-sftp-server`，安装路径为 `/usr/libexec/sftp-server`。
不安装完整的 `openssh-server`，也不改变现有 Dropbear 服务、SSH 端口或认证配置。

连接参数：

| 项目 | 设置 |
|---|---|
| 协议 | SFTP（不是 FTP，也不是 SCP） |
| 主机 | 路由器 LAN 地址（默认 `192.168.1.1`） |
| 端口 | `22` |
| 用户名 | `root` |
| 认证 | 使用现有 SSH 密码或公钥认证 |

在 WinSCP、FileZilla 或其他客户端中选择 **SFTP** 协议，填写上述主机、端口和 SSH 凭据即可。
首次启动时 root 默认无密码；需要密码登录时，先通过本机控制台或现有管理入口执行
`passwd` 设置密码。若使用公钥认证，沿用 Dropbear 的
`/etc/dropbear/authorized_keys`。

## 构建

```sh
# 依赖（Ubuntu/Debian）
sudo apt-get install -y build-essential clang flex bison g++ gawk gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync swig unzip \
  zlib1g-dev file wget cpio bc time perl

# feeds（feeds.conf.default 里已包含 kuncy7/nss-packages;ipq50xx-rebase）
./scripts/feeds update -a
./scripts/feeds install -a

# 应用 feed 侧补丁（SQM 的 nss-edma 联动）
./scripts/apply-feed-patches.sh

# 使用仓库内的完整配置
cp .github/ci/nx54.config .config
make defconfig
make -j$(nproc)
```

产物在 `bin/targets/qualcommax/ipq50xx/`：

- `…-squashfs-factory-nx54.bin`：H3C 原厂网页升级用
- `…-squashfs-factory.ubi`：从 factory 镜像抽出的 UBI，`ubiformat` / 救援页使用
- `…-squashfs-sysupgrade.bin`：已是 OpenWrt 时升级用
- `…-squashfs-initramfs-uImage.itb`：可选，U-Boot 下临时启动

## CI

推送到 `master` 触发 `.github/workflows/build.yml`：安装依赖 → feeds → 应用 feed 补丁 →
使用 `.github/ci/nx54.config` 构建 → 上传 `factory` / `sysupgrade` / `.ubi` / `.itb` /
manifest / sha256 到 artifact `nx54-image`。

打 tag 时会用 `gh release create` 自动发布 release。

## 刷机

### 从 H3C 原厂固件

在原厂后台「系统升级」上传 `…-factory-nx54.bin`。刷机前建议先确认能进入原厂恢复模式并备份
ART、原厂分区（原厂 U-Boot 不会被替换）。

### 从已有的 OpenWrt

```sh
sysupgrade -n /tmp/…-sysupgrade.bin
```

从旧版本/旧 overlay 升级时务必加 `-n`，否则旧的 `wireless`/`network` 配置会带过来，
可能出现 5G 不启用、MAC 不对等问题。

### 恢复

- 原厂 U-Boot 未改动，可用串口 + `nand` 命令写回备份分区
- 需要网页救砖的，可另刷 [FlyFish-go/IPQ50XX-Uboot](https://github.com/FlyFish-go/IPQ50XX-Uboot)

## 首次启动

- 管理地址：<http://192.168.1.1>，用户名 `root`，无密码
- Wi-Fi：默认 SSID `ImmortalWrt`，无加密
- 5G 默认 `ch36 / HE80`；160 MHz 需要 DFS 信道，未配 `country`/DFS 时 hostapd 会拒绝启用 AP（见「注意事项」）

### MAC 地址规则

从原厂环境分区 `ethaddr` 派生：

| 接口 | 规则 | 示例 |
|---|---|---|
| WAN / 标签 | `ethaddr` | `00:11:22:33:44:55` |
| LAN / eth1 | `+1` | `…56` |
| 2.4G | `+2` | `…57` |
| 5G | `+3` | `…58` |

## 注意事项

- **NSS 与软件加速互斥**：NSS 开启时，软件流量分载、硬件/Shortcut-FE 流卸载、全锥形 NAT
  （含 IPv6）会被强制关闭并在 TurboACC 页面隐藏。要使用 fullcone 需先关闭 NSS。
- **NSS 开启时 SQM 的队列脚本固定为 `nss-edma.qos`**：Qdisc 仍选真实 qdisc（`cake`、`fq_codel` 等）；
  `nss-edma.qos` 会忽略 Qdisc 字段，自行安装 `nsstbl`/`nssprio` + `nssfq_codel`。不要选/输入
  `nss-edma` 作为 qdisc。切换 NSS 开关会自动改写 SQM 脚本并重载，无需手动进 SQM 页面。
- **DFS / 160 MHz**：默认 5G 为 `ch36 / HE80`（非 DFS）。160 MHz 必然覆盖 52–64 的 DFS 段；
  当前默认未设置 `country`，`ieee80211h` 不会写进 hostapd，DFS 信道不可用。要开 160 MHz
  需设置 `wireless.radio1.country`（如 `CN`），并接受 CAC（普通 60s、气象 600s，检测到雷达
  退避 30 分钟）；只设 `ch56 + HE160` 而不配 country/DFS 时 hostapd 会拒绝启用 AP。
- **NSS 固件**：12.x 固件不可替换成非 IPQ50xx 平台的 14.x；`qca-nss-drv` 必须与固件版本匹配。
- **CPU 频率**：默认 `schedutil` 在额定 1008 MHz 与 1296 MHz boost 之间自动升降；
  可在 **System → CPU Freq** 里设置 governor、最小/最大频率。1296 MHz 是超出额定的 boost 档，
  散热不佳或追求绝对稳定时，把最大频率固定为 `1008000` 即可。

## WAN 本地 VLAN（NSS 下载整形）

NX54 的 WAN 是独立的 gmac0，没有交换机 conduit。`nss-edma.qos` 做下载整形时，
IFB 回注的包需要一个 VLAN 节点才能重新进入固件加速路径；因此在 **WAN 上套一层本地 VLAN**：

- `br-wan`（`vlan_filtering=1`，`wan` 作为 untagged 口，PVID 35）+ `br-wan.35`；
- `network.wan.device` 与 `network.wan6.device` 都指向 `br-wan.35`；`wan`/`wan6` 只是同一
  VLAN 设备上的 IPv4/IPv6 逻辑接口，**不是桥端口**，不会出现在 `bridge vlan show` 的端口列表里；
- **线上仍是 untagged**：桥内部打 tag、出方向剥 tag，MTU 和 ISP 侧不变；
- 建桥时设 `vlan_default_pvid=0`，并删除 `wan`/`br-wan` 上的 VLAN 1；最终只保留 VID 35：
  `wan 35 PVID Egress Untagged`、`br-wan 35`（self，tagged）。self VID 在 `br-wan.35`
  创建之后添加，避免 `ip link add ... type vlan` 因 VID 已存在而失败；
- 自 2026-11-25 起，`br-wan` **不由 netifd 拥有**，由脚本用 `ip`/`bridge` 在 netifd 启动前创建（`S18nx54-wan-vlan`），
  netifd 只把 `br-wan.35` 当外部设备使用；清理只需 `ip link del br-wan`；
- 启动时 `wan` 未就绪不会阻塞，`hotplug.d/net` 的 `add wan` 会补建；
- 有线 ↔ Wi-Fi 中继/WISP 切换由 `hotplug.d/iface` 自动处理：切中继删桥释放 WAN 口，切回有线重建；
- 修改 VID 可用 `uci set nss.general.wan_vlan_id=35`（默认 35，范围 1–4094）；
- 依赖 `ip-bridge` 包（提供 `/usr/sbin/bridge`），已在 `nss-tools-dwmac` 的 `DEPENDS` 中。

> 这层 VLAN 只对 NSS 下载整形有意义；不用 SQM/只做上传整形时也可保留，不影响正常上网。
> NSS 关闭（`nss.general.enabled=0`）时 S18 会把它拆掉、WAN 回到裸 `wan`；重新开启并重启后自动恢复。

## 目录

| 路径 | 内容 |
|---|---|
| `target/linux/qualcommax/patches-6.18/` | stmmac claim API、DSA qca8k、ECM、qdisc、ECC、CPU 提频等内核补丁 |
| `target/linux/qualcommax/dts/` | NX54 板级 DTS、QCN6122/WCSS、NSS DTSI |
| `target/linux/qualcommax/ipq50xx/base-files/` | MAC/caldata/network/upgrade 脚本 |
| `package/kernel/mac80211/` | ath11k NSS/WiFi 补丁集 |
| `package/nss/`、`package/kernel/qca-*` | NSS 工具（nss-tools/nssinfo）、WAN VLAN 脚本（`nx54-wan-vlan*`）与 stmmac claim / DSA qca8k 胶水 |
| `package/luci-app-turboacc/` | NSS 开关与加速设置（含互斥逻辑） |
| `feed-patches/` | feeds 侧补丁（SQM nss-edma 联动） |
| `.github/ci/nx54.config` | CI 使用的完整配置 |

## 致谢

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) / [OpenWrt](https://openwrt.org)
- [kuncy7/openwrt-nss-edma](https://github.com/kuncy7/openwrt-nss-edma) 与
  [kuncy7/nss-packages](https://github.com/kuncy7/nss-packages)（NSS-EDMA 路线）
- [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq)（ath11k NSS 原厂实现）
- [FlyFish-go/IPQ50XX-Uboot](https://github.com/FlyFish-go/IPQ50XX-Uboot)（可选 U-Boot）

## 许可

与上游一致：GPL-2.0（内核/补丁）与各包自身的许可证。NSS 固件、ath11k 固件等闭源组件
按各自许可分发。
