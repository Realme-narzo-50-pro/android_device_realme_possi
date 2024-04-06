#!/vendor/bin/sh
#
config="$1"

function oplus_configure_zram_parameters() {
	#huacai.zhou@PSW.BSP.kernel.drv, 2018/03/09, adjust zram size according to total ram size
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	echo lz4 > /sys/block/zram0/comp_algorithm
	echo 160 > /proc/sys/vm/swappiness
	echo 60 > /sys/module/oplus_bsp_zram_opt/parameters/direct_vm_swappiness
	echo 0 > /proc/sys/vm/page-cluster
	if [ -f /sys/block/zram0/disksize ]; then
		if [ -f /sys/block/zram0/use_dedup ]; then
			echo 1 > /sys/block/zram0/use_dedup
		fi

		if [ $MemTotal -le 524288 ]; then
			#config 384MB zramsize with ramsize 512MB
			echo 402653184 > /sys/block/zram0/disksize
		elif [ $MemTotal -le 1048576 ]; then
			#config 768MB zramsize with ramsize 1GB
			echo 805306368 > /sys/block/zram0/disksize
		elif [ $MemTotal -le 2097152 ]; then
			#config 1GB+256MB zramsize with ramsize 2GB
			echo lz4 > /sys/block/zram0/comp_algorithm
			echo 1342177280 > /sys/block/zram0/disksize
		elif [ $MemTotal -le 3145728 ]; then
			#config 1GB+512MB zramsize with ramsize 3GB
			echo lz4 > /sys/block/zram0/comp_algorithm
			echo 1610612736 > /sys/block/zram0/disksize
		elif [ $MemTotal -le 4194304 ]; then
			#config 2GB+512MB zramsize with ramsize 4GB
			echo 2684354560 > /sys/block/zram0/disksize
		elif [ $MemTotal -le 6291456 ]; then
			#config 3GB zramsize with ramsize 6GB
			echo 3221225472 > /sys/block/zram0/disksize
		else
			#config 4GB zramsize with ramsize >=8GB
			echo zstd > /sys/block/zram0/comp_algorithm
			echo 5368709120 > /sys/block/zram0/disksize
			echo 200 > /proc/sys/vm/swappiness
			echo 0 > /proc/sys/vm/direct_swappiness
		fi
		/vendor/bin/mkswap /dev/block/zram0
		/vendor/bin/swapon /dev/block/zram0
	fi
}

function oplus_configure_dynamic_swappiness() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	if [ $MemTotal -le 6291456 ]; then
		echo 0 > /proc/sys/vm/vm_swappiness_threshold1
		echo 0 > /proc/sys/vm/swappiness_threshold1_size
		echo 0 > /proc/sys/vm/vm_swappiness_threshold2
		echo 0 > /proc/sys/vm/swappiness_threshold2_size
	elif [ $MemTotal -le 8388608 ]; then
		echo 100 > /proc/sys/vm/vm_swappiness_threshold1
		echo 2000 > /proc/sys/vm/swappiness_threshold1_size
		echo 120 > /proc/sys/vm/vm_swappiness_threshold2
		echo 1500 > /proc/sys/vm/swappiness_threshold2_size
		echo 25 > /proc/sys/vm/watermark_scale_factor
	elif [ $MemTotal -le 12582912 ]; then
		echo 120 > /proc/sys/vm/vm_swappiness_threshold1
		echo 3600 > /proc/sys/vm/swappiness_threshold1_size
		echo 140 > /proc/sys/vm/vm_swappiness_threshold2
		echo 1500 > /proc/sys/vm/swappiness_threshold2_size
		echo 25 > /proc/sys/vm/watermark_scale_factor
	fi
}

function configure_read_ahead_kb_values() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	erofs_ra_kb=128

	dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)

	# Set 128 for <= 3GB &
	# set 512 for >= 4GB targets.
	if [ $MemTotal -le 3145728 ]; then
		ra_kb=128
	else
		ra_kb=512
	fi

	if [ -f /sys/block/mmcblk0/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0/bdi/read_ahead_kb
	fi
	if [ -f /sys/block/mmcblk0rpmb/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
	fi

	for dm in $dmpts; do
		# mtk configure dm-[0-5], so we don't need rewrite here.
		ignore=`echo $dm | grep 'dm-[0-5]/'`
		if [ ! -z "$ignore" ]; then
			continue
		fi

		dm_dev=`echo $dm |cut -d/ -f4`
		if [ "$dm_dev" = "" ]; then
			is_erofs=""
		else
			is_erofs=`mount |grep erofs |grep "${dm_dev} "`
		fi
		if [ "$is_erofs" = "" ]; then
			echo $ra_kb > $dm
		else
			echo $erofs_ra_kb > $dm
		fi
	done
}

#ifdef OPLUS_FEATURE_HYBRIDSWAP
function oplus_configure_hybridswap() {
	kernel_version=`uname -r`

	if [[ "$kernel_version" == "5.10"* ]]; then
		echo 160 > /sys/module/oplus_bsp_zram_opt/parameters/vm_swappiness
	else
		echo 160 > /sys/module/zram_opt/parameters/vm_swappiness
	fi

	echo 0 > /proc/sys/vm/page-cluster

	# FIXME: set system memcg pata in init.kernel.post_boot-lahaina.sh temporary
	echo 500 > /dev/memcg/system/memory.app_score
	echo systemserver > /dev/memcg/system/memory.name
}
#endif /* OPLUS_FEATURE_HYBRIDSWAP */

function configure_memory_parameters() {
	# For vts test which has replace system.img
	ls -l /product | grep '\-\>'
	if [ $? -eq 0 ]; then
		oplus_configure_zram_parameters
	else
		if [ -f /sys/block/zram0/hybridswap_enable ]; then
			oplus_configure_hybridswap
		else
			oplus_configure_zram_parameters
		fi
	fi
	oplus_configure_dynamic_swappiness
	# disable boost_watermark
	echo 0 > /proc/sys/vm//watermark_boost_factor

	# Disable periodic kcompactd wakeups. We do not use THP, so having many
	# huge pages is not as necessary.
	echo 0 > /proc/sys/vm/compaction_proactiveness

	# With THP enabled, the kernel greatly increases min_free_kbytes over its
	# default value. Disable THP to prevent resetting of min_free_kbytes
	# value during online/offline pages.
	# 11584kb is the standard kernel value of min_free_kbytes for 8Gb of lowmem
	if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi

	#set min_free_kbytes
	echo 12374 > /proc/sys/vm/min_free_kbytes

	# bind kswapd to kswapd cpuset
	kswapd_pid=`cat /sys/module/oplus_bsp_zram_opt/parameters/kswapd_pid`
	if [ ! -z "$kswapd_pid" ]; then
		if [ ${kswapd_pid} -gt 0 ]; then
			echo $kswapd_pid > /dev/cpuset/kswapd-like/tasks
		fi
	fi
}

case "$config" in
	"configure_memory_parameters")
		echo "configure_memory_parameters"
		configure_memory_parameters
		;;
	"configure_read_ahead_kb_values")
		echo "configure_read_ahead_kb_values"
		configure_read_ahead_kb_values
		;;
esac
