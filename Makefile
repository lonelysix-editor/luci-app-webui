include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-webui
PKG_RELEASE:=1

LUCI_TITLE:=Modem Manager WebUI for RM502Q-AE
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc +jq +coreutils-timeout
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
