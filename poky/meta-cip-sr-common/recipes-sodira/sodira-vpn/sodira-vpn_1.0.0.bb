SUMMARY = "Sodira vpn"
DESCRIPTION = "openvpn configuration"
LICENSE = "MIT"
LIC_FILES_CHKSUM = " \
    file://../sodira_license.txt;md5=323581fce7a2f1705c6388b97ecc7c13 \ 
"

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://sodira_license.txt \
    file://sodira_vpn.service \
    file://start_vpn_config.sh \
"

SYSTEMD_SERVICE_${PN} = "sodira_vpn.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

inherit systemd

do_install () {
    install -d ${D}/etc/openvpn
    install -d ${D}/opt/scripts
    install -m 0755 ${WORKDIR}/start_vpn_config.sh ${D}/opt/scripts/start_vpn_config.sh

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/sodira_vpn.service ${D}${systemd_unitdir}/system

    ln -s /data/openvpn/client.conf ${D}/etc/openvpn/client.conf
}

FILES_${PN} = " \
  /etc  \
  /opt \
  /etc/openvpn \
  /opt/scripts \
"
