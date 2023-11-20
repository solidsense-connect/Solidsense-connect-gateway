#!/bin/sh
# SolidSense-Connect
#
# Flash nordic nrf52832 u-blox | nrf52833 FWM7BLZ22W | nrf52840 ublox


# Globals
NC="$(command -vp nc)"
OCD_CFG_FILE="$(mktemp /tmp/.openocd_cfg.XXXXX)"
OCD_PID=""
LOGFILE="$(mktemp /tmp/.openocd_log.XXXXX)"
LOGFILE_CMD="$(mktemp /tmp/.openocd_log_cmd.XXXXX)"
UICR_FILE="/tmp/uicr.bin"
OCD_SWD_NUMS=""
FLASH_OFFSET=""
FILENAME=""
MAC=""
STATUS_CHECK_MAC="0"
STATUS_TYPE="0"
DEVICE="b1"

# Functions
openocd_create_cfg_file () {
	hardware=$(determine_hardware)
	if [ "${hardware}" = "imx8mnc" ] ; then
	cat > "${OCD_CFG_FILE}" << END
source [find interface/imx-native.cfg]

transport select swd

set WORKAREASIZE 0

imx_gpio_peripheral_base 0x30200000
imx_gpio_speed_coeffs 50000 50
source [find target/nrf52.cfg]

imx_gpio_swd_nums ${OCD_SWD_NUMS}
adapter speed 100
END
	else
	cat > "${OCD_CFG_FILE}" << END
source [find interface/imx-native.cfg]

transport select swd

set WORKAREASIZE 0

source [find target/nrf52.cfg]

imx_gpio_swd_nums ${OCD_SWD_NUMS}
END
	fi
}

replaceByte () {
	file="${1}"
	offset="${2}"
	value="$(echo "obase=10; ibase=16; ${3}" | bc)"

	# shellcheck disable=SC2059
	printf "$(printf '\\x%02X' "${value}")" | dd of="${file}" bs=1 seek="${offset}" count=1 conv=notrunc > /dev/null 2>&1
}

openocd_cmd () {
	cmd="${1}"

	printf "%s: " "$(date)">> "${LOGFILE_CMD}" 2>&1
	if [ -z "${NC}" ]; then
		(echo "${cmd}"; sleep 0.1) | telnet localhost 4444 >> "${LOGFILE_CMD}" 2>&1
	else
		echo "${cmd}" | nc localhost 4444 | tr -d '\000' >> "${LOGFILE_CMD}" 2>&1
	fi
	echo "" >> "${LOGFILE}" 2>&1
}

openocd_check_busy_state () {
	echo "Checking chip state"
	OCD_PID=$(openocd -f "${OCD_CFG_FILE}" -c init >> "${LOGFILE}" 2>&1 & echo ${!})
	sleep 2
	grep -q "telnet" "${LOGFILE}"
	result="${?}"
	if [ "${result}" != "0" ]; then
		echo "Chip is busy! Please power cycle and run again."
		cleanup
		exit 1
	fi
}

openocd_check_state () {
	if [ -z "${NC}" ]; then
		result=$( (echo "targets"; sleep 0.1) | telnet localhost 4444 | tr -d '\000')
	else
		result=$(echo "targets" | nc localhost 4444 | tr -d '\000')
	fi
	if echo "${result}" | grep -q halted; then
		echo "Chip is ready for flashing, continuing..."
	elif echo "${result}" | grep -q running; then
		echo "Chip is running, halting..."
		openocd_cmd "halt"
	elif echo "${result}" | grep -q unknown; then
		echo "Chip is locked! Unlocking and preparing for flashing..."
		openocd_cmd "nrf52.dap apreg 1 0x04 0x00"
		openocd_cmd "nrf52.dap apreg 1 0x04 0x01"
		# Turn on ERASEALL bit
		sleep 1
		openocd_cmd "nrf52.dap apreg 1 0x00 0x01"
		openocd_cmd "nrf52.dap apreg 1 0x00 0x00"
		# Chip has gone through reset state
		openocd_cmd "nrf52.dap apreg 1 0x04 0x00"
		# Turn off ERASEALL bit
		openocd_cmd "reset halt"
		# Undergo reset and halt chip
	else
		echo "Chip is in unknown state, canceling."
		openocd_cmd "shutdown"
		exit 1
	fi
}

openocd_check_protected_state () {
	if [ -z "${NC}" ]; then
		result=$( (echo "nrf52.dap apreg 1 0x04"; sleep 0.1) | telnet localhost 4444 | tr -d '\000')
	else
		result=$(echo "nrf52.dap apreg 1 0x04" | nc localhost 4444 | tr -d '\000')
	fi
	if echo "${result}" | grep -q "0x00000000"; then
		echo "Chip is protected state!"
		# Turn off protected state.
		openocd_cmd "nrf52.dap apreg 1 0x04 0x01"

		# Undergo reset and halt chip
		openocd_cmd "reset"
		openocd_cmd "halt"
	elif ! echo "${result}" | grep -q "0x00000001"; then
		value=$(echo "${result}" | awk '/^0x/{print $0}')
		echo "Chip is a weird state: ${value}"
		openocd_cmd "nrf52.dap apreg 1 0x04 0x01"
		sleep 1
		openocd_cmd "nrf52.dap apreg 1 0x04 0x01"
		sleep 1
		openocd_cmd "nrf52.dap apreg 1 0x04 0x01"
		sleep 1
		openocd_shutdown
		cleanup
		echo "Please *power* cycle the unit and try again"
		exit 1
	fi
}

openocd_load () {
	echo "Programming flash of type <${TYPE}> with file <$(basename "${FILENAME}")>."
	openocd_cmd "reset halt"
	openocd_cmd "flash write_image erase ${FILENAME} ${FLASH_OFFSET}"
	bytes_written="$(grep wrote "${LOGFILE_CMD}")"
	if [ -n "${bytes_written}" ]; then
		echo "${bytes_written}"
	else
		echo "Warning something went wrong, no bytes written."
	fi
}

openocd_reset_run () {
	openocd_cmd "reset run"
}

openocd_shutdown () {
	openocd_cmd "shutdown"
	sleep 1
}

openocd_check_mac () {
	if [ -z "${NC}" ]; then
		result=$( (echo "mdb 0x10001080 6"; sleep 0.1) | telnet localhost 4444 | tr -d '\000')
	else
		result=$(echo "mdb 0x10001080 6" | nc localhost 4444 | tr -d '\000')
	fi
	mac="$(echo "${result}" | sed -n 's/.*0x10001080: //p' | awk '{printf("%s:%s:%s:%s:%s:%s", $1, $2, $3, $4, $5, $6)}')"

	echo "${mac}"
}

openocd_uicr_save () {
	openocd_cmd "flash read_bank 1 ${UICR_FILE}"
}

openocd_uicr_load () {
	openocd_cmd "flash write_bank 1 ${UICR_FILE}"
}

openocd_uicr_erase_sector () {
	openocd_cmd "flash erase_sector 1 0 last"
}

openocd_set_mac () {
	mac="${1}"

	# Save UICR
	openocd_uicr_save

	# Update ${UICR_FILE} contents with the MAC address
	eval set -- "$(echo "${mac}" | sed 's/:/ /g')"
	replaceByte "${UICR_FILE}" "128" "${1}"
	replaceByte "${UICR_FILE}" "129" "${2}"
	replaceByte "${UICR_FILE}" "130" "${3}"
	replaceByte "${UICR_FILE}" "131" "${4}"
	replaceByte "${UICR_FILE}" "132" "${5}"
	replaceByte "${UICR_FILE}" "133" "${6}"
	set --

	# Erase UICR
	openocd_uicr_erase_sector
	# Load UICR
	openocd_uicr_load
}

determine_hardware () {
	type="$(tr -d '\000' < /proc/device-tree/model)"
	case "${type}" in
		"SolidRun HummingBoard2 Solo/DualLite (1.5som+emmc)" )
			hardware="n6gsdl"
			;;
		"SolidRun HummingBoard2 Dual/Quad (1.5som+emmc)" )
			hardware="n6gq"
			;;
		"SolidRun SolidSense IN6 Solo/DualLite (1.5som+emmc)" )
			hardware="in6gsdl"
			;;
		"SolidRun SolidSense IN6 Dual/Quad (1.5som+emmc)" )
			hardware="in6gq"
			;;
		"NXP i.MX8MNano DDR4 SolidRun board" )
			hardware="imx8mnc"
			;;
		* )
			hardware="UNKNOWN"
			;;
	esac

	echo "${hardware}"
}

determine_swds () {
	hardware=$(determine_hardware)
	case "${hardware}" in
		n6gsdl|n6gq )
			case "${1}" in
				1|sink1 )
					SWD="82 81"
					;;
				2|sink2 )
					SWD="59 125"
					;;
				* )
					SWD="UNKNOWN"
					;;
			esac
			;;
		in6gsdl|in6gq )
			case "${1}" in
				1|sink1 )
					SWD="64 65"
					;;
				2|sink2 )
					SWD="91 90"
					;;
				* )
					SWD="UNKNOWN"
					;;
			esac
			;;
		imx8mnc )
			case "${1}" in
				1|sink1 )
					SWD="14 15"
					;;
				* )
					SWD="UNKNOWN"
					;;
			esac
			;;
		UNKNOWN )
			echo "Hardware type <${hardware}> not found!"
			exit 1
			;;
		* )
			echo "Hardware type <${hardware}> not found!"
			exit 1
			;;
	esac

	echo "${SWD}"
}

determine_offset () {
	device="${1}"

	case "${device}" in
		b1|B1 )
			FLASH_OFFSET="0x8000"
			;;
                fwm|FWM )
                        FLASH_OFFSET="0x8000"
                        ;;
		b3|B3 )
			FLASH_OFFSET="0xc000"
			;;
		UNKNOWN )
			echo "Device type <${hardware}> not found!"
			FLASH_OFFSET="UNKNOWN"
			;;
		* )
			echo "Device type <${hardware}> not found!"
			FLASH_OFFSET="UNKNOWN"
			;;
	esac
	echo "${FLASH_OFFSET}"
}

determine_reset_gpio () {
	hardware=$(determine_hardware)

	case "${hardware}" in
		imx8mnc )
			GPIO_RESET="5"
			;;
		* )
			GPIO_RESET="UNKNOWN"
			;;
	esac
	echo "${GPIO_RESET}"
}

gpio_set_value () {
	value="${1}"
	gpio_reset=$(determine_reset_gpio)
	export="/sys/class/gpio/export"
	unexport="/sys/class/gpio/unexport"
	file_gpio="/sys/class/gpio/gpio${gpio_reset}"

	if [ ! -e "${file_gpio}" ] ; then
		echo "${gpio_reset}" > ${export}
	fi

	if [ "${value}" -eq 1 ] ; then
		echo "out" > "${file_gpio}/direction"
		echo "${value}" > "${file_gpio}/value"
	else
		echo "${gpio_reset}" > "${unexport}"
	fi
}

gpio_handle () {
	gpio_reset=$(determine_reset_gpio)
	if [ "${gpio_reset}" = "UNKNOWN" ] ; then
		return
	fi
	state=${1}
	case "${state}" in
		enable )
			gpio_set_value 1
			;;
		disable )
			gpio_set_value 0
			;;
		* )
			echo "Unknown GPIO state: ${state}"
			;;
	esac
}

cleanup () {
	if [ -f "${OCD_CFG_FILE}" ]; then
		rm -f "${OCD_CFG_FILE}"
	fi
	pid="$(pgrep openocd)"
	if [ -n "${pid}" ]; then
		if [ "${pid}" != "${OCD_PID}" ]; then
			echo "Warning.  Detecting a running openocd that was not started by me, pid: <${pid}>"
		else
			echo "Killing running openocd pid: <${OCD_PID}>, detected pid: <${pid}>"
			pkill "${OCD_PID}" >> "${LOGFILE}" 2>&1
			pkill -9 "${OCD_PID}" >> "${LOGFILE}" 2>&1
		fi
	fi
}

usage () {
        echo "$(basename "${0}"): firmware                   : Firmware image to flash"
        echo ""
        echo " N6 indoor        : SRGxxxx.01SD (Nina-b1 nRF52832) and SRGxxxx.02SD (Fujitsu nRF52833)"
        echo " N8 compact       : SRG40x.01SD  (Nina-b1 nRF52832) and SRG40x.02SD  (Fujitsu nRF52833)"
        echo " N6 outdoor       : Nina-b3 nRF52840"
        echo ""
        echo " parameters"
        echo "    -s|--sink                                  : Sink <1|2>"
        echo "    -d|--device                                : Nina <b1|B1> or Fwm <fwm|FWM> or Nina <b3|B3>"
        echo "    -m|--mac-check                             :"
        echo "    -M|--mac-set <MAC Address>                 : example: 0a:01:02:03:04:05 or ETH MAC + 1 (Recommended)"
        echo "    -t|--type                                  : type to flash <boot|program|wirepas>"
        echo "    <FILE>                                     : file to flash"
        echo ""
        echo "  example BLE: $(basename "${0}") -s1 -db1 -tboot blehci-boot-1.2.0.bin"
        echo "  example Wirepas: $(basename "${0}") -s1 -db1 -twirepas firmware.hex"
        exit 1
}

options=$(getopt -l "help,mac-check,mac-set:,sink:,device:,type:" -o ":hmM:s:d:t:" -- "${@}")
eval set -- "${options}"

while true
do
	case ${1} in
		-h|--help )
			usage
			;;
		-m|--mac-check )
			STATUS_CHECK_MAC="1"
			;;
		-M|--mac-set )
			shift
			MAC="${1}"
			;;
		-s|--sink )
			shift
			OCD_SWD_NUMS=$(determine_swds "${1}")
			if [ "${OCD_SWD_NUMS}" = "UNKNOWN" ]; then
				echo "Unknown sink device <${1}>!"
				usage
			fi
			;;
		-d|--device )
			shift
			DEVICE="${1}"
			;;
		-t|--type )
			shift
			STATUS_TYPE="1"
			TYPE="${1}"
			;;
		\? )
			usage
			;;
		: )
			echo "Invalid option: ${OPTARG} requires an argument" 1>&2
			;;
		-- )
			shift
			break
			;;
		* )
			usage
			;;
	esac
	shift
done

if [ -z "${OCD_SWD_NUMS}" ]; then
	echo ""
	echo "-s|--sink is a mandatory option"
	echo ""
	usage
fi

# Have a valid sink
touch "${LOGFILE}"
gpio_handle "enable"
openocd_create_cfg_file
openocd_check_busy_state
openocd_check_state
openocd_check_protected_state

# Check MAC address
if [ "${STATUS_CHECK_MAC}" = "1" ]; then
	echo "Current configure mac address is: $(openocd_check_mac)"
fi

# Set MAC address
if [ -n "${MAC}" ]; then
	echo "Current configure mac address is: $(openocd_check_mac)"
	openocd_set_mac "${MAC}"
	echo "New configure mac address is: $(openocd_check_mac)"
fi

# Program flash
if [ "${STATUS_TYPE}" = "1" ]; then
	if [ "${#}" -ne "1" ]; then
		openocd_reset_run
		openocd_shutdown
		gpio_handle "disable"
		cleanup
		usage
	else
		FILENAME="${1}"
		if [ -f "${FILENAME}" ]; then
			case "${TYPE}" in
				boot )
					FLASH_OFFSET="0x0"
					;;
				program )
					FLASH_OFFSET="$(determine_offset "${DEVICE}")"
					;;
				wirepas )
					FLASH_OFFSET="0x0"
					;;
				* )
					echo "Unknown type <${TYPE}> not found!"
					openocd_reset_run
					openocd_shutdown
					gpio_handle "disable"
					cleanup
					exit 1
					;;
			esac
			openocd_load
		else
			echo "The <${FILENAME}> does not exist!"
			openocd_reset_run
			openocd_shutdown
			gpio_handle "disable"
			cleanup
			exit 1
		fi
	fi
fi

# Finished, cleaning up
openocd_reset_run
openocd_shutdown
gpio_handle "disable"
cleanup
