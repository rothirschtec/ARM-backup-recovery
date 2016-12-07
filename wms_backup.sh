#!/bin/bash 

echo "#wms Backup tool"
echo "Author: René Zingerle"
echo "Date: 07.12.2016"
echo "Version: 0.09 [BETA]"
echo "Info: http://http://wmsblog.rothirsch.tech/wms_backup/"
echo "---------------------"

usr=$USER
prf=1
dbg=0

cd $(dirname $0)
hdir="$PWD/"
imgfol="${hdir}part_img"

check_dependencies() {
    dep=("ntp" "ntpdate" "pv")

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

# Check user for root permissions
if [[ $usr == "root" ]]; then

    echo ""
    echo "Please insert/reinsert you microSD Card now!"
    read -p "If the system has recognized the card please write (mount): " plugged
    exit=0
    while [ $exit -eq 0 ]; do
        if [[ $plugged == "mount" ]]; then
            
            # Warte 5 Sekunde
            wait=5
            echo -n "Wait for 5 seconds. Please check if everything is fine ["
            for ((x=0; x<$wait; x++))
            do
                echo -n "."
                sleep 1
            done
            echo "]"

            if check_dependencies; then
               
                echo "Choose between following Options: "
                echo    "[1] Complete Backup of the card. (writes the complete card to the image. The image will have the same size as your card has.)" 
                echo    "[2] Shrink der ROOTfs partition (backup image will have the size of you ROOTfs)"
                read -p "Choose (1/2): " shrinkdec

                if [[ $shrinkdec == "1" ]]; then
                    echo "Command accepted, create Full Backup!"
                elif [[ $shrinkdec == "2" ]]; then
                    echo "Command accepted, create Small Backup!"
                fi

                if [[ $shrinkdec == "1" ]] || [[ $shrinkdec == "2" ]]; then

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
                                device[$i]=$p
                                echo "[$i] ${device[$i]}"
                            else
                                part[$i]="Disk Array"
                            fi
                            ((i++))
                        done < <(lsblk -d -o NAME)
                        read -p "Choose your backup device [0-9]: " ddec
                        partprobe /dev/${device[$ddec]} 
                    fi

                    if [[ $shrinkdec == "2" ]]; then

                        # Find partition size in byte
                        if [ $prf -eq 1 ]; then

                            # HEAD
                            i=0
                            part[$i]="Part Array"       # @param part: Array for partitions
                            psize[$i]="Partition Sizes" # @param psize: Array for partition size

                            # MAIN
                            while read p
                            do
                            # Runs through all devices

                                if [[ $p == *${device[$ddec]}* ]] && [[ $p != *${device[$ddec]} ]]; then
                                    ((i++))
                                    part[$i]=$p

                                    # Umount mounted partitions
                                    if mountpoint -q /dev/${part[$i]} &> /dev/null; then
                                        echo "${part[$i]} ist eingehängt. Entferne..."
                                        umount /dev/${part[$i]} &> /dev/null
                                    elif mount -l | grep /dev/${part[$i]} &> /dev/null; then
                                        echo "${part[$i]} ist eingehängt. Entferne..."
                                        umount /dev/${part[$i]} &> /dev/null
                                    fi
                                
                                fi

                            done < <(lsblk -l -o NAME /dev/${device[$ddec]})
                        fi


                        if [ $prf -eq 1 ]; then
                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo "[$x] ${part[$x]} with ${psize[$x]}"
                                fi
                            done
                            read -p "Which one is the parition that should be resized? (ROOTfs): " pdec
                        fi

                        # Shrint partition of ROOTfs
                        if [ $prf -eq 1 ]; then

                            echo "Check filesystem..."
                            e2fsck -f /dev/${part[$pdec]}

                            echo "Shrink filesystem ${part[$pdec]}... "
                            resize2fs -M /dev/${part[$pdec]} 
                            rbc=$(tune2fs -l /dev/${part[$pdec]} | grep "Block count" | tail -1)
                            bsz=$(tune2fs -l /dev/${part[$pdec]} | grep "Block size" | tail -1)
                            rbc=${rbc##* }
                            bsz=${bsz##* }
                            ((psizadd=(${rbc}*${bsz})/1000))
                            #read -p "$rbc * $bsz = $psizadd" dec

                            echo "Find start sector of the partition"
                            starsec=$(fdisk -l |grep /dev/${part[$pdec]} | awk '{ print $2 }')

                            echo "Shrink partition size: ${part[$pdec]}..."
                            (echo d; echo $pdec; echo n; echo p; echo $pdec; echo $starsec ; echo +${psizadd}K; echo w) | fdisk /dev/${device[$ddec]}

                            echo "Check the filesystem again..."
                            e2fsck -f /dev/${part[$pdec]}

                        fi
                    fi

                    # Sichern der Partitionen
                    if [ $prf -eq 1 ]; then

                        ls -R ${imgfol}/ | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\// /g' -e 's/^/ /'
                        read -p "Name of the backup directory: " bak_fol
                        NOW=${bak_fol}/$(date +"%Y_%m_%dat%H_%M_%S")
                        mkdir -p ${imgfol}/$NOW

                        if [[ $shrinkdec == "2" ]]; then
                            echo "Partition backup..."
                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo "Backup ${part[$x]}..."
                                    echo "Please be patient!..."
                                    pv -tpreb /dev/${part[$x]} | dd bs=4M | gzip > ${imgfol}/$NOW/p${x}_wmsone.img.gz && sync
                                fi
                            done
                            echo "Partition" > ${imgfol}/$NOW/state.txt
                        elif [[ $shrinkdec == "1" ]]; then
                            echo "Backup the complete filesystem..."
                            echo "Please be patient..."
                            pv -tpreb /dev/${device[$ddec]} | dd bs=4M | gzip > ${imgfol}/$NOW/complete_wmsone.img.gz && sync
                            echo "Complete" > ${imgfol}/$NOW/state.txt
                        fi
                    fi

                    if [[ $shrinkdec == "2" ]]; then
                        # Resize des ROOTfs
                        if [ $prf -eq 1 ]; then
                            echo "Resize partition /dev/${part[$pdec]} to maximum"
                            echo "Check the filesystem..."
                            if [ $dbg -eq 0 ]; then 
                                e2fsck -f -y -v -C 0 /dev/${part[$pdec]} &> /dev/null
                            else
                                e2fsck -f -y -v -C 0 /dev/${part[$pdec]}
                            fi
                            echo "Resize filesystem to maximum..."
                            if [ $dbg -eq 0 ]; then 
                                resize2fs -p /dev/${part[$pdec]} &> /dev/null
                            else
                                resize2fs -p /dev/${part[$pdec]}
                            fi
                            echo "Check the filesystem..."
                            if [ $dbg -eq 0 ]; then 
                                e2fsck -f -y -v -C 0 /dev/${part[$pdec]} &> /dev/null
                            else
                                e2fsck -f -y -v -C 0 /dev/${part[$pdec]}
                            fi
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

                    if [[ $shrinkdec == "2" ]]; then
                        echo ""
                        echo "Partition backup successfully ends..."
                    elif [[ $shrinkdec == "1" ]]; then
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
