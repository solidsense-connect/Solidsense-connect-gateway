SUMMARY = "Wireless Firmware required by SolidRun MX8 based SOMs"
DESCRIPTION = "Provides firmware required by wireless hardware on \
SolidRun i.MX8 based SOMs."
LICENSE = "CLOSED"

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://BCM4345C0.hcd \
    file://brcmfmac43455-sdio.bin \
    file://brcmfmac43455-sdio.clm_blob \
    file://brcmfmac43455-sdio.fsl,imx8mn-solidrun.txt \
    file://brcmfmac43455-sdio.txt \
    git://git@github.com/solidsense-connect/SolidSense-V1.git;protocol=ssh;branch=master;destsuffix=SolidSense-V1;name=SolidSense-V1 \
"
SRCREV_SolidSense-V1 = "2ca1c95ebec578d033e2e10e70030349369c49cf"
S-V1 = "${WORKDIR}/SolidSense-V1"

SYSTEMD_SERVICE_${PN} = "ble1.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

inherit systemd

do_install () {
    install -d ${D}${base_libdir}/firmware/brcm 
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.bin ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.bin
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.clm_blob ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.clm_blob
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.fsl,imx8mn-solidrun.txt ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.fsl,imx8mn-solidrun.txt
    install -m 0644 ${WORKDIR}/brcmfmac43455-sdio.txt ${D}${base_libdir}/firmware/brcm/brcmfmac43455-sdio.txt
    install -m 0644 ${WORKDIR}/BCM4345C0.hcd ${D}${base_libdir}/firmware/brcm/BCM4345C0.hcd

    # install systemd service file
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${S-V1}/BLE/systemd/ble1.service.imx8mnc ${D}${systemd_unitdir}/system/ble1.service
    sed -i -e 's,@SBINDIR@,${sbindir},g' \
        -e 's,@SYSCONFDIR@,${sysconfdir},g' \
        ${D}${systemd_unitdir}/system/ble1.service
}

FILES_${PN} = " \
    ${base_libdir}/firmware/brcm/* \
"

COMPATIBLE_MACHINE = "imx8mnc"
