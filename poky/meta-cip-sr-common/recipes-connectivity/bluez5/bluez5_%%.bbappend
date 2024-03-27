# Add main.conf configuration file

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += " \
    ${@bb.utils.contains('PACKAGECONFIG', 'kura', '', 'file://dbus-bluetooth.conf', d)} \
    file://main.conf \
"

do_install_append () {
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
    if [ -n "${@bb.utils.contains('PACKAGECONFIG', 'kura', '', '', d)}" ]; then
        install -m 0644 ${WORKDIR}/dbus-bluetooth.conf ${D}${sysconfdir}/dbus-1/systemd/bluetooth.conf
    fi
}

FILES_${PN} += " \
    /etc/bluetooth/main.conf \
"
