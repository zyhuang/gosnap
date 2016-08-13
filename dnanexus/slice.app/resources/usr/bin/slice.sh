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
# XXXXX.bam,1:000004000001-000005000000,1:000003999001-000005001000
# 1st field: bam absolute path
# 2nd field: region in the filename
# 3rd field: region used in slicing

# output (in current directory)
# sliced bam and bai: $id.${regname/:/.}.bam $id.${regname/:/.}.bai
# or if empty: $id.${regname/:/.}.bam.empty

line=$1
bam=$(echo $line | cut -d\, -f1)
regname=$(echo $line | cut -d\, -f2)
region=$(echo $line | cut -d\, -f3)

id=$(basename $bam | cut -d\. -f1)
obam=$id.${regname/:/.}.bam
obai=$id.${regname/:/.}.bam.bai

nread=$(samtools view $bam $region | head -n 1 | wc -l)
if [ $nread -ne 1 ]; then
	echo "[slice.sh] empty region found: $regname in $bam"
	set +e
	samtools view -h $bam $region | samtools view -bS - > $obam 2>/dev/null 
	samtools index $obam 
	set -e
	touch $obam.empty
	exit 0
fi

echo "[slice.sh] samtools view -h $bam $region | samtools view -bS - > $obam 2>/dev/null"
samtools view -h $bam $region | samtools view -bS - > $obam 2>/dev/null 
samtools index $obam 

if [ ! -f $obam ] || [ ! -f $obai ]; then
	echo "[slice.sh] *ERROR* failed to write output $obam $obai"
	exit 1
fi




