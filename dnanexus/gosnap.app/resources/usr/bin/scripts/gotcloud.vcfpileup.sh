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
# $id, $bam, $allvcfsite, $region, $pvcfdir
# output
# $pvcfdir/$id.$region.vcf.gz(.log, .err)

line=$1
id=$(echo $line | cut -d\, -f 1)			# sample id
bam=$(echo $line | cut -d\, -f 2)			# sample level bam file
allvcfsite=$(echo $line | cut -d\, -f 3)	# sites of all SNPs (before filtering)
region=$(echo $line | cut -d\, -f 4)		# calling region
pvcfdir=$(echo $line | cut -d\, -f 5)		# output pvcf

mkdir -p $pvcfdir
pvcf=$pvcfdir/$id.${region/:/.}.vcf.gz
log=$pvcf.log
err=$pvcf.err

# pileup vcf
echo "[gc.vcfpileup] input = $line,  output = $pvcf"
${gcbin}/vcfPileup -i $allvcfsite -v $pvcf -b $bam > $log 2> $err

# error checking
if [ ! $pvcf ]; then
	echo "*ERROR* failed to write to $pvcf"
	exit 1
fi

