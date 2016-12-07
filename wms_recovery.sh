#!/bin/bash

echo "#wms Recovery tool"
echo "Author: René Zingerle"
echo "Date: 12.05.2015"
echo "Version: 0.09 [BETA]"
echo "Info: http://http://wmsblog.rothirsch.tech/wms_backup/"
echo "---------------------"

usr=$USER
prf=1
dbg=0

cd $(dirname $0)
hdir="$PWD/"
imgfol="${hdir}part_img"
tmpdir="/tmp/wms_recovery/$(date)/"

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
# Check user for root permissions
if [[ $usr == "root" ]]; then

    echo "Please insert/reinsert you microSD Card now!"
    read -p "If the system has recognized the card please write (mount): " plugged
    exit=0
    while [ $exit -eq 0 ]; do
        if [[ $plugged == "mount" ]]; then
            
            # Give the user 5 seconds to rethink
            wait=5
            echo -n "Wait for 5 seconds. Please check if everything is fine ["
            for ((x=0; x<$wait; x++))
            do
                echo -n "."
                sleep 1
            done
            echo "]"

            if check_dependencies; then
                # Choose backup
                if [ $prf -eq 1 ]; then
                   
                    req=0 
                    while [ $req -eq 0 ]; do

                        # Find recovery image folder
                        rq=0
                        while [ $rq -eq 0 ]; do

                            i=0
                            echo ""
                            while read p
                            do
                                fol[$i]=$p
                                echo "[$i] ${fol[$i]}"
                                ((i++))
                            done < <(ls -1 $imgfol)

                            read -p "Choose one of the backups above ([0-9]): " bdec
                            re='^[0-9]+$'
                            if [ $bdec -lt 0 ] || [ $bdec -gt ${#fol[@]} ] || ! [[ $bdec =~ $re ]]; then
                                echo "Unknown parameter."
                            else
                                if [ -e ${imgfol}/${fol[bdec]}/state.txt ]; then
                                    echo "Use directory ${imgfol}/${fol[bdec]}"
                                    rq=1
                                else
                                    imgfol="${imgfol}/${fol[bdec]}"
                                    echo "Sub directory recognized by script!"
                                fi
                            fi
                        done

                        # Output commit
                        echo ""
                        echo "Commit: "
                        cat ${imgfol}/${fol[bdec]}/comment.txt 
                        echo "--------------"
                        rq=1

                        # Entgültige Entscheidung
                        read -p "Do you wanna use this backup? (y/n): " cdec
                        rq=0 
                        while [ $rq -eq 0 ]; do
                            if [[ $cdec == "y" ]]; then
                                rq=1
                                req=1
                            elif [[ $cdec == "n" ]]; then
                                rq=1
                            else 
                                read -p "Unknown parameter (y/n): " cdec
                            fi
                        done
                    done

                    # Prüfe status
                    if [[ $(cat ${imgfol}/${fol[$bdec]}/state.txt) == "Complete" ]]; then
                        state="full"
                    elif [[ $(cat ${imgfol}/${fol[$bdec]}/state.txt) == "Partition" ]]; then
                        state="part"
                    else
                        echo "Missing Information in backup directory please help with following information: " 
                        echo "[1] Fullbackup"
                        echo "[2] Partitionbackup"
                        read -p "Choose: " sdec
                        if [ $sdec -eq 1 ]; then
                            state="full"
                        elif [ $sdec -eq 2 ]; then
                            state="part"
                        else
                            echo "Unknown parameter, end script..."
                            exit
                        fi
                    fi
                        
                fi

                # Start the recovery process
                if [ $prf -eq 1 ]; then
                    echo ""
                    echo "-- Start recovery --"
                    echo "Use Backup: ${fol[$bdec]}"
                    rm -rf ${tmpdir}*
                fi

                # Show devices
                i=0
                echo ""
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
                read -p "Choose device ([0-9]): " ddec


                # Choose device
                if [ $prf -eq 1 ]; then 

                    if [[ $state == "part" ]]; then

                        # Hole Informationen
                        if [ $prf -eq 1 ]; then
                            echo ""
                            echo "Copy directory"
                            cp -a ${imgfol}/${fol[$bdec]}/*.gz ${tmpdir}

                            echo "Extract gzip archive and find size..."
                            i=0
                            for x in ${tmpdir}*
                            do
                                echo -n "$x..."
                                gunzip $x
                                calc=$(ls -s ${x%.*} | awk '{ print $1 }')
                                #calc=$(echo "scale=0; ($calc/100 * 110)" | bc)
                                size[$i]="+${calc}K"
                                echo ${size[$i]}
                                (( i++ ))
                            done
                            (( i-- ))
                
                            # Vergrößern eines Datenträgers
                            while [[ $sidc != "y"  ]] && [[ $sidc != "n" ]] 
                            do
                                read -p "Do you want to resize the last partition to maximum? (y/n): " sidc
                                if [[ $sidc == "y" ]]; then
                                    size[$i]=""
                                    echo "Extend partition..."
                                elif [[ $sidc == "n" ]]; then
                                    echo "Go ahead..."
                                else
                                    read -p "Unknown parameter!... (y/n): " sidc
                                fi  
                            done
                        fi

                        read -p "The complete device ${device[$ddec]} will be overwritten (y/n): " dec
                        if [[ $dec == "y" ]]; then

                            if [ $prf -eq 1 ]; then
                                read -p "Overwrite complete device with NULL? This will erase everything (y/n): " dec
                                if [[ $dec == "y" ]]; then
                                    read -p "The maximum lifte time of a SDcard dependc on the write cykle to the card. (y/n): " dec
                                    if [[ $dec == "y" ]]; then
                                        echo "Overwrite the complete device ${device[$ddec]} with /dev/null ..."
                                        pv -tpreb /dev/zero | dd of=/dev/${device[$ddec]} bs=32M conv=noerror
                                    fi
                                fi
                            fi

                            # Find partition and there sizes
                            if [ $prf -eq 1 ]; then
                                i=0
                                while read p
                                do
                                    if [[ $p == *${device[$ddec]}* ]]; then
                                        if [ $i -ne 0 ]; then
                                            part[$i]=$p
                                            j=0
                                        else
                                            part[$i]="Part Array"
                                        fi
                                        ((i++))
                                    fi
                                done < <(lsblk -l -o NAME)
                            fi

                            if [ $prf -eq 1 ]; then
                            # Remove empty space on partition
                                echo "Check mount state of the device ${part[$pdec]}"
                                for (( x=0; x<${#part[@]}; x++ ));
                                do
                                    if mountpoint -q /dev/${part[$x]}; then
                                        echo "${part[$x]} is mounted. Umount... "
                                        if [ $dbg -eq 0 ]; then 
                                            umount /dev/${part[$x]} &> /dev/null
                                        else
                                            umount /dev/${part[$x]}
                                        fi
                                    elif mount -l | grep /dev/${part[$x]}; then
                                        echo "${part[$x]} is mounted. Umount... "
                                        if [ $dbg -eq 0 ]; then 
                                            umount /dev/${part[$x]} &> /dev/null
                                        else
                                            umount /dev/${part[$x]}
                                        fi
                                    else
                                        echo "${part[$x]} isn't mounted. Go ahead..."
                                    fi
                                done
                            fi

                            # Delete existing partitions
                            if [ $prf -eq 1 ]; then
                                echo "Delete all partitions on the device ${device[$ddec]} ..."

                                for (( x=(${#part[@]} - 1);  x > 0; x-- )); do
                                    echo "Delete Partition: ${part[$x]}"
                                    if [ $dbg -eq 0 ]; then 
                                        if [ $x -eq 1 ]; then
                                            (echo d; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                                        else
                                            (echo d; echo $x; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                                        fi
                                        partprobe /dev/${device[$ddec]} 
                                    else
                                        if [ $x -eq 1 ]; then
                                            (echo d; echo w) | fdisk /dev/${device[$ddec]}
                                        else
                                            (echo d; echo $x; echo w) | fdisk /dev/${device[$ddec]}
                                        fi
                                        partprobe /dev/${device[$ddec]}
                                    fi
                                done

                                echo ""
                                echo "------------"
                                echo "Erzeuge partitonstabelle"
                                parted -s /dev/${device[$ddec]} mklabel msdos
                            fi

                            # Erstellen der Partitionen 
                            if [ $prf -eq 1 ]; then
                                echo "Erstelle Partitionen..."
                                for (( x=0;  x < ${#size[@]}; x++ )); do
                                    echo "Partition $x > Size:${size[$x]}"
                                    if [ $dbg -eq 0 ]; then 
                                        ( echo n; echo p; echo $(( x + 1 )); echo ; echo ${size[$x]}; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                                    else
                                        ( echo n; echo p; echo $(( x + 1 )); echo ; echo ${size[$x]}; echo w) | fdisk /dev/${device[$ddec]}
                                    fi
                                done
                            fi

                            # Suche der Partitionen und deren Größen im Format Byte
                            if [ $prf -eq 1 ]; then
                                i=0             # Zähler
                                while read p
                                do
                                    if [[ $p == *${device[$ddec]}* ]]; then
                                        if [ $i -ne 0 ]; then
                                            part[$i]=$p
                                            j=0
                                        else
                                            part[$i]="Part Array"
                                        fi
                                        ((i++))
                                    fi
                                done < <(lsblk -l -o NAME)
                            fi
                            # Wiederherstellen der Image Dateien
                            if [ $prf -eq 1 ]; then
                                echo "Erstelle Partitionen..."
                                echo "!! Dieser Vorgang kann einige Zeit in Anspruch nehmen...  !!"
                                echo "!! Bitte warten Sie auch wenn der Vorgang 100% erreicht hat... !!"
                                echo ""
                                i=1
                                for x in ${tmpdir}*
                                do
                                    pv -tpreb $x | dd of=/dev/${part[$i]} bs=4M conv=notrunc,noerror

                                    if [ $i -gt 1 ]; then
                                        echo "Überprüfe das Dateisystem..."
                                        if [ $dbg -eq 0 ]; then 
                                            e2fsck -f -y -v -C 0 /dev/${part[$i]} &> /dev/null
                                        else
                                            e2fsck -f -y -v -C 0 /dev/${part[$i]}
                                        fi
                                        echo "Vergrößere Dateisystem auf maximum..."
                                        if [ $dbg -eq 0 ]; then 
                                            resize2fs -p /dev/${part[$i]} &> /dev/null
                                        else
                                            resize2fs -p /dev/${part[$i]}
                                        fi
                                        echo "Überprüfe das Dateisystem..."
                                        if [ $dbg -eq 0 ]; then 
                                            e2fsck -f -y -v -C 0 /dev/${part[$i]} &> /dev/null
                                        else
                                            e2fsck -f -y -v -C 0 /dev/${part[$i]}
                                        fi
                                    fi
                                    (( i++ ))
                                done
                            fi

                            echo "Setze das Boot Flag"
                            if [ $dbg -eq 0 ]; then 
                                parted /dev/${device[$ddec]} set 1 lba on &> /dev/null
                            else
                                parted /dev/${device[$ddec]} set 1 lba on
                            fi

                            echo ""
                            echo "Image wurde wiederhergestellt."
                            for x in 1 2 3; do sleep 0.5; echo -ne "\a"; done

                        fi # state = part
                    fi # $prf -eq 1

                    if [[ $state == "full" ]]; then
                        echo "Vollständiges Backup erkannt. Überschreibe Datenträger!"
                        echo "!! Sollten der Recovery-Prozess 100% erreicht haben, der Skript aber nicht mehr reagieren, dann muss der Datenträger entfernt werden !!"
                        gzip -dc ${imgfol}/${fol[$bdec]}/*.gz | pv -tpreb | dd bs=4M of=/dev/${device[$ddec]}
                    fi

                # Beende Script wenn $prf 0
                fi

            # Beende den Script wenn die Abhängigkeiten nicht gegeben sind
            else
                echo ""
                echo "-- ! Bitte installieren Sie die Abhängigkeiten --"
            fi
            exit=1
            # Beende den Script wenn das Gerät nicht angehängt ist.
        else
            echo ""
            read -p "Eingabe nicht möglich. Geben Sie 'mount' oder 'exit' ein: " plugged
        fi
        if [[ $plugged == "exit" ]]; then
            echo ""
            echo "Script wurde beendet."
            exit=1
        fi
    done

# Beende den Script wenn er nicht vom User root ausgeführt wird!
else
    echo "Der Script muss als Root ausgeführt werden."
fi
