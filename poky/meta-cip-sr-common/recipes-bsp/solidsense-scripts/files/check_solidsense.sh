#!/bin/sh

rpmb_device="/dev/mmcblk2rpmb"
mmc_output="$(/usr/bin/mmc rpmb read-block ${rpmb_device} 0x0 1 - | sed 's/,/ /g' | tr -s '\0' '\n')"
solidsense_file="/etc/solidsense"
hosts_file="/etc/hosts"
tmp_hosts_file="/tmp/hosts"
hostname_file="/etc/hostname"
kernel_hostname_file="/proc/sys/kernel/hostname"
redo_check_etc_solidsense=0
prog="$(basename "${0}")"
log_it="/usr/bin/logger -i --stderr --tag ${prog}"

create_etc_solidsense () {
	${log_it} "Creating ${solidsense_file}"
	for entry in ${mmc_output}
	do
		echo "${entry}" | grep -q '='
		is_valid="$?"
		if [ ${is_valid} -eq 1 ]
		then
			${log_it} "Error: Invalid RPMB entry <${entry}>."
		else
			echo "${entry}" >> ${solidsense_file}
		fi
	done
}

check_etc_solidsense () {
	${log_it} "Checking ${solidsense_file}"
	# shellcheck source=/dev/null
	. ${solidsense_file}
	for entry in ${mmc_output}
	do
		rpmb_key=${entry%=*}
		rpmb_val=${entry#*=}
		existing_key_value=$(eval "echo \$${rpmb_key}")
		if [ "${rpmb_val}" != "${existing_key_value}" ]
		then
			${log_it} "${solidsense_file} check: Values for ${rpmb_key} do not equal: ${rpmb_val} != ${existing_key_value}"
			redo_check_etc_solidsense=1
			${log_it} "Recreating ${solidsense_file}"
		fi
	done
}

check_etc_hosts () {
	${log_it} "Checking ${hosts_file}"
	if [ -f ${hosts_file} ]
	then
		${log_it} "${hosts_file} exists"
		if ! /bin/grep -q "${SERIAL}" ${hosts_file}
		then
			${log_it} "Updating ${hosts_file}"
			/bin/sed "s/127.0.1.1.*/127.0.1.1	${SERIAL}.localdomain		${SERIAL}/" < ${hosts_file} > ${tmp_hosts_file}
			/bin/mv ${tmp_hosts_file} ${hosts_file}
		fi
	fi
}

check_etc_hostname () {
	${log_it} "Checking ${hostname_file}"
	if [ -f ${hostname_file} ]
	then
		${log_it} "${hostname_file} exists"
		if ! /bin/grep -q "${SERIAL}" ${hostname_file}
		then
			${log_it} "Updating ${hostname_file}"
			/bin/echo "${SERIAL}" > ${hostname_file}
		fi
	else
		${log_it} "${hostname_file} does not exist"
		${log_it} "Creating ${hostname_file}"
		/bin/echo "${SERIAL}" > ${hostname_file}
	fi

	${log_it} "Checking ${kernel_hostname_file}"
	kernel_hostname=$(cat ${kernel_hostname_file})
	if [ "${kernel_hostname}" != "${SERIAL}" ]
	then
		${log_it} "Updating ${kernel_hostname_file}"
		/bin/echo "${SERIAL}" > ${kernel_hostname_file}
	fi
}

# Check/create /etc/solidsense
if [ ! -f ${solidsense_file} ]
then
	touch ${solidsense_file}
	create_etc_solidsense
else
	check_etc_solidsense
	if [ ${redo_check_etc_solidsense} -eq 1 ]
	then
		create_etc_solidsense
	fi
fi

# shellcheck source=/dev/null
. ${solidsense_file}

# Check ${hosts_file}
check_etc_hosts

# Check ${hostname_file}
check_etc_hostname
