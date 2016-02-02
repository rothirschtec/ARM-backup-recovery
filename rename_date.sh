#!/bin/bash

for x in $(find part_img/ -type d |grep "2016at")
do 
    dir_name=${x##*/}
    nname=$(sed 's/_2016//g' <<<$dir_name)
    nname=$(sed 's/^/2016_/g' <<<$nname)
    rename 's/'$dir_name'/'$nname'/g' $x
done
for x in $(find part_img/ -type d |grep "2016")
do 
    echo $x
done
