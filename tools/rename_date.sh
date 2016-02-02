#!/bin/bash

for year in 2015 2016
do
    for x in $(find ../part_img/ -type d |grep "${year}at")
    do 
        dir_name=${x##*/}
        nname=$(sed 's/_'${year}'//g' <<<$dir_name)
        nname=$(sed 's/^/'${year}'_/g' <<<$nname)
        rename 's/'$dir_name'/'$nname'/g' $x
    done
    for x in $(find part_img/ -type d |grep "'${year}'")
    do 
        echo $x
    done
done
