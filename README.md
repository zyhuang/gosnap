# goSNAP

goSNAP is a high performance ensemble variant calling pipeline designed for large scale variant calling using next generation sequencing data. It employs multiple variant callers (currently including SNPTools, GATK-HaplotypeCaller, GATK-UnifiedGenotyper and GotCloud for SNP calling) in joint calling mode across thousands to millions of samples. It is highly scalable and can be deployed to different cloud computing platforms (current release includes the DNAnexus version).


## Installation

To build the goSNAP App `gosnap.app` for DNAnexus platform, you need to install the [DNAnexus Platform SDK]. Once `dx-toolkit` is installed, you can build the applications with

```bash
git clone https://github.com/zyhuang/gosnap.git gosnap
cd gosnap/dnanexus/gosnap.app
dx cd $dx_project_name:
dx build -f -d $dx_project_name:$path_to_install/gosnap
```
`slice.app` and `repack.app` can be built in a similar fashion.

[DNAnexus Platform SDK]: https://wiki.dnanexus.com/Downloads

## Usage

Given the path to the input tarball of BAM files located in a DNAnexus project, which is generated using ``slice.app`` and ``repack.app``, and the path to the human reference genome tarball, you may run goSNAP variant calling with

```bash
dx run $dx_project_name:$path_to_install/gosnap -idxSliceBamTar=$dx_data_project:$path_to_bam_data/sliced_bams.tar.gz -idxRefGenTar=$dx_data_project:$path_to_ref_gen/ref_fasta.tar.gz
```
The outputs files are configured in the JSON file ``dnanexus/gosnap.app/dxapp.json`` (defined with ``outputSpec`` key).






## Authors

goSNAP was developed by Zhuoyi Huang, designed by Fuli Yu, Zhuoyi Huang and Navin Rustagi at Baylor College of Medicine, Human Genome Sequencing Center.



## License

For non-commercial use, goSNAP is released under Apache 2.0 License.
For commercial use, please contact [Fuli Yu]. Please see ``LICENSE`` for details.

[Fuli Yu]: fyu@bcm.edu


## History

DNAnexus version of goSNAP package (including the slice and repack pre-reduction applications) were released on May 6, 2015 (see also https://sourceforge.net/projects/gosnap/).

## How to cite

Zhuoyi Huang, Navin Rustagi, Narayanan Veeraraghavan, Andrew Carroll, Richard Gibbs, Eric Boerwinkle, Manjunath Gorentla Venkata, Fuli Yu.
*A hybrid computational strategy to address WGS variant analysis in >5000 samples.* [[BMC Bioinformatics 17 (1), 361]]

[BMC Bioinformatics 17 (1), 361]: http://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-016-1211-6


## References

##### GATK
DePristo M, Banks E, Poplin R, Garimella K, Maguire J, Hartl C, Philippakis A, del Angel G, Rivas MA, Hanna M, McKenna A, Fennell T, Kernytsky A, Sivachenko A, Cibulskis K, Gabriel S, Altshuler D, Daly M. *A framework for variation discovery and genotyping using next-generation DNA sequencing data.*   Nature Genetics, 2011, 43:491-498. [[PMID: 21478889]]

##### GotCloud
Jun G, Wing MK, Abecasis GR, Kang HM. *An efficient and scalable analysis framework for variant extraction and refinement from population-scale DNA sequence data.* Genome Research, 2015, Jun 1;25(6):918-25. [[PMID: 25883319]]

##### Samtools
Li H., Handsaker B., Wysoker A., Fennell T., Ruan J., Homer N., Marth G., Abecasis G., Durbin R. and 1000 Genome Project Data Processing Subgroup (2009) *The Sequence alignment/map (SAM) format and SAMtools.* Bioinformatics, 2009, 25, 2078-9. [[PMID: 19505943]]

##### SNPTools
Wang Y, Lu J, Yu J, Gibbs RA, Yu F. *An integrative variant analysis pipeline for accurate genotype/haplotype inference in population NGS data.* Genome Research, 2013, May 1;23(5):833-42. [[PMID: 23296920]]

[PMID: 21478889]: http://www.ncbi.nlm.nih.gov/pubmed/21478889
[PMID: 25883319]: http://www.ncbi.nlm.nih.gov/pubmed/25883319
[PMID: 19505943]: http://www.ncbi.nlm.nih.gov/pubmed/19505943
[PMID: 23296920]: http://www.ncbi.nlm.nih.gov/pubmed/23296920

