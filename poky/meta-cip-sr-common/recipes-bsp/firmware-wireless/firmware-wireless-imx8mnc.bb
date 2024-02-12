SUMMARY = "Wireless Firmware required by SolidRun MX8 based SOMs"
DESCRIPTION = "Provides firmware required by wireless hardware on \
SolidRun i.MX8 based SOMs."
LICENSE = "CLOSED"

SRC_URI = " \
    git://github.com/SolidRun/imx8mp_build.git;protocol=https;branch=imx8mn \
    git://git@github.com/solidsense-connect/SolidSense-V1.git;protocol=ssh;branch=master;destsuffix=SolidSense-V1;name=SolidSense-V1 \
"
SRCREV = "3161945e5524b5901035ddd9e1d4a3429d5d4403"
SRCREV_SolidSense-V1 = "2ca1c95ebec578d033e2e10e70030349369c49cf"
S-V1 = "${WORKDIR}/SolidSense-V1"

SYSTEMD_SERVICE_${PN} = "ble1.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

inherit systemd

S = "${WORKDIR}/git"
FIRMWARE_LIB_SRC = "${S}/patches/overlay/usr/lib/firmware/brcm"
FIRMWARE_ETC_SRC = "${S}/patches/overlay/etc/firmware"

do_install () {
    install -d ${D}${base_libdir}/firmware/brcm 
    install -m 0644 ${FIRMWARE_LIB_SRC}/brcmfmac43455-sdio.bin ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.bin
    install -m 0644 ${FIRMWARE_LIB_SRC}/brcmfmac43455-sdio.clm_blob ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.clm_blob
    install -m 0644 ${FIRMWARE_LIB_SRC}/brcmfmac43455-sdio.txt ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.txt
    install -m 0644 ${FIRMWARE_LIB_SRC}/BCM4345C0.hcd ${D}${base_libdir}/firmware/brcm/BCM4345C0.hcd

    install -d ${D}${sysconfdir}/firmware
    install -d ${D}${sysconfdir}/firmware/murata-master
    install -m 0644 ${FIRMWARE_ETC_SRC}/BCM4345C0.1MW.hcd ${D}${sysconfdir}/firmware/BCM4345C0.1MW.hcd
    install -m 0644 ${FIRMWARE_ETC_SRC}/BCM4345C0_003.001.025.0144.0266.1MW.hcd ${D}${sysconfdir}/firmware/BCM4345C0_003.001.025.0144.0266.1MW.hcd
    install -m 0644 ${FIRMWARE_ETC_SRC}/CYW4345C0.1MW.hcd ${D}${sysconfdir}/firmware/CYW4345C0.1MW.hcd
    install -m 0644 ${FIRMWARE_ETC_SRC}/murata-master/_BCM4345C0.1MW.hcd ${D}${sysconfdir}/firmware/murata-master/_BCM4345C0.1MW.hcd

    # install systemd service file
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${S-V1}/BLE/systemd/ble1.service.imx8mnc ${D}${systemd_unitdir}/system/ble1.service
    sed -i -e 's,@SBINDIR@,${sbindir},g' \
        -e 's,@SYSCONFDIR@,${sysconfdir},g' \
        ${D}${systemd_unitdir}/system/ble1.service
}

FILES_${PN} = " \
    ${base_libdir}/firmware/brcm/* \
    ${sysconfdir}/firmware/* \
"

COMPATIBLE_MACHINE = "imx8mnc"
