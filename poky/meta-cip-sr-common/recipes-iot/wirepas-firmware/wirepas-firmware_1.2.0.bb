SUMMARY = "Wirepas Firmware utils"
DESCRIPTION = "Wirepas utils needed to flash firmware"
LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = " \
    file://../gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263 \
"
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI = " \
   file://gpl-2.0.txt \
   file://flash.sh \
   file://flash_nordic.sh \
   file://nordic1.cfg \
   file://nordic2.cfg \
"

RDEPENDS_${PN} = " \
    bash \
    openocd \
"

do_install () {
    install -d ${D}/opt/scripts

    install -m 0700 ${WORKDIR}/flash.sh ${D}/opt/scripts/flash
    install -m 0700 ${WORKDIR}/flash_nordic.sh ${D}/opt/scripts/flash_nordic
    install -m 0600 ${WORKDIR}/nordic1.cfg ${D}/opt/scripts/nordic1.cfg
    install -m 0600 ${WORKDIR}/nordic2.cfg ${D}/opt/scripts/nordic2.cfg
}

FILES_${PN} = " \
  /opt/scripts/nordic2.cfg \
  /opt/scripts/nordic1.cfg \
  /opt/scripts/flash \
  /opt/scripts/flash_nordic \
"
