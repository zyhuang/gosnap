#!/bin/bash -e

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#    Copyright  2015  Fuli Yu's group at Baylor College of Medicine
#
#    Author:  Zhuoyi Huang <zhuoyih@bcm.edu>
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
#    Last modified:  05/06/2015
#
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# input:
# "name": "dxBamTarList",
# output:
# "name": "sliceBamTarArray",


main () {

	# determine number of threads to use
	ncpu=$(lscpu | grep ^CPU\( | awk '{print $NF}')
	ncore=$(lscpu | grep ^Thread | awk '{print $NF}')
	nthread=$[$ncpu*$ncore]
	echo "ncpu = $ncpu, ncore = $ncore, nthread = $nthread"

	# start job
	home=/mnt
	cd $home

	echo "========== INPUT =========="
	echo "input: BAM tarball list: '${dxBamTarList}'"		

	# resolve input filenames:
	bamTarList=$home/$(dx describe "${dxBamTarList}" --name)

	# download input files
	echo "download ${dxBamTarList} to local file ${bamTarList}"
	dx download "${dxBamTarList}" -o "${bamTarList}" --no-progress

	# count number of tarballs to download
	ntar=$(cat $bamTarList | wc -l)
	echo "::::: Number of tarballs to download: $ntar :::::"

	# download input tarballs in serial
	t1=$(date +%s)
	echo "download $ntar input tarballs in serial"
	cat $bamTarList | xargs -n1 -P1 /usr/bin/down.sh 
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: input tarballs download done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"	

	# check number of tarballs
	tarList=$home/local.tars.list
	ls *.slicebin.*.tar.gz > $tarList
	ntar1=$(cat $tarList | wc -l)
	echo "::::: Number of tarballs downloaded: $ntar1 :::::"
	if [ $ntar1 -ne $ntar ]; then
		echo "*ERROR*: failed to download some tarballs: expected $ntar, downloaded $ntar1"
		exit 1
	fi

 	# untar in parallel
	t1=$(date +%s)
	echo "untar $ntar1 tarballs in parallel"
	cat $tarList | xargs -n1 -P$nthread /usr/bin/untar.sh 
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: untar tarballs done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"	
	
	# check number of bams
	sliceDir=$home/slice
	fileList=$home/slice.list
	ls $sliceDir > $fileList

	nbam_expect=$[ntar*10]
	nbam=$(cat $fileList | grep bam$ | wc -l)
	nbai=$(cat $fileList | grep bai$ | wc -l)
	nempty=$(cat $fileList | grep empty$ | wc -l)
	echo "::::: downloaded in $sliceDir $nbam BAMs $nbai BAIs (expected $nbam_expect) and $nempty emtpy BAMs :::::"
	if [ $nbam -ne $nbai ] || [ $nbam -ne $nbam_expect ]; then
		echo "*ERROR*: missing bams: expected $nbam_expect, downloaded $nbam BAMs and $nbai BAIs"
		exit 1
	fi

	# make output region list
	regList=$home/regions.list
	cat $fileList | cut -d\. -f 2,3 | sort | uniq > $regList

	nreg=$(cat $regList | wc -l)
	echo "::::: input BAMs are in $nreg regions :::::"
	if [ $nreg -ne 10 ]; then
		echo "*ERROR*: expect 10 regions, found $nreg"
		exit 1
	fi

	# make 1mbp tarballs in parallel
	cd slice
	t1=$(date +%s)
	echo "tar $nreg regions in parallel"
	awk -v nsample=$ntar -v fileList=$fileList '{print $1","nsample","fileList}' $regList | xargs -n1 -P$nthread /usr/bin/tar.sh 
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: untar tarballs done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"	
	cd ..
  
	# count output tarballs
	otarList=$home/output.tars.list
	# $region.$nsample.bams.$nempty.empty.tar.gz
	find $sliceDir -name "*.bams.*.empty.tar.gz" > $otarList
	notar=$(cat $otarList | wc -l)
	echo "::::: number of output tarballs = $notar :::::"
	if [ $nreg -ne 10 ]; then
		echo "*ERROR*: expect 10 output tarballs, found $notar"
		exit 1
	fi

	# upload in serial
	t1=$(date +%s)
	for otar in $(cat $otarList); do 
		echo "dx upload $otar --brief"
		oid=$(time dx upload $otar --brief)
		dx-jobutil-add-output sliceBamTarArray "$oid" --class=array:file
		echo "rm $otar"
		rm $otar
	done
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: upload $notar tarballs done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"	



	echo "ALL DONE!"
}




