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


# input:	dxBam, dxBai, dxRegList, bamMd5, baiMd5
# output:	sliceBamTarArray, coverStat

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
	echo "input: BAM file: '${dxBam}'"		
	echo "input: BAI: '${dxBai}'"
	echo "input: region list: '${dxRegList}'"	
	echo "input: BAM Md5: '${bamMd5}'"
	echo "input: BAI Md5: '${baiMd5}'"

	# resolve input filenames:
	bam=$home/$(dx describe "${dxBam}" --name)
	bai=$home/$(dx describe "${dxBai}" --name)
	regList=$home/$(dx describe "${dxRegList}" --name)

	# download input files
	echo "download ${dxBam} to local file ${bam}"
	dx download "${dxBam}" -o "${bam}" --no-progress
	echo "download ${dxBai} to local file ${bai}"
	dx download "${dxBai}" -o "${bai}" --no-progress
	echo "download ${dxRegList} to local file ${regList}"
	dx download "${dxRegList}" -o "${regList}" --no-progress

	nreg=$(cat $regList | wc -l)
	echo "::::: Number of regions to slice: $nreg :::::"

	# check md5sum
	echo "checking md5sum of BAI $bai"
   	md5=$(md5sum $bai | awk '{print $1}')
	if [ $md5 != $baiMd5 ]; then
		echo "*ERROR* BAI md5sum mismatch: expected \"$baiMd5\" downloaded \"$md5\""
		exit 1
	fi

	echo "checking md5sum of BAM $bam"
   	md5=$(md5sum $bam | awk '{print $1}')
	if [ $md5 != $bamMd5 ]; then
		echo "*ERROR* BAM md5sum mismatch: expected \"$bamMd5\" downloaded \"$md5\""
		exit 1
	fi

	# prepare output dir
	slicedir=$home/slice
	mkdir -p $slicedir
	cd $slicedir
	echo "slice bam in $nreg regions defined in $regList"
	t1=$(date +%s)
	awk -v bam=$bam '{print bam","$0}' $regList | xargs -n1 -P$nthread /usr/bin/slice.sh 
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: slicing bam done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"
	cd $home

	# stat output sliced bams
	id=$(basename $bam | cut -d\. -f1)
	stat=$home/$id.cover.stat.dat
   	ls $slicedir > $stat
	num_bam=$(cat $stat | grep -c bam$)
	num_bai=$(cat $stat | grep -c bai$)
	num_empty=$(cat $stat | grep -c empty$)
	if [ $num_bam -ne $num_bai ]; then
		echo "*ERROR*: number of BAMs and BAIs mismatch: $num_bam BAMs but $num_bai BAIs"
		exit 1
	fi
	if [ $num_bam -ne $nreg ]; then
		echo "*ERROR*: number of BAMs and output regions mismatch: $num_bam BAMs but $nreg regions"
		exit 1
	fi
	echo "::::: Sliced $num_bam BAMs and $num_bai BAIs in sample $id :::::"
	echo "::::: $num_empty out of $nreg regions are found empty in sample $id :::::"

	# remove bam file to save space
	echo "rm $bai $bam"
	rm $bai $bam

	# tar stat file and upload
	echo "upload $stat.gz"
	gzip $stat
	oid=$(time dx upload $stat.gz --brief)
    dx-jobutil-add-output coverStat "$oid" --class=file

	# group output files in every 10 windows in parallel
	nbin=$[nreg/10]
	t1=$(date +%s)
	seq 0 $nbin | awk -v id=$id -v regList=$regList '{print id","regList","$1}' | xargs -n1 -P$nthread /usr/bin/tar10.sh
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: compress every 10 sliced bams done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"

	# upload in serial
	t1=$(date +%s)
	for i in $(seq 0 $nbin); do 
		otar=$id.slicebin.$i.tar.gz
		echo "dx upload $otar --brief"
		oid=$(time dx upload $otar --brief)
		dx-jobutil-add-output sliceBamTarArray "$oid" --class=array:file
		echo "rm $otar"
		rm $otar
	done	
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::::: upload tarballs done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}') ::::"

	echo "ALL DONE!"
}




