SUMMARY = "Solidsense miscellaneous scripts"
DESCRIPTION = "Solidsense miscellaneous scripts"
LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = " \
    file://../gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263 \
"
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://bind9.init \
    file://gpl-2.0.txt \
    file://check_solidsense.sh \
    git://git@github.com/solidsense-connect/SolidSense-V1.git;protocol=ssh;branch=master;destsuffix=SolidSense-V1;name=SolidSense-V1 \
"
SRCREV_SolidSense-V1 = "2ca1c95ebec578d033e2e10e70030349369c49cf"
S-V1 = "${WORKDIR}/SolidSense-V1"

SYSTEMD_SERVICE_${PN} = "check_solidsense.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

inherit systemd

do_install () {
    install -d ${D}/opt/scripts
    install -d ${D}/opt/SolidSense/bin
    install -m 0755  -m 0755 ${WORKDIR}/check_solidsense.sh ${D}/opt/scripts/check_solidsense
    install -m 0755 ${S-V1}/scripts/restart.sh ${D}/opt/scripts/restart
    ln -s /opt/scripts/restart ${D}/opt/SolidSense/bin/restart

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${S-V1}/scripts/check_solidsense.service ${D}${systemd_unitdir}/system
    sed -i -e 's,@SBINDIR@,${sbindir},g' \
        -e 's,@SYSCONFDIR@,${sysconfdir},g' \
        ${D}${systemd_unitdir}/system/check_solidsense.service

    install -d ${D}/etc/init.d
    install -m 0755 ${WORKDIR}/bind9.init ${D}/etc/init.d/bind9

    ln -s /etc/solidsense ${D}/etc/solidsense_device

    install -d ${D}/etc/udev/rules.d
    install -m 0644 ${S-V1}/leds/udev/99-leds-permission.rules ${D}/etc/udev/rules.d
    install -m 0644 ${S-V1}/wifi/udev/99-power-save.rules ${D}/etc/udev/rules.d
}

FILES_${PN} = " \
    /etc/init.d/bind9 \
    /etc/udev/rules.d/99-leds-permission.rules \
    /etc/udev/rules.d/99-power-save.rules \
    /etc/solidsense_device \
    /opt/scripts/check_solidsense \
    /opt/scripts/restart \
    /opt/SolidSense/bin/restart \
"

COMPATIBLE_MACHINE = "solidsense|n6gq|n6gsdl|in6gq|in6gsdl|imx8mnc"
