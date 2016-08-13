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


gcbin=/usr/bin/gotcloud

# input CSV string (without space): 
# $refgen, $id, $bam, $region, $glfdir
# output 
# $glfdir/$id.$region.glf(.log)

line=$1
refgen=$(echo $line | cut -d\, -f 1)		# reference genome file
id=$(echo $line | cut -d\, -f 2)			# sample id
bam=$(echo $line | cut -d\, -f 3)			# sample level bam file
region=$(echo $line | cut -d\, -f 4)		# calling region
glfdir=$(echo $line | cut -d\, -f 5)		# output glfdir

mkdir -p $glfdir
glf=$glfdir/$id.${region/:/.}.glf
log=$glf.log

# glf calling
echo "[gc.pileup] input = $line,  output = $glf"
(${gcbin}/samtools-hybrid view -q 20 -F 0x0704 -uh $bam $region | \
	${gcbin}/samtools-hybrid calmd -uAEbr - $refgen | \
	${gcbin}/bam clipOverlap --in -.ubam --out -.ubam --phoneHomeThinning 10 | \
	${gcbin}/samtools-hybrid pileup -f $refgen -g - \
	> $glf) 2> $log

# error checking
if [ ! $glf ]; then
	echo "*ERROR* failed to write to $glf"
	exit 1
fi

