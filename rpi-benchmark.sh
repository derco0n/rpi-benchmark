#!/bin/bash

function greeting {
	clear
	sync
	echo -e "\e[96mRaspberry Pi Benchmark Test"
	echo -e "by: derco0n (https://github.com/derco0n/rpi-benchmark)"
	echo -e "Version: 0.1 (2020/01)"
	echo -e ""
	echo -e "Based on the work of \"AikonCWD\" (https://github.com/aikoncwd)\e\n[97m"

	# Show current hardware
	vcgencmd measure_temp
	vcgencmd get_config int | grep arm_freq
	vcgencmd get_config int | grep core_freq
	vcgencmd get_config int | grep sdram_freq
	vcgencmd get_config int | grep gpu_freq
	printf "sd_clock="
	grep "actual clock" /sys/kernel/debug/mmc0/ios 2>/dev/null | awk '{printf("%0.3f MHz", $3/1000000)}'
	echo -e "\n\e[93m"

}

function benchcpu {
	mprime=20000
	threads=4
	echo -e "CPU-Test started. Temperature is: $(vcgencmd measure_temp | cut -d"=" -f 2)"
	echo -e "Calculating $mprime Primes in $threads Threads. Please wait."
	echo -e ""
	echo -e "For comparison, this test lasts this long on stock frequencies:"
	echo -e "Raspberry Pi 4\tRaspbian Buster\t63.16s"
	echo -e "Raspberry Pi 3\tRaspbian Jessie\t119.54s"
	echo -e "Raspberry Pi 2\tRaspbian Jessie\t191.24s"
	echo -e "Raspberry Pi ZW\tRaspb. Stretch\t607s"
	echo -e ""
	echo -e "OC-Results:"
	echo -e "Raspberry Pi 4\tCPU=2147\t43.7s"
	echo -e "\e[94m"
	sysbench --num-threads=$threads --validate=on --test=cpu --cpu-max-prime=$mprime run | grep 'total time:\|min:\|avg:\|max:' | tr -s [:space:]
	echo -e "\e[93m"
	echo -e "CPU-Test finished. Temperature is: $(vcgencmd measure_temp)"
}


function benchinternet {
	echo -e "Internet-Test started..."
	echo -e "\e[94m"
	speedtest-cli --simple
	echo -e "\e[93m"
	echo -e "Internet-Test finished."

}

function benchthreads {
	tyields=32000
	threads=4
	echo "THREAD-Test started."
	echo "Performing Test with $threads Threads. Yields=$tyields. Please wait."
	echo -e "\e[94m"
	sysbench --num-threads=$threads --validate=on --test=threads --thread-yields=$tyields --thread-locks=6 run | grep 'total time:\|min:\|avg:\|max:' | tr -s [:space:]
	vcgencmd measure_temp
	echo -e "\e[93m"
	echo "THREAD-Test finished."

}

function memtest {
	bsizes=(1 2 4 8 16 32)
	amodes=(seq rnd)
	threads=4
	echo "RAM-Test started."
	echo "Testing RAM with $threads Threads."
	echo -e "\e[94m"
	tsize=3
	for amode in ${amodes[@]}; do
		echo -e "Testing $amode Access"
		for bsize in ${bsizes[@]};do
			echo -e "\e[93m"
			echo "Testing Write Total $tsize GBytes with $bsize kByte Blocksize..."
			echo -e "\e[94m"
			sysbench --num-threads=4 --memory-oper=write --validate=on --test=memory --memory-block-size="$bsize"K --memory-total-size="$tsize"G --memory-access-mode=$amode run | grep 'Operations\|transferred\|total time:\|min:\|avg:\|max:' | tr -s [:space:]
			vcgencmd measure_temp
			echo -e ""
			echo -e "\e[93m"
			echo "Testing Read Total $tsize GBytes with $bsize kByte Blocksize..."
			echo -e "\e[94m"
			sysbench --num-threads=4 --memory-oper=read --validate=on --test=memory --memory-block-size="$bsize"K --memory-total-size="$tsize"G --memory-access-mode=$amode run | grep 'Operations\|transferred\|total time:\|min:\|avg:\|max:' | tr -s [:space:]
			vcgencmd measure_temp
			echo -e ""
		done
	done
	echo -e "\e[93m"
	echo "RAM-Test finished."
}

function dddisktest {
	echo "DD-Disk-IO-Test started."
	echo -e "\e[93m"

	echo -e "Running DD WRITE test...\e[94m"
	rm -f ~/test.tmp 2> /dev/zero && sync && dd if=/dev/zero of=~/test.tmp bs=1M count=512 conv=fsync 2>&1 | grep -v records
	vcgencmd measure_temp
	echo -e "\e[93m"


	echo -e "Running DD READ test...\e[94m"
	echo -e 3 > /proc/sys/vm/drop_caches 2> /dev/zero&& sync && dd if=~/test.tmp of=/dev/null bs=1M 2>&1 | grep -v records
	vcgencmd measure_temp
	rm -f ~/test.tmp
	echo -e "\e[0m"

	echo -e "\e[93m"
	echo "DD-Disk-IO-Test finished."

}

function fin {
	echo -e "\eRPi-Benchmark completed.\e[0m\n"
}


function soconly {
	START=$(date +"%s")
	benchcpu
	benchthreads
	memtest
	fin
	END=$(date +"%s")
	DIFF=$(($END - $START))
	echo -e "$Yellow Test ended after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
}

function all {
	START=$(date +"%s")
	benchcpu
	benchthreads
	memtest
	dddisktest
	benchinternet
	fin
	END=$(date +"%s")
	DIFF=$(($END - $START))
	echo -e "$Yellow Test ended after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
}

function inst {
	echo "Checking for dependencies"
	#Install dependencies
	if [ ! `which hdparm` ]; then
	  echo "hdparm not found. installing..."
	  apt-get install -y hdparm
	fi
	if [ ! `which sysbench` ]; then
	  echo "sysbench not found. installing..."
	  apt-get install -y sysbench
	fi
	if [ ! `which speedtest-cli` ]; then
	  echo "speedtest-cli not found. installing..."
	  apt-get install -y speedtest-cli
	fi
	echo "Install done."

}

# Welcome the user
greeting
if ! [ -z $1 ]; then
	# param1 was set
	if [[ "$1" == "install" ]]; then
		[ "$(whoami)" == "root" ] || { echo "Must be run as sudo!"; exit 1; }
		# Install
		inst
	elif [[ "$1" == "soc" ]]; then
		soconly
	elif [[ "$1" == "disk" ]]; then
		dddisktest
	elif [[ "$1" == "internet" ]]; then
		benchinternet
	elif [[ "$1" == "ram" ]]; then
		memtest
	elif [[ "$1" == "threads" ]]; then
		benchthreads
	elif [[ "$1" == "cpu" ]]; then
		benchcpu
	else
		# Perform all tests
		all
	fi
else
	# Perform all tests
	all

fi

exit 0

