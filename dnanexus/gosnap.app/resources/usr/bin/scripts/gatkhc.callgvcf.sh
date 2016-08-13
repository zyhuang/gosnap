#!/bin/bash

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

# input CSV string:
# bam, ref, mem (per core), odir
# output:
# $odir/$bam_file_id.gvcf.gz.tbi

datain=$1

bam=$(echo $datain | cut -d\, -f 1)
ref=$(echo $datain | cut -d\, -f 2)
mem=$(echo $datain | cut -d\, -f 3)
odir=$(echo $datain | cut -d\, -f 4)

region=$(basename $bam | awk -F\. '{print $(NF-2)":"$(NF-1)}')
ogvcf=$odir/$(basename $bam | sed 's/.bam/.gvcf/g')
olog=$odir/$(basename $bam | sed 's/.bam/.log/g')

# Default 
gatk=/usr/bin/gatk/GenomeAnalysisTK.jar
bgzip=/usr/bin/tabix/bgzip
tabix=/usr/bin/tabix/tabix

nct=1
echo "calling GVCF output $ogvcf.gz"
java -Xmx${mem}g -jar $gatk -T HaplotypeCaller -ERC GVCF -R $ref \
	-variant_index_type LINEAR \
	-variant_index_parameter 128000 \
	--max_alternate_alleles 16 \
	-stand_emit_conf 10 \
	-mbq 10 \
	-nct $nct \
	-I $bam \
	-L $region \
	-o $ogvcf &> $olog

# compress and index
$bgzip -f $ogvcf
$tabix -fp vcf $ogvcf.gz





