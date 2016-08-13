#!/bin/bash -ex

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
# 	dxSliceBamTar, dxRefGenTar, dxRefGenChrTar
# output:
# 	snptoolsVcfTar, snptoolsByprodTar,
# 	gotcloudVcfTar, gotcloudByprodTar,
# 	gatkgvcfVcfTar, gatkgvcfByprodTar,
# 	gatkugVcfTar


main () {

	# determine number of threads to use
	ncpu=$(lscpu | grep ^CPU\( | awk '{print $NF}')
	ncore=$(lscpu | grep ^Thread | awk '{print $NF}')
#	nthread=$[$ncpu*$ncore]
	nthread=$[$ncpu]					# use 1 thread per core to prevent low memory per thread (~2GB/thread)
	mem=$(grep MemTotal /proc/meminfo | awk '{print int($2/1000/1000)}')
	echo "ncpu = $ncpu, ncore = $ncore, nthread = $nthread, mem = $mem"

	# start job
	home=/mnt
	cd $home

	echo "========== INPUT =========="
	echo "sliced BAMs tarball: '${dxSliceBamTar}'"
	echo "reference genome tarball: '${dxRefGenTar}'"
	echo "reference genome tarball (by chrom): '${dxRefGenChrTar}'"

	# resolve input filename
	sliceBamTar=$home/$(dx describe "${dxSliceBamTar}" --name)
	echo "sliceBamTar = $sliceBamTar"
	refGenTar=$home/$(dx describe "${dxRefGenTar}" --name)
	echo "refGenTar = $refGenTar"
	refGenChrTar=$home/$(dx describe "${dxRefGenChrTar}" --name)
	echo "refGenChrTar = $refGenChrTar"
	chrom=$(basename $sliceBamTar | cut -d\. -f 1)						# e.g. 16
	region=$(basename $sliceBamTar | cut -d\. -f 1,2 | sed 's/\./:/g')	# e.g. 16:000003300001-000004300000

	# download input files
	echo "download sliceBamTar = $sliceBamTar"
	time dx download "${dxSliceBamTar}" -o "${sliceBamTar}" --no-progress
	echo "download refGenTar = $refGenTar"
	time dx download "${dxRefGenTar}" -o "${refGenTar}" --no-progress
	echo "download refGenChrTar = $refGenChrTar"
	time dx download "${dxRefGenChrTar}" -o "${refGenChrTar}" --no-progress
	ls -l

	# decompress the reference files
	echo "tar xzf $refGenTar"
	tar xzf $refGenTar
	refGen=$home/human.g1k.v37.fa
	if [ ! -f $refGen ]; then
		echo "*ERROR*: $refGen not found!"
		exit 1
	fi
	echo "reference genome file: $refGen"
	echo "rm $refGenTar"
	rm $refGenTar

	echo "tar xzf $refGenChrTar"
	tar xzf $refGenChrTar
	refGenChr=$home/$chrom.fa
	if [ ! -f $refGenChr ]; then
		echo "*ERROR*: $refGenChr not found!"
		exit 1
	fi
	echo "reference genome file (by chrom): $refGenChr"
	echo "rm $refGenChrTar"
	rm $refGenChrTar

	# decompress the sliced BAMs
	bamdir=$home/bams
	mkdir -p $bamdir
	cd $bamdir
	echo "tar xzf $sliceBamTar"
	tar xzf $sliceBamTar
	cd ..
	bamlist=$home/bams.list
	find $bamdir -name "*.bam" > $bamlist
	nbam=$(cat $bamlist | wc -l)
	nbai=$(find $bamdir -name "*.bai" | wc -l)
	# check number of BAMs and BAIs
	echo "nbam = $nbam nbai = $nbai"
	if [ $nbam -ne $nbai ];  then
		echo "*ERROR*: nbam = $nbam, nbai = $nbai, quit."
		exit 1
	fi
	echo "rm $sliceBamTar"
	rm $sliceBamTar

	# FIX(2014-12-02): check if SM tag in the BAM is the same as the sample name in the BAM file name and update if inconsistent
	t1=$(date +%s)
	echo "cat $bamlist | xargs -n1 -P $nthread python3.2 /usr/bin/scripts/samtools.bamsubsm.py"
	cat $bamlist | xargs -n1 -P $nthread python3.2 /usr/bin/scripts/samtools.bamsubsm.py
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::: BAM SM tag update done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"



	# ===========================================================================================================
	# SNPTools
	# ===========================================================================================================

	# prepare pileup dir
	ebddir=$home/ebds
	mkdir -p $ebddir
	cd $ebddir

	# run pileup.sh (skip bams with no coverage)
	t1=$(date +%s)

	echo "cat $bamlist | xargs -n1 -P $nthread /usr/bin/scripts/snptools.pileup.xargs"
   	cat $bamlist | xargs -n1 -P $nthread /usr/bin/scripts/snptools.pileup.xargs

	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::: SNPTOOLS Pileup done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	cd ..

	# check empty bams
	nbam_empty=$(find $bamdir -name "*.bam.empty" | wc -l)
	echo "::: Number of empty BAMs = $nbam_empty :::"
	if [ $nbam_empty -eq $nbam ]; then
	   	echo "*ERROR*: ALL BAMs are empty. Quit now."
		exit 0
	fi

	# make EBD list
	ebdlist=$home/ebds.list
	find $ebddir -name "*.ebd" > $ebdlist
    nebd=$(cat $ebdlist | wc -l)
	nebi=$(find $ebddir -name "*.ebi" | wc -l)
	# check number of EBDs and EBIs
	echo "nebd = $nebd  nebi = $nebi  nbam = $nbam  nbai = $nbai"
	if [ $nebd -ne $nebi ];  then
		echo "*ERROR*: nebd = $nebd, nebi = $nebi, quit."
		exit 1
	fi
	if [ $nebd -ne $nbam ];  then
		echo "*WARNING*: nebd = $nebd, nbam = $nbam, $[nbam-nebd] BAMs have no coverage."
	fi

	# call SNP using varisite
	ovcf=${region/:/.}.$nebd.bams.sites.vcf			# 16.000003300001-000004300000.3291.bams.sites.vcf

	# run varisite
	t1=$(date +%s)
	echo "/usr/bin/snptools/varisite -s 0 -g 32 $ebdlist $chrom $refGenChr"
	/usr/bin/snptools/varisite -s 0 -g 32 $ebdlist $chrom $refGenChr
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::: SNPTOOLS Varisite done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	# filter the marginal regions (keep only the calling region)
	istart=$(echo $region | sed 's/:/-/g' | cut -d'-' -f 2)
	iend=$(echo $region | sed 's/:/-/g' | cut -d'-' -f 3)
	echo "keep SNPs in region [$istart, $iend]"
	awk '/^#/ || ($2>='$istart' && $2<='$iend')' $chrom.sites.vcf > $ovcf
	rm $chrom.sites.vcf
	ls -l
	echo "SNP sites vcf = $ovcf"
	echo "::: number of variants in $ovcf = $(grep -vc ^# $ovcf)"

	# compress and index
	echo "/usr/bin/tabix/bgzip -f $ovcf; /usr/bin/tabix/tabix -f $ovcf.gz"
	/usr/bin/tabix/bgzip -f $ovcf
	/usr/bin/tabix/tabix -f $ovcf.gz

	# crate VCF tarball
	ovcfTar=snptools.${region/:/.}.$nebd.bams.sites.vcf.tar.gz
	echo "tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi"
	time tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi

	# create EBD+EBI tarball
	cd $home
	oebdTar=snptools.${region/:/.}.$nebd.ebds.tar.gz
	echo "tar czf $oebdTar ebds/*.ebd ebds/*.ebi"
	time tar czf $oebdTar ebds/*

	# upload outputs
	echo "upload $ovcfTar"
	oid=$(time dx upload $ovcfTar --brief)
    dx-jobutil-add-output snptoolsVcfTar "$oid" --class=file
	echo "upload $oebdTar"
	oid=$(time dx upload $oebdTar --brief)
    dx-jobutil-add-output snptoolsByprodTar "$oid" --class=file

	# cleanning
	rm -r $ebddir $ebdlist $ovcfTar $ovcf.gz $ovcf.gz.tbi $oebdTar 
	ls

	# ===========================================================================================================
	# GotCloud
	# ===========================================================================================================

	gcbin=/usr/bin/gotcloud
	gcsrc=/usr/src

	# =========================== glf pileup ===========================

	# glf pileup
	glfdir=$home/glfs
	mkdir -p $glfdir
	echo "running GotCloud glf pileup"

	t1=$(date +%s)
	awk -v refgen=$refGen -v region=$region -v glfdir=$glfdir '{n=split($1,a,"/");split(a[n],b,"."); OFS=",";print refgen,b[1],$1,region,glfdir}' $bamlist | \
		xargs -n1 -P${nthread} /usr/bin/scripts/gotcloud.pileup.sh
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::: GOTCLOUD glf pileup finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	# make glf index file (.ped)
	glflist=$glfdir/glfindex.ped
	echo "making glf index file $glflist"
	find $glfdir -name "*.glf" | sort | awk -F\/ '{split($NF,a,".");OFS="\t";print a[1],a[1],"0","0","2",$0}' > $glflist
	nglf=$(cat $glflist | wc -l)
	echo "nglf = $nglf"
	if [ $nglf -ne $nbam ] ;  then
		echo "*ERROR*: nglf = $nglf, nbam = $nbam, quit."
		exit 1
	fi

	# =========================== glf SNP calling ===========================

	# prepare for SNP calling
	vcfdir=$home/vcf
	mkdir -p $vcfdir
	allvcf=$vcfdir/${region/:/.}.$nbam.bams.vcf
	allvcfsite=${allvcf%.vcf}.sites.vcf

	# call SNP using glfMultiples
	t1=$(date +%s)
	echo "${gcbin}/glfMultiples --minMapQuality 0 --minDepth 1 --maxDepth 1000000000 --uniformTsTv --smartFilter --ped $glflist -b $allvcf > $allvcf.log 2> $allvcf.err"
	${gcbin}/glfMultiples --minMapQuality 0 --minDepth 1 --maxDepth 1000000000 --uniformTsTv --smartFilter --ped $glflist -b $allvcf > $allvcf.log 2> $allvcf.err
	# cat $allvcf.log $allvcf.err
	echo "cut -f 1-8 $allvcf > $allvcfsite"
	cut -f 1-8 $allvcf > $allvcfsite
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "::: GOTCLOUD glfMultiples finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	nsnp=$(grep -vc ^# $allvcfsite)
	echo "::: number of SNPs called $nsnp"
	if [ $nsnp -eq 0 ]; then
		echo "*ERROR*: no SNP called in region $region, quit"
		exit 1
	fi

	# =========================== vcf pileup ===========================

	# collect information in each sample for filtering
	pvcfdir=$home/pvcfs
	mkdir -p $pvcfdir
	echo "running GotCloud vcf pileup"

	t1=$(date +%s)
	awk -v vcf=$allvcfsite -v region=$region -v pvcfdir=$pvcfdir '{n=split($1,a,"/");split(a[n],b,"."); OFS=",";print b[1],$1,vcf,region,pvcfdir}' $bamlist | \
		xargs -n1 -P${nthread} /usr/bin/scripts/gotcloud.vcfpileup.sh
	t2=$(date +%s)
	dt=$[t2-t1]
	echo ":: GOTCLOUD vcf pileup finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	# count number of pvcfs
	pvcflist=$home/pvcfs.list
	echo "making pileupvcf list $pvcflist"
	find $pvcfdir -name "*.vcf.gz" | sort > $pvcflist
	npvcf=$(cat $pvcflist | wc -l)
    echo "npvcf = $npvcf"
    if [ $npvcf -ne $nbam ] ;  then
        echo "*ERROR*: npvcf = $npvcf, nbam = $nbam, quit."
        exit 1
    fi


	# =========================== collect site statistics ===========================

	# prepare for stat.vcf (bam.index format: id\tfoo\tid)
	bamidx=$pvcfdir/bams.index
	echo "making $bamidx for infoCollector"
	awk '{n=split($1,a,"/");split(a[n],b,"."); OFS="\t";print b[1],"foo",b[1]}' $bamlist > $bamidx

	# make stat.vcf
	allvcfstat=${allvcf%.vcf}.stats.vcf
	echo "making stat.vcf"
	t1=$(date +%s)
	${gcbin}/infoCollector --anchor $allvcf --prefix "$pvcfdir/" --suffix ".${region/:/.}.vcf.gz" \
		--outvcf $allvcfstat --index $bamidx > $allvcfstat.log 2> $allvcfstat.err
	# cat $allvcfstat.log $allvcfstat.err
	t2=$(date +%s)
	dt=$[t2-t1]
	echo ":: statvcf finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"

	# check output statvcf
    nstat=$(grep -vc ^# $allvcfstat)
    echo "nstat = $nstat"
    if [ $nstat -ne $nsnp ] ;  then
        echo "*ERROR*: nstat = $nstat, nsnp = $nsnp, quit."
        exit 1
    fi

	# =========================== hard filtering ===========================
	# golden datasets
	indelvcf=$gcsrc/1kg.pilot_release.merged.indels.sites.hg19.chr$chrom.vcf
	tgvcf=$gcsrc/1000G_omni2.5.b37.sites.PASS.vcf.gz
	hapmapvcf=$gcsrc/hapmap_3.3.b37.sites.vcf.gz
	dbsnpvcf=$gcsrc/dbsnp_135.b37.vcf.gz

	if [ ! -f $indelvcf ] || [ ! -f $tgvcf ] || [ ! -f $hapmapvcf ] || [ ! -f $dbsnpvcf ]; then
		echo "*ERROR*: some calibration VCFs not found in $gcsrc: $indelvcf $tgvcf $hapmapvcf $dbsnpvcf"
		ls $gcsrc
		exit 1
	fi

	# apply hard filter
	hdfvcf=${allvcf%.vcf}.hard.vcf.gz
	hdfvcfsite=${allvcf%.vcf}.hard.sites.vcf

	maxDP=$[nbam*1000]
	minDP=$[nbam]
	minNS=$[nbam/2]
	echo "applying hard filter, output = $hdfvcfsite"
	${gcbin}/vcfCooker --write-vcf --filter --maxDP $maxDP --minDP $minDP --minNS $minNS --maxABL 65 --maxAOI 5 --maxCBR 10 --maxLQR 20 --maxMQ0 10 \
		--maxSTR 10 --maxSTZ 10 --minFIC -10 --minMQ 20 --minQual 5 --minSTR -10 --minSTZ -10 --winIndel 5 \
		--indelVCF $indelvcf --in-vcf $allvcfstat --out $hdfvcfsite  > $hdfvcfsite.log 2> $hdfvcfsite.err
	# cat $hdfvcfsite.log $hdfvcfsite.err

	# check output hard filtered sites
    nrec=$(grep -vc ^# $hdfvcfsite)
    echo "in $hdfvcfsite nrec = $nrec"
    if [ $nrec -ne $nsnp ] ;  then
        echo "*ERROR*: in $hdfvcfsite nrec = $nrec, but nsnp = $nsnp, quit."
        exit 1
    fi

	echo "stitch $hdfvcfsite with $allvcf, output = $hdfvcf"
	perl ${gcbin}/scripts/vcfPaste.pl $hdfvcfsite $allvcf | /usr/bin/tabix/bgzip -c > $hdfvcf
	/usr/bin/tabix/tabix -f -pvcf $hdfvcf

	# write hard filter summary
	echo "summarize hard filter quality"
	perl ${gcbin}/scripts/vcf-summary --vcf $hdfvcfsite --ref $refGen --dbsnp $dbsnpvcf --FNRvcf $hapmapvcf --chr $chrom \
		--tabix /usr/bin/tabix/tabix > $hdfvcfsite.summary 2> $hdfvcfsite.summary.err
	# cat $hdfvcfsite.summary $hdfvcfsite.summary.err


	# =========================== SVM filtering ===========================

	# apply SVM filter
	svmvcf=${allvcf%.vcf}.svm.vcf.gz
	svmvcfsite=${allvcf%.vcf}.svm.sites.vcf

	echo "applying SVM filter, output = $svmvcfsite"
	perl ${gcbin}/scripts/run_libsvm.pl --invcf $hdfvcfsite --out $svmvcfsite --pos 100 --neg 100 \
	    --svmlearn ${gcbin}/svm-train --svmclassify ${gcbin}/svm-predict --bin ${gcbin}/invNorm --threshold 0 \
	    --bfile $tgvcf --bfile $hapmapvcf --checkNA > $svmvcfsite.log 2> $svmvcfsite.err
	# cat $svmvcfsite.log $svmvcfsite.err

	# check output SVM filtered sites
    nrec=$(grep -vc ^# $svmvcfsite)
    echo "in $svmvcfsite nrec = $nrec"
    if [ $nrec -ne $nsnp ] ;  then
        echo "*ERROR*: in $svmvcfsite nrec = $nrec, but nsnp = $nsnp, quit."
        exit 1
    fi

	echo "stitch $svmvcfsite with $allvcf, output = $svmvcf"
	perl ${gcbin}/scripts/vcfPaste.pl $svmvcfsite $allvcf | /usr/bin/tabix/bgzip -c > $svmvcf
	/usr/bin/tabix/tabix -f -pvcf $svmvcf

	# write SVM filter summary
	echo "summarize SVM filter quality"
	perl ${gcbin}/scripts/vcf-summary --vcf $svmvcfsite --ref $refGen --dbsnp $dbsnpvcf --FNRvcf $hapmapvcf --chr $chrom \
		--tabix /usr/bin/tabix/tabix > $svmvcfsite.summary 2> $svmvcfsite.summary.err
	# cat $svmvcfsite.summary $svmvcfsite.summary.err

	# =========================== compress output ===========================
	/usr/bin/tabix/bgzip -f $allvcf
	/usr/bin/tabix/tabix -f -pvcf $allvcf.gz

	# --------------------------------------------------------------------------------
	# end of GotCloud calling
	# --------------------------------------------------------------------------------

	# create VCF tarball
	cd $home
	ovcfTar=gotcloud.${region/:/.}.$nbam.bams.vcf.tar.gz
	echo "tar czf $ovcfTar vcf"
	time tar czf $ovcfTar vcf

	# create glf and pvcf tarball
	cd $home
	oauxTar=gotcloud.${region/:/.}.$nbam.bams.aux.tar.gz
	echo "tar czf $oauxTar glfs pvcfs"
	time tar czf $oauxTar glfs pvcfs

	# upload outputs
	echo "upload $ovcfTar"
	oid=$(time dx upload $ovcfTar --brief)
    dx-jobutil-add-output gotcloudVcfTar "$oid" --class=file

	echo "upload $oauxTar"
	oid=$(time dx upload $oauxTar --brief)
    dx-jobutil-add-output gotcloudByprodTar "$oid" --class=file	

	# cleanning
	rm -r $glfdir $vcfdir $pvcfdir $pvcflist $ovcfTar $oauxTar
	ls

	# ================================================================================
	# GATK GVCF
	# ================================================================================

	# first calculate memory per thread (GB) for batch gvcf calling
	mem_per_thread=$(echo $mem $nthread | awk '{m=int($1/$2);if(m<1)m=1;print m}')
	gvcfdir=$home/gvcfs
	mkdir -p $gvcfdir

	# call GATK-HC GVCF
	t1=$(date +%s)
	# expected input for callgvcf: /A00018.16.000003300001-000003400000.bam,/mnt/human.g1k.v37.fa,mem_in_gb,gvcf_dir
	echo "awk -v ref=$refGen -v mem=$mem_per_thread -v odir=$gvcfdir '{print \$0\",\"ref\",\"mem\",\"odir}' $bamlist | xargs -n1 -P $nthread /usr/bin/scripts/gatkhc.callgvcf.sh"
	awk -v ref=$refGen -v mem=$mem_per_thread -v odir=$gvcfdir '{print $0","ref","mem","odir}' $bamlist | \
		xargs -n1 -P $nthread /usr/bin/scripts/gatkhc.callgvcf.sh
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "% gvcf calling finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"
	echo "% disk usage $(du -sh)"

	gvcflist=$home/gvcfs.list
	find $gvcfdir -name "*.gvcf.gz" | sort > $gvcflist
    ngvcf=$(cat $gvcflist | wc -l)
	ntbi=$(find $gvcfdir -name "*.gvcf.gz.tbi" | wc -l)
	# check number of GVCFs and TBIs
	echo "ngvcf = $ngvcf ntbi = $ntbi"
	if [ $ngvcf -ne $ntbi ] || [ $ngvcf -ne $nbam ];  then
		echo "*ERROR*: ngvcf = $ngvcf, ntbi = $ntbi, nbam = $nbam, nbai = $nbai, quit."
		exit 1
	fi

	# run gVCF genotyping
	t1=$(date +%s)
	ovcf=${region/:/.}.$nbam.bams.vcf			# 16.000003300001-000004300000.3291.bams.vcf
	gatk=/usr/bin/gatk/GenomeAnalysisTK.jar
	varfiles=$(cat $gvcflist | awk '{printf("--variant %s ",$1)}')
	echo "java -Xmx${mem}g -jar $gatk -R $refGen -T GenotypeGVCFs [--variant gvcfs] -L $region -o $ovcf -log $ovcf.log --max_alternate_alleles 32 -stand_emit_conf 10"
	java -Xmx${mem}g -jar $gatk -R $refGen -T GenotypeGVCFs \
		$varfiles -L $region -o $ovcf -log $ovcf.log --max_alternate_alleles 32 -stand_emit_conf 10
	t2=$(date +%s)
	dt=$[t2-t1]
	echo "% GenotypeGVCFs finished in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"
	ls -l
	echo "output vcf = $ovcf"
	echo "> number of variants in $ovcf = $(grep -vc ^# $ovcf)"

	# compress and index
	echo "/usr/bin/tabix/bgzip -f $ovcf; /usr/bin/tabix/tabix -f $ovcf.gz"
	/usr/bin/tabix/bgzip -f $ovcf
	/usr/bin/tabix/tabix -f $ovcf.gz
	ovcfTar=gatkgvcf.$ovcf.tar.gz
	echo "tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi $ovcf.idx $ovcf.log"
	time tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi $ovcf.idx $ovcf.log

	# create gVCF tarball
	cd $home
	ogvcfTar=gatkgvcf.${region/:/.}.$ngvcf.gvcfs.tar.gz
	echo "tar czf $ogvcfTar gvcfs/*"
	time tar czf $ogvcfTar gvcfs/*

	# upload outputs
	echo "upload $ovcfTar"
	oid=$(time dx upload $ovcfTar --brief)
    dx-jobutil-add-output gatkgvcfVcfTar "$oid" --class=file
	echo "upload $ogvcfTar"
	oid=$(time dx upload $ogvcfTar --brief)
    dx-jobutil-add-output gatkgvcfByprodTar "$oid" --class=file

	# cleaning
	rm -r $gvcfdir $gvcflist $ovcfTar $ovcf.gz $ovcf.gz.tbi $ovcf.log $ovcf.idx $ogvcfTar
	ls

	# ================================================================================
	# GATK UG
	# ================================================================================

	# call GATK-UG
	ovcf=${region/:/.}.$nbam.bams.vcf			# 16.000003300001-000004300000.3291.bams.vcf
	gatk=/usr/bin/gatk/GenomeAnalysisTK.jar

	# for nct and nt, see http://gatkforums.broadinstitute.org/discussion/1975/how-can-i-use-parallelism-to-make-gatk-tools-run-faster
	nct=$nthread
	nt=1

	# turn off error checking (to allow for a number of retries)
	set +e
	t1=$(date +%s)

	# split calling region further by 10 bins to avoid the Heisenbug "Somehow" Bug
	sublist=$home/subregion.list
	subsize=$(echo $region | sed 's/-/ /g;s/:/ /g' | awk '{print int(($3-$2+1)/10)}')
	echo $region | sed 's/-/ /g;s/:/ /g'| awk -v subsize=$subsize '{for(i=$2;i<$3;i+=subsize)printf("%s:%012d-%012d\n", $1, i, ((i+subsize-1)>$3 ? $3 : i+subsize-1))}' | sort > $sublist
	for subregion in $(cat $sublist); do
		maxtry=100
		ecode=1
		ntry=0
		while [ $ecode -ne 0 ] && [ $ntry -lt $maxtry ]; do
			ntry=$[ntry+1]
			echo "subregion = $subregion,  number of retries = $ntry:  java -Xmx${mem}g -jar $gatk -T UnifiedGenotyper -R $refGen -nct $nct -nt $nt -glm BOTH -I $bamlist -L $subregion --max_alternate_alleles 16 -stand_emit_conf 10 -mbq 10 -o sub.${subregion/:/.}.vcf -log sub.${subregion/:/.}.vcf.log"
			java -Xmx${mem}g -jar $gatk -T UnifiedGenotyper -R $refGen \
				-nct $nct -nt $nt \
				-glm BOTH \
				-I $bamlist \
				-L $subregion \
				--max_alternate_alleles 16 \
				-stand_emit_conf 10 \
				-mbq 10 \
				-o sub.${subregion/:/.}.vcf \
				-log sub.${subregion/:/.}.vcf.log
			ecode=$?
		done
		echo "> number of variants in sub.${subregion/:/.}.vcf = $(grep -vc ^# sub.${subregion/:/.}.vcf)"
	done


	t2=$(date +%s)
	dt=$[t2-t1]
	echo "> GATK-UG calling done in $(date -ud @$dt +%j:%T | awk -F\: '{printf("%03d:%02d:%02d:%02d\n",$1-1,$2,$3,$4)}')"
	# turn on error checking
	set -e
	if [ $ecode -ne 0 ]; then
		echo "*ERROR*: GATK-UG exit state $ecode"
		exit $ecode
	fi

	# check output subregion vcfs
	# grep -vc ^# sub.*.vcf
	awk '!/^#/' sub.*.vcf | wc -l
	nvcf_expect=$(cat $sublist | wc -l)
	nvcf_called=$(ls sub.*.vcf | wc -l)
	echo "expected $nvcf_expect subregion VCFs, called $nvcf_called"
	if [ $nvcf_called -ne $nvcf_expect ]; then
		echo "*ERROR*: not all subregions are called!"
		exit 1
	fi

	# cat output subregion VCFs together
	echo "concatenate subregion VCFs"
	for i in $(seq 1 $nvcf_expect); do
		subregion=$(awk 'NR=='$i'' $sublist)
		subvcf=sub.${subregion/:/.}.vcf
		if [ $i -eq 1 ]; then
			echo "cp $subvcf $ovcf"
			cp $subvcf $ovcf
		else
			# echo "grep -v ^# $subvcf >> $ovcf"
			# grep -v ^# $subvcf >> $ovcf
			echo "awk '!/^#/' $subvcf >> $ovcf"
			awk '!/^#/' $subvcf >> $ovcf
		fi
		rm $subvcf $subvcf.idx
	done

	ls -l
	echo "output vcf = $ovcf"
	echo "> number of variants in $ovcf = $(grep -vc ^# $ovcf)"

	# compress and index
	echo "/usr/bin/tabix/bgzip -f $ovcf; /usr/bin/tabix/tabix -f $ovcf.gz"
	/usr/bin/tabix/bgzip -f $ovcf
	/usr/bin/tabix/tabix -f $ovcf.gz
	ovcfTar=gatkug.$ovcf.tar.gz
	echo "tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi sub.*.vcf.log"
	time tar czf $ovcfTar $ovcf.gz $ovcf.gz.tbi sub.*.vcf.log

	# upload outputs
	echo "upload $ovcfTar"
	oid=$(time dx upload $ovcfTar --brief)
    dx-jobutil-add-output gatkugVcfTar "$oid" --class=file

	# cleaning
	rm -r $ovcfTar $ovcf.gz $ovcf.gz.tbi sub.*.vcf.log $sublist
	ls 

	echo "ALL DONE!"

}

