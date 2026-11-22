include $(TOPDIR)/rules.mk

PKG_NAME:=ddns-scripts-dnspod-starsunyzl
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=starsunyzl

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=DNSPod DDNS provider (Tencent Cloud API 3.0)
  DEPENDS:=+ddns-scripts +curl +openssl-util +bind-host
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  DNSPod dynamic DNS provider for OpenWrt ddns-scripts.
  Supports IPv4, IPv6 and multiple records through Tencent Cloud API 3.0.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/ddns
	$(INSTALL_BIN) ./files/usr/lib/ddns/update_dnspod.sh $(1)/usr/lib/ddns/update_dnspod.sh
	$(INSTALL_DIR) $(1)/usr/share/ddns/custom
	$(INSTALL_DATA) ./files/usr/share/ddns/custom/dnspod.json $(1)/usr/share/ddns/custom/dnspod.json
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
