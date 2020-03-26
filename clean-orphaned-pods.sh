#!/bin/sh

logpath="/var/log/kubernetes/kubelet.log"
podspath="/var/lib/kubelet/pods"
orphanednum=`tail $logpath | grep "Orphaned pod" | tail -n 1 | awk -F "total of" '{print $2}' | awk '{print int($1)}'`

echo "found $orphanednum orphaned pods"

while [ $orphanednum -gt 0 ]
do
	podid=`tail $logpath | grep "Orphaned pod" | tail -n 1 | awk -F "Orphaned pod" '{print $2}' | awk '{print $1}' | sed 's/"//g'`
	echo "found orphaned pod $podid"

	if [ ! -d "$podspath/$podid/volumes" ]; then
		orphanednum=$(( $orphanednum -1 ))
		continue
	fi

	if [ -d "$podspath/$podid/volume-subpaths" ]; then
		mountpaths=`mount | grep "$podspath/$podid/volume-subpaths/" | awk '{print $3}'`
		for mntpath in $ mountpaths;
		do
			echo "fix subpath issue:: umount subpath $mntpath"
			umount $mntpath
		done
	fi

	echo "start to clean orphaned pod $podid"

	volumeTypes=`ls $podspath/$podid/volumes/`
	for volumeType in $volumeTypes;
	do
		subVolumes=`ls -A $podspath/$podid/volumes/$volumeType`
		for subVolume in $subVolumes;
		do
			if [ -d "$podspath/$podid/volumes/$volumeType/$subVolume/mount" ]; then
				chattr -i $podspath/$podid/volumes/$volumeType/$subVolume/mount
			fi
			rm -rf $podspath/$podid/volumes/$volumeType/$subVolume
		done
		rm -rf $podspath/$podid/volumes/$volumeType
	done

	rm -rf $podspath/$podid/volumes
	echo "orphaned pod $podid is deleted"

	sleep 2
	orphanednum=$(( $orphanednum -1 ))
done
