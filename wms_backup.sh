#!/bin/bash 

echo ""
echo "wms Backup tool"
echo "Author: René Zingerle"
echo "Date: 23.11.2017"
echo "Version: 0.12 [BETA]"
echo "Infos: https://blog.rothirsch.tech/wms_backup/"
echo "---------------------"


# # #
# Check dependencies
    check_dependencies() {

        # # #
        # Checks dependencies and tries to install them
        dep=("ntp" "ntpdate" "pv" "uuid-runtime")

        for x in "${dep[@]}"; do
            dpkg-query -W $x &> /dev/null
            if [ $? -eq 1 ]; then
                echo "$x: is not installed"
                apt-get -y install $x
                ni=1
            fi
        done
        return $ni
    }
    check_dependencies
#
# # #


# # #
# Declare variables
    usr=$USER
    prf=1
    dbg=0

    cd $(dirname $0)
    hdir="$PWD/"
    imgfol="${hdir}part_img"

    runID=$(uuidgen)
    tdir=/tmp/wms_backup/${runID}/
    bLog=${tdir}backup.log
    mkdir -p $tdir

    pinfo=${tdir}pinfo.sh
#
# # #


# # #
#
if [[ $usr == "root" ]]; then

    echo ""
    echo "Please insert/reinsert you microSD Card now!"
    read -p "If the system has recognized the card please write (mount): " plugged
    exit=0

    while [ $exit -eq 0 ]; do

        if [[ $plugged == "mount" ]]; then

            if check_dependencies; then
              
                echo "" 
                echo "Choose between following Options: "
                echo "  [1] Complete Backup of the card."
                echo "      (Writes the complete card to the image. The image will have the same size as your card has.)" 

                echo "  [2] Shrink der ROOTfs partition"
                echo "      (Image will have the size of your ROOTfs)"

                read -p "Choose (1/2): " shrink

                if [[ $shrink == "1" ]]; then
                    echo "Command accepted, create Full Backup!"
                elif [[ $shrink == "2" ]]; then
                    echo "Command accepted, create Small Backup!"
                fi

                if [[ $shrink == "1" ]] || [[ $shrink == "2" ]]; then

                    if [ $prf -eq 1 ]; then
                    # Create part_img fol
                        mkdir -p ${imgfol}
                    fi
                    
                    if [ $prf -eq 1 ]; then
                    # Show devices
                        i=0
                        while read p
                        do
                            if [ $i -ne 0 ]; then
                                devices[$i]=$p
                                echo "[$i] ${devices[$i]}"
                            else
                                part[$i]="Disk Array"
                            fi
                            ((i++))
                        done < <(lsblk -d -o NAME)
                        read -p "Choose your backup device [0-9]: " ddec

                        ls -R ${imgfol}/ | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\// /g' -e 's/^/ /'
                        read -p "Name of the backup directory: " bak_fol
                        NOW=${bak_fol}/$(date +"%Y_%m_%dat%H_%M_%S")
                        mkdir -p ${imgfol}/$NOW

                    fi
    

                    if [[ $shrink == "2" ]]; then

                        echo ""
                        echo "MBR Backup" 
                        dd if=/dev/${devices[$ddec]} of=${imgfol}/$NOW/mbr.bin bs=100M count=1

                    # # #
                    # Find partition size in byte
                        if [ $prf -eq 1 ]; then

                            i=0
                            part[$i]="Part Array"       
                                # @param part: Array for partitions
                            psize[$i]="Partition Sizes" 
                                # @param psize: Array for partition size

                            echo ""
                            echo "Find partition size and sectors..."

                            while read p # Runs through all devices
                            do
                    
                                if [[ $p == *${devices[$ddec]}* ]] && [[ $p != *${devices[$ddec]} ]]; then
                                    ((i++))
                                    part[$i]=$p

                        # Find Size
                                    psize[$i]="$(parted /dev/${devices[$ddec]} unit s print | tail -$((1+$i)) | awk '{print $4}')"
                                    psize[$i]=$(sed 's/s//g' <<<${psize[$i]})

                        # Find start sector of the partition
                                    starsec[$i]="$(parted /dev/${devices[$ddec]} unit s print | tail -$((1+$i)) | awk '{print $2}')"
                                    starsec[$i]=$(sed 's/s//g' <<<${starsec[$i]})
                    
                        # Umount mounted partitions
                                    if mountpoint -q /dev/${part[$i]} &> /dev/null; then
                                        echo "${part[$i]} is mounted, trying to umount..."
                                        umount /dev/${part[$i]} &> /dev/null
                                    elif mount -l | grep /dev/${part[$i]} &> /dev/null; then
                                        echo "${part[$i]} is mounted, trying to umount..."
                                        umount /dev/${part[$i]} &> /dev/null
                                    fi

                        # Find label name
                                    plabel[$i]=$(awk -F'"' '{print $2;}' <<< $(awk '{print $2;}' <<< $(blkid /dev/${part[$i]})))

                                
                                fi

                            done < <(lsblk -l -o NAME /dev/${devices[$ddec]})

                        fi
                    #
                    # # #

                    # # #
                    # Show possible decisions
                        if [ $prf -eq 1 ]; then

                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo "[$x] ${part[$x]} with "
                                    echo "      Label: ${plabel[$x]}"
                                    echo "      and a sector size of: ${psize[$x]}"
                                    echo ""
                                fi
                            done
                            read -p "Which one is the ROOTfs? [1-$(bc -l <<< "$x - 1")]: " pdec
                        fi
                    #
                    # # #


                    # # #
                    # Create image structure for later recovery
                        if [ $prf -eq 1 ]; then
                            i=0
                            c=0
                            p=1
                            parted /dev/${devices[$ddec]} unit s print free > ${pinfo}.orig

                            parted /dev/${devices[$ddec]} unit s print free |awk '{print $1, $2, $3, $4, $5, $6}' |grep [0-9]s | while read x 
                            do
                                case $i in
                                0)
                                    echo "csize=\"$(echo $x |awk '{print $3}')\"" > ${pinfo}
                                    ;;
                                *)
                                    type=$(echo $x |awk '{print $4}')
                                    if [[ $type == "Free" ]]; then
                                        echo "opsize[$c]=\"Free;$(echo $x | awk 'BEGIN { FS=" "; OFS=";"; } {print $1,$2,$3}')\"" >> ${pinfo}
                                    else
                                        echo "opsize[$c]=\"P$p;$(echo $x | awk 'BEGIN { FS=" "; OFS=";"; } {print $2,$3,$4}')\"" >> ${pinfo}
                                        ((p++))
                                    fi
                                    ((c++))
                                  ;;
                                esac
                                ((i++))
                            done
                            source ${pinfo}
                        fi
                    #
                    # # #
                    

                    # # #
                    # Shrink partition to ROOTfs size
                        if [ $prf -eq 1 ]; then

                            echo ""
                            echo "Check filesystem..."
                            e2fsck -f -y /dev/${part[$pdec]} >> $bLog

                            echo ""
                            echo "Shrink filesystem ${part[$pdec]}... "
                            resize2fs -M /dev/${part[$pdec]}  >> $bLog

                            rbc=$(tune2fs -l /dev/${part[$pdec]} | grep "Block count" | tail -1)
                            bsz=$(tune2fs -l /dev/${part[$pdec]} | grep "Block size" | tail -1)
                            rbc=${rbc##* }
                            bsz=${bsz##* }
                            ((psizadd=(${rbc}*${bsz})/1000))

                            echo "Shrink partition size: ${part[$pdec]}..."
                            (echo d; echo $pdec; echo n; echo p; echo $pdec; echo ${starsec[$(bc -l <<< "${pdec} - 1")]} ; echo +${psizadd}K; echo w) | fdisk /dev/${devices[$ddec]} >> $bLog

                            echo "Check the filesystem again..."
                            e2fsck -f -y /dev/${part[$pdec]} >> $bLog

                        fi
                    # # # #

                    fi

                    # Sichern der Partitionen
                    if [ $prf -eq 1 ]; then

                        if [[ $shrink == "2" ]]; then
                            echo "Partition backup..."
                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo ""
                                    echo "Backup ${part[$x]}..."
                                    echo "Please be patient!..."
                                    pv -tpreb /dev/${part[$x]} | dd bs=4M | gzip -c -9 > ${imgfol}/$NOW/p${x}_wms.img.gz && sync
                                fi
                            done
                            echo "Partition" > ${imgfol}/$NOW/type.txt
                        elif [[ $shrink == "1" ]]; then
                            echo "Backup the complete filesystem..."
                            echo "Please be patient..."
                            pv -tpreb /dev/${devices[$ddec]} | dd bs=4M | gzip -c -9 > ${imgfol}/$NOW/complete_wms.img.gz && sync
                            echo "Complete" > ${imgfol}/$NOW/type.txt
                        fi
                        echo ""
                    fi


                    if [[ $shrink == "2" ]]; then
                        # Resize des ROOTfs
                        if [ $prf -eq 1 ]; then

                            echo "Resize partition /dev/${part[$pdec]} to maximum"
                            echo "Check the filesystem..."
                            e2fsck -f -y -C 0 /dev/${part[$pdec]} &> /dev/null

                            echo "Resize filesystem to maximum..."
                            (echo d; echo $pdec; echo n; echo p; echo $pdec; echo ${starsec[$(bc -l <<< "${pdec} - 1")]} ; echo ; echo w) | fdisk /dev/${devices[$ddec]} >> $bLog
                            resize2fs /dev/${part[$pdec]} 

                            echo "Check the filesystem..."
                            e2fsck -f -y -C 0 /dev/${part[$pdec]} &> /dev/null
                        fi
    
                        # Copy files
                        if [ $prf -eq 1 ]; then
                            mv ${pinfo} ${imgfol}/$NOW/
                            mv ${pinfo}.orig ${imgfol}/$NOW/
                        fi

                    fi

                    # Write comment 
                    if [ $prf -eq 1 ]; then

                        i=0
                        read -p "Do you wanna write a comment? (y/n): " cdec
                        while [ $i -eq 0  ]; do
                            if [[ $cdec == "y" ]]; then
                                read -p "Oneline or vim comment? (o/v): " edec
                                j=0
                                while [ $j -eq 0  ]; do
                                    if [[ $edec == "v" ]]; then
                                        vi ${imgfol}/$NOW/comment.txt
                                        j=1
                                    elif [[ $edec == "o" ]]; then
                                        read -p "Comment: " comment
                                        echo $comment > ${imgfol}/$NOW/comment.txt
                                        j=1
                                    else
                                        read -p "Parameter not allowed. Choose between (o)ne line or (v)i!: " edec
                                        j=0
                                    fi
                                done
                                i=1
                            elif [[ $cdec == "n" ]]; then
                                echo "Option: No comment!"
                                echo "Option: No comment!" > ${imgfol}/$NOW/comment.txt
                                i=1
                            else
                                read -p "Choose between (y)es or (n)o!: " cdec
                                i=0
                            fi
                        done

                    if [[ $shrink == "2" ]]; then

                        echo ""
                        echo "Partition backup successfully ends..."
                    elif [[ $shrink == "1" ]]; then
                        echo ""
                        echo "Full backup successfully ends..."
                    fi
                            
                    fi

                # End script on wrong input
                else
                    echo "Choose between (y)es or (n)o"         
                fi
            
            # End script on missing dependencies
            else
                echo ""
                echo "-- ! Please install the dependencies --"
            fi

        exit=1
        # End script if device has no mount state
        else
            echo ""
            read -p "Parameter not allowed. Please use (mount) or (exit): " plugged
        fi
        if [[ $plugged == "exit" ]]; then
            echo ""
            echo "Script ends."
            exit=1
        fi
    done

# End script if not executed by root
else
    echo "The script has to be executed as root."
fi
