#!/bin/bash

echo ""
echo "wms Recovery Tool"
echo "Author: René Zingerle"
echo "Date: 23.11.2017"
echo "Version: 0.12 [BETA]"
echo "Infos: https://blog.rothirsch.tech/wms_backup/"
echo "---------------------"

usr=$USER
prf=1
dbg=0
imgfol="part_img"

# Get script directory
cd $(dirname $0)
sdir="$PWD/"

if [ $dbg -eq 0 ]; then
     exec="&> /dev/null"
fi

check_dependencies() {
    dep=("pv" "util-linux" "gzip" "parted")

    for x in "${dep[@]}"; do
        dpkg-query -W $x &> /dev/null
        if [ $? -eq 1 ]; then
            echo "$x: ist nicht installiert"
            ni=1
        fi
    done        
    return $ni
}

echo ""
# Check if the user is root
if [[ $usr == "root" ]]; then

    echo "Please insert sdCard"
    read -p "Confirm with mount (mount): " plugged
    exit=0
    while [ $exit -eq 0 ]; do
        if [[ $plugged == "mount" ]]; then
            
            if check_dependencies; then

                # Choose backup
                if [ $prf -eq 1 ]; then
                   
                    req=0 
                    while [ $req -eq 0 ]; do

                        # Choose directory
                        rq=0
                        while [ $rq -eq 0 ]; do

                            # Read list directory
                            i=0
                            echo ""
                            while read p
                            do
                                fol[$i]=$p
                                echo "[$i] ${fol[$i]}"
                                ((i++))
                            done < <(ls -1 $imgfol)

                            read -p "Choose directory which includes the backup (Number): " bdec
                            re='^[0-9]+$'
                            if [ $bdec -lt 0 ] || [ $bdec -gt ${#fol[@]} ] || ! [[ $bdec =~ $re ]]; then
                                echo "Decision not possible, choose again: "
                            else
                                if [ -e ${imgfol}/${fol[bdec]}/type.txt ]; then
                                    echo "Choose directory ${imgfol}/${fol[bdec]}"
                                    rq=1
                                else
                                    imgfol="${imgfol}/${fol[bdec]}"
                                    echo "Subdirectory found, choose again:"
                                fi
                            fi
                        done

                        # Read the comment
                        echo ""
                        echo "Comment: "
                        cat ${imgfol}/${fol[bdec]}/comment.txt 
                        echo "--------------"
                        rq=1

                        # Final decision
                        read -p "Do you really want to use this backup? (Y/n): " cdec
                        rq=0 
                        while [ $rq -eq 0 ]; do
                            if [[ $cdec == [Yy] ]] || [[ $cdec == "" ]]; then
                                rq=1
                                req=1
                            elif [[ $cdec == "n" ]]; then
                                rq=1
                            else 
                                read -p "Unknown option (Y/n): " cdec
                            fi
                        done
                    done

                    # Check type
                    if [[ $(cat ${imgfol}/${fol[$bdec]}/type.txt) == "Complete" ]]; then
                        b_type="full"
                    elif [[ $(cat ${imgfol}/${fol[$bdec]}/type.txt) == "Partition" ]]; then
                        b_type="part"
                    else
                        echo "type.txt file is missing. What kind of backup is in the directory?" 
                        echo "[1] Fullbackup"
                        echo "[2] Partitionbackup"
                        read -p "Choose: " sdec
                        if [ $sdec -eq 1 ]; then
                            b_type="full"
                        elif [ $sdec -eq 2 ]; then
                            b_type="part"
                        else
                            echo "Unknow option [1/2]:"
                            exit 1
                        fi
                    fi
                        
                    if [ -f  ${imgfol}/${fol[$bdec]}/pinfo.sh ]; then
                        source ${imgfol}/${fol[$bdec]}/pinfo.sh
                    else
                        echo "This backup is not compatible with the version of this script."
                        exit 1
                    fi
                fi

                # Start recovery
                if [ $prf -eq 1 ]; then
                    echo ""
                    echo "-- Starting recovery --"
                    echo "Use backup: ${fol[$bdec]}"
                fi

                # Search and list all existing disks
                echo ""
                partprobe
                i=0             # Counter
                while read p
                do
                    if [ $i -ne 0 ]; then
                        device[$i]=$p
                        echo "[$i] ${device[$i]}"
                    fi
                    ((i++))
                done < <(lsblk -d -o NAME)
                read -p "Please choose the disk which you want to overwrite (0-9): " ddec
                sdCard=${device[$ddec]}

                if [[ $sdCard == "mmcblk"[0-9] ]]; then
                    partition="p"
                elif [[ $sdCard == "sd"[a-z] ]]; then
                    partition=""
                else
                    echo ""
                    echo "ERROR: Unknow device name type."
                    echo "For safety reasons this script will stop."
                    echo "Script only allows following devices: "
                    echo " - mmcblk[0-9]"
                    echo " - sd[a-z]"
                    echo "If you want to add an other option, please don't hesitate to write to hq@rothirsch.tech"
                    echo ""
                    exit 2
                fi 
                echo "Using: ${sdCard}${partition}"

                # Choose disk
                if [ $prf -eq 1 ]; then 

                    if [[ $b_type == "part" ]]; then

                        # Getting information
                        if [ $prf -eq 1 ]; then

                            # Vergrößern eines Datenträgers
                            sidc="I"
                            while [[ $sidc == [!Yy]  ]] && [[ $sidc != "n" ]] 
                            do
                                read -p "Do you want to extend the last partition to maximum (Y/n): " sidc
                                if [[ $sidc == [Yy] ]] ||  [[ $sidc == "" ]]; then
                                    echo "Last partition will be extended..."
                                    sidc="y"
                                elif [[ $sidc == [Nn] ]]; then
                                    echo "Partition sizes will be the same as the backup sizes..."
                                else
                                    read -p "Unknown option (Y/n)!... " sidc
                                fi  
                            done

                            read -p "The complete disk ${sdCard} will be overwritten (z=ZEROS) [Y/n/z]: " dec
                            if [[ $dec == "z" ]]; then
if [[ $dec == "z" ]]; then
                                    read -p "The lifetime of a sdCard depends on how often it is overwritten. Ok? (Y/n): " dec
                                    if [[ $dec == [Yy] ]] || [[ $dec == "" ]]; then
                                        echo "Overwrite the complete storage device ${sdCard} with /dev/null ..."
                                        pv -tpreb /dev/zero | dd of=/dev/${sdCard} bs=32M conv=noerror && sync
                                    fi
                                fi
                            fi

                        # # #
                        # Delete existing partitions and the MBR on the storage device

                        # Find partitions and there sizes in Byte
                            if [ $prf -eq 1 ]; then
                                i=0 # counter
                                j=0 # counter
                                while read p
                                do
                                    if  [[ $p == *"${sdCard}"* ]]; then
                                        if [ $i -ne 0 ]; then
                                            part[$j]=$p
                                            ((j++))
                                        fi
                                        ((i++))
                                    fi
                                done < <(lsblk -l -o NAME)
                            fi
                            part=($(printf "%s\n" "${part[@]}" | sort -u))

                        # Unmount
                            if [[ ${part[@]} == "" ]]; then

                                echo "No partitions found."

                            else

                                if [ $prf -eq 1 ]; then

                                    echo ""
                                    echo "Check if the partition ${part[$pdec]} is mounted."
                                    for (( x=0; x<${#part[@]}; x++ ));
                                    do
                                        if mountpoint -q /dev/${part[$x]} &> /dev/null; then
                                            echo ""
                                            echo "${part[$x]} mounted. Unmount..."
                                            umount /dev/${part[$x]} &> /dev/null

                                        elif mount -l | grep /dev/${part[$x]} &> /dev/null; then
                                            echo ""
                                            echo "${part[$x]} mounted. Unmount..."
                                            umount /dev/${part[$x]} &> /dev/null

                                        fi
                                    done
                                fi

                            fi
                        #
                        # # #

                        # # #
                        # Create new partitions

                        # Find the last parition
                            partAmount=0
                            if [ $prf -eq 1 ]; then
                                for (( x=0;  x < ${#opsize[@]}; x++ )); do
                                    partType=$(awk -F';' '{print $1;}' <<<${opsize[$x]})
                                    if [[ $partType != "Free" ]]; then
                                        (( partAmount++ ))
                                    fi
                                done
                            fi
   
                        # Create 
                            if [ $prf -eq 1 ]; then

                                #echo ""
                                #echo "Create partition table and partitions"
                                #parted -s /dev/${sdCard} mklabel msdos

                                # wms_backups saves the mbr. Maybe this is helpful in the future
                                echo "MBR und Partitionstabelle recovery"
                                dd if=${imgfol}/${fol[$bdec]}/mbr.bin of=/dev/${sdCard} bs=100M count=1
                                partprobe 

                        # Read trough the partition list save by wms_backup.sh
                                echo ""
                                echo "Resize partitions"
                                pnumber=1
                                for (( x=0;  x < ${#opsize[@]}; x++ )); do

                                    partType=$(awk -F';' '{print $1;}' <<<${opsize[$x]})
                                    if [[ $partType != "Free" ]]; then

                                        ssec=$(awk -F';' '{print $2;}' <<<${opsize[$x]})
                                        ssec=$(sed 's/s//g' <<< $ssec)

                                        if [ $pnumber -eq $partAmount ] && [[ $sidc == [Yy] ]]; then
                                            ssiz=""
                                            ( echo d; echo $pnumber; echo n; echo p; echo $pnumber; echo $ssec; echo $ssiz; echo w) | fdisk /dev/${sdCard} &> /dev/null
                                        else
                                            ssiz=$(awk -F';' '{print $3;}' <<<${opsize[$x]})
                                            ssiz=$(sed 's/s//g' <<< $ssiz)
                                        fi

                                        (( pnumber++ ))
                                    fi
                                done
                            fi

                        # ReRead sdCard so all partitions will be recognized
                        # Without this option a device called /dev/loop0 will be created
                            partprobe

                        #
                        # # #

                        # # #
                        # Recovery of the images
                            if [ $prf -eq 1 ]; then
                                echo "!! Please sit back an wait for a while... !!"
                                echo "!! This step can take some time..."
                                echo "!! Please wait, even if the proccess stucks at 100%... !!"
                                echo ""
                                i=1

                                for x in  ${imgfol}/${fol[$bdec]}/p[0-9]*.gz
                                do
                                    echo "Write, $x to /dev/${sdCard}${partition}$i..."
                            
                                    gzip -dc $x | pv -tpreb | dd of=/dev/${sdCard}${partition}$i  bs=4M
                                    sync

                                    if [ $i -gt 1 ]; then
                                        echo "Check filesytem..."
                                            e2fsck -f /dev/${sdCard}${partition}$i &> /dev/null

                                        echo "Resize filesystem to maximum..."
                                            resize2fs -p /dev/${sdCard}${partition}$i &> /dev/null

                                        echo "Check filesystem..."
                                            e2fsck -f /dev/${sdCard}${partition}$i &> /dev/null
                                    fi

                                    (( i++ ))
                                    echo ""
                                done
                            fi

                            partprobe
                            echo "Image recovered successfully."
                            for x in 1 2 3; do sleep 0.5; echo -ne "\a"; done

                        fi # b_type = part
                    fi # $prf -eq 1

                    if [[ $b_type == "full" ]]; then
                        echo "Found Fullbackup. Overwrite complite storage device!"
                        gzip -dc ${imgfol}/${fol[$bdec]}/*.gz | pv -tpreb | dd bs=4M of=/dev/${sdCard} && sync
                    fi

                # Exist scritp if $prf 0
                fi

            # Exit script if dependencie problems detected
            else
                echo ""
                echo "-- ! Please install dependencies --"
            fi
            exit=1
            # Exit script if storage device is unmounted
        else
            echo ""
            read -p "Unknown option. Use 'mount' or 'exit': " plugged
        fi
        if [[ $plugged == "exit" ]]; then
            echo ""
            echo "User exits script."
            exit=1
        fi
    done

# End script if the executing user is not root
else
    echo "The script must be executed as root"
fi
