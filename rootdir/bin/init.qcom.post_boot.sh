#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2020, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function configure_read_ahead_kb_values() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)

    # Set 128 for <= 3GB &
    # set 512 for >= 4GB targets.
    if [ $MemTotal -le 3145728 ]; then
        echo 128 > /sys/block/mmcblk0/bdi/read_ahead_kb
        echo 128 > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
        for dm in $dmpts; do
            echo 128 > $dm
        done
    else
        echo 128 > /sys/block/mmcblk0/bdi/read_ahead_kb
        echo 128 > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
        for dm in $dmpts; do
            echo 128 > $dm
        done
    fi
}

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 32 bit Non-Go, all memory configurations will use 15K series
    # 32 bit Go, all memory configurations will use uLMK + Memcg
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #

ProductName=`getprop ro.board.platform`
low_ram=`getprop ro.config.low_ram`

if [ "$ProductName" == "msmnile" ] || [ "$ProductName" == "kona" ] || [ "$ProductName" == "sdmshrike_au" ]; then
      configure_read_ahead_kb_values
fi
}

function start_hbtp()
{
        # Start the Host based Touch processing but not in the power off mode.
        bootmode=`getprop ro.bootmode`
        if [ "charger" != $bootmode ]; then
                start vendor.hbtp
        fi
}

case "$target" in
	"kona")
	rev=`cat /sys/devices/soc0/revision`
	ddr_type=`od -An -tx /proc/device-tree/memory/ddr_device_type`
	ddr_type4="07"
	ddr_type5="08"

	# cpuset parameters
        echo 0-1     > /dev/cpuset/background/cpus
        echo 0-3     > /dev/cpuset/system-background/cpus
        echo 4-6     > /dev/cpuset/foreground/boost/cpus
        echo 0-2,4-6 > /dev/cpuset/foreground/cpus
        echo 0-7     > /dev/cpuset/top-app/cpus
        echo 0-3     > /dev/cpuset/restricted/cpus
        echo 0-7     > /dev/cpuset/camera-daemon/cpus
        echo 0-7     > /dev/cpuset/camera-daemon-dedicated/cpus

	# Enable bus-dcvs
	for device in /sys/devices/platform/soc
	do
	    for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
	    do
		echo "bw_hwmon" > $cpubw/governor
		echo "4577 7110 9155 12298 14236 15258" > $cpubw/bw_hwmon/mbps_zones
		echo 4 > $cpubw/bw_hwmon/sample_ms
		echo 50 > $cpubw/bw_hwmon/io_percent
		echo 20 > $cpubw/bw_hwmon/hist_memory
		echo 10 > $cpubw/bw_hwmon/hyst_length
		echo 30 > $cpubw/bw_hwmon/down_thres
		echo 0 > $cpubw/bw_hwmon/guard_band_mbps
		echo 250 > $cpubw/bw_hwmon/up_scale
		echo 1600 > $cpubw/bw_hwmon/idle_mbps
		echo 14236 > $cpubw/max_freq
		echo 40 > $cpubw/polling_interval
	    done

	    for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
	    do
		echo "bw_hwmon" > $llccbw/governor
		if [ ${ddr_type:4:2} == $ddr_type4 ]; then
			echo "1720 2086 2929 3879 5161 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
		elif [ ${ddr_type:4:2} == $ddr_type5 ]; then
			echo "1720 2086 2929 3879 5931 6881 7980 10437" > $llccbw/bw_hwmon/mbps_zones
		fi
		echo 4 > $llccbw/bw_hwmon/sample_ms
		echo 80 > $llccbw/bw_hwmon/io_percent
		echo 20 > $llccbw/bw_hwmon/hist_memory
		echo 10 > $llccbw/bw_hwmon/hyst_length
		echo 30 > $llccbw/bw_hwmon/down_thres
		echo 0 > $llccbw/bw_hwmon/guard_band_mbps
		echo 250 > $llccbw/bw_hwmon/up_scale
		echo 1600 > $llccbw/bw_hwmon/idle_mbps
		echo 6881 > $llccbw/max_freq
		echo 40 > $llccbw/polling_interval
	    done

	    for npubw in $device/*npu*-ddr-bw/devfreq/*npu*-ddr-bw
	    do
		echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
		echo "bw_hwmon" > $npubw/governor
		if [ ${ddr_type:4:2} == $ddr_type4 ]; then
			echo "1720 2086 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
		elif [ ${ddr_type:4:2} == $ddr_type5 ]; then
			echo "1720 2086 2929 3879 5931 6881 7980 10437" > $npubw/bw_hwmon/mbps_zones
		fi
		echo 4 > $npubw/bw_hwmon/sample_ms
		echo 160 > $npubw/bw_hwmon/io_percent
		echo 20 > $npubw/bw_hwmon/hist_memory
		echo 10 > $npubw/bw_hwmon/hyst_length
		echo 30 > $npubw/bw_hwmon/down_thres
		echo 0 > $npubw/bw_hwmon/guard_band_mbps
		echo 250 > $npubw/bw_hwmon/up_scale
		echo 1600 > $npubw/bw_hwmon/idle_mbps
		echo 40 > $npubw/polling_interval
		echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
	    done

	    for npullccbw in $device/*npu*-llcc-bw/devfreq/*npu*-llcc-bw
	    do
		echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
		echo "bw_hwmon" > $npullccbw/governor
		echo "4577 7110 9155 12298 14236 15258" > $npullccbw/bw_hwmon/mbps_zones
		echo 4 > $npullccbw/bw_hwmon/sample_ms
		echo 160 > $npullccbw/bw_hwmon/io_percent
		echo 20 > $npullccbw/bw_hwmon/hist_memory
		echo 10 > $npullccbw/bw_hwmon/hyst_length
		echo 30 > $npullccbw/bw_hwmon/down_thres
		echo 0 > $npullccbw/bw_hwmon/guard_band_mbps
		echo 250 > $npullccbw/bw_hwmon/up_scale
		echo 1600 > $npullccbw/bw_hwmon/idle_mbps
		echo 40 > $npullccbw/polling_interval
		echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
	    done
	done
        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        setprop vendor.dcvs.prop 0
	setprop vendor.dcvs.prop 1
    configure_memory_parameters
    ;;
esac

# Post-setup services
case "$target" in
    "msm8909" | "msm8916" | "msm8937" | "msm8952" | "msm8953" | "msm8994" | "msm8992" | "msm8996" | "msm8998" | "sdm660" | "apq8098_latv" | "sdm845" | "sdm710" | "msmnile" | "msmsteppe" | "sm6150" | "kona" | "lito" | "trinket" | "atoll" | "bengal" | "sdmshrike")
        setprop vendor.post_boot.parsed 1
    ;;
