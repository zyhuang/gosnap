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

# This script is a patch to cope with the inconsistency between the sample id
# as present in the BAM filename and SM field in the BAM header.

import sys
import subprocess

# gSNAP specific predefinition:
samtools = "/usr/bin/samtools/samtools"

def run_with_retry(cmd, max_retry):
	i = 0
	return_code = 1
	while i <= max_retry and return_code != 0:
		print(':' if i == 0 else "Retry {} of {}:".format(i, max_retry), cmd)
		return_code = subprocess.call(cmd, shell=True)
		i += 1
	if return_code != 0:
		sys.exit('*ERROR*: max number of retry ({}) reached, failed command {}'.format(max_retry, cmd))
	return return_code

# first argument is the bam path (the only 1 argument)
bam = sys.argv[1]

# sample_id is the first "." separated field
sample_id = bam.split('/')[-1].split('.')[0]

# check lines with "SM:sample_id"
check_cmd = "{} view -H {} | awk \'match($0,\"\\tSM\")\' | grep -v \"SM:{}\"".format(samtools, bam, sample_id)
check = subprocess.Popen(check_cmd, shell=True, stdout=subprocess.PIPE)
n = len(check.stdout.read())

# if already contains "SM:sample_id", do nothing
if n == 0:
	exit(0)

print("*WARNING*: mismatch between sample name and SM tag in BAM {}, fixing ...".format(bam))

changesm_cmd = "{} view -H {}".format(samtools, bam)
new_header = bam+".header.txt"
hfile = open(new_header, "w")

for line in subprocess.Popen(changesm_cmd, shell=True, stdout=subprocess.PIPE).stdout:
	line = line.decode('UTF-8').strip()
	if "SM:" not in line:
		hfile.write(line + '\n')
		continue
	data = line.split('\t')
	for i in range(len(data)):
		if data[i][:3] == "SM:":
			data[i] = "SM:{}".format(sample_id)
	hfile.write('\t'.join(data) + '\n')

hfile.close()

# replace header
temp_bam = bam[:-4] + ".reheaded.bam"
replace_cmd = "{} reheader {} {} > {}".format(samtools, new_header, bam, temp_bam)
run_with_retry(replace_cmd, 10)

# clean up steps
clean_up = "mv {} {}; {} index {}; rm {}".format(temp_bam, bam, samtools, bam, new_header)
run_with_retry(clean_up, 10)
