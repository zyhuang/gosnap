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

# input:	region, nsample, filelist
# region e.g. 16.000080000001-000081000000
# nsample is the expected number of samples in the tarball
# filelist is the list of sliced bams, bais and emptys in the current directory
# output tarball in current directory

line=$1
region=$(echo $line | cut -d\, -f1)
nsample=$(echo $line | cut -d\, -f2)
filelist=$(echo $line | cut -d\, -f3)

# looking for BAMs BAIs and empty tags to tar, e.g.
# HG00133.16.000081000001-000082000000.bam
# HG00133.16.000081000001-000082000000.bam.bai
# HG00133.16.000081000001-000082000000.bam.empty

nbam=$(cat $filelist | grep ".$region.bam$" | wc -l)
nbai=$(cat $filelist | grep ".$region.bam.bai$" | wc -l)
nempty=$(cat $filelist | grep ".$region.bam.empty$" | wc -l)

if [ $nbam -ne $nbai ] || [ $nbam -ne $nsample ]; then
	echo "[tar.sh] *ERROR* in region $region, expected $nsample samples, found $nbam BAMs $nbai BAIs"
	exit 1
fi

otar=$region.$nsample.bams.$nempty.empty.tar.gz
allfiles=$(cat $filelist | grep ".$region.bam" | tr '\n' ' ')

echo "[tar.sh] tar czf $otar allfiles; rm allfiles"
tar czf $otar $allfiles

if [ ! -f $otar ]; then
	echo "[tar.sh] *ERROR*: failed to generate $otar"
	exit 1
fi

rm $allfiles

