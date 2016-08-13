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

# input (CSV without space): 	id, reglist, group-id

line=$1

id=$(echo $line | cut -d\, -f1)
regList=$(echo $line | cut -d\, -f2)
i=$(echo $line | cut -d\, -f3)

files=$(awk 'NR>=1+'$i'*10 && NR<=1+'$i'*10+9' $regList | cut -d\, -f1 | sed 's/:/./g' | awk '{printf("slice/'$id'.%s.* ",$1)}')
otar=$id.slicebin.$i.tar.gz
echo "[tar10.sh] tar czf $otar $files; rm $files"
tar czf $otar $files
rm $files


