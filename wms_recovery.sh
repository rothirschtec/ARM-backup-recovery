#!/bin/bash

echo "wms-one Recovery tool"
echo "Author: René Zingerle"
echo "Date: 10.08.2015"
echo "Version: 0.11 [BETA]"
echo "Infos: http://wmsblog.rothirsch-tec.at/wmsone_backup/index.html"
echo "---------------------"

usr=$USER
prf=1
dbg=0
imgfol="part_img"

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
# Prüfe ober der ausführende Benutzer root ist.
if [[ $usr == "root" ]]; then

    echo "Bitte führen Sie den Datenträger jetzt/erneut in den Card Reader ein!"
    read -p "Bestätigen Sie mit dem Befehl (mount): " plugged
    exit=0
    while [ $exit -eq 0 ]; do
        if [[ $plugged == "mount" ]]; then
            
            if check_dependencies; then
                # Wähle Backup
                if [ $prf -eq 1 ]; then
                   
                    req=0 
                    while [ $req -eq 0 ]; do

                        # Entscheidung welcher Ordner verwendet werden soll 
                        rq=0
                        while [ $rq -eq 0 ]; do

                            # Lese Inhalt des Backup Ordner
                            i=0
                            echo ""
                            while read p
                            do
                                fol[$i]=$p
                                echo "[$i] ${fol[$i]}"
                                ((i++))
                            done < <(ls -1 $imgfol)

                            read -p "Welches Backup soll wiederhergestellt werden (Nummer): " bdec
                            re='^[0-9]+$'
                            if [ $bdec -lt 0 ] || [ $bdec -gt ${#fol[@]} ] || ! [[ $bdec =~ $re ]]; then
                                echo "Auswahl nicht möglich"
                            else
                                if [ -e ${imgfol}/${fol[bdec]}/state.txt ]; then
                                    echo "Verwende Ordner ${imgfol}/${fol[bdec]}"
                                    rq=1
                                else
                                    imgfol="${imgfol}/${fol[bdec]}"
                                    echo "Unterordner erkannt: Wähle erneut:"
                                fi
                            fi
                        done

                        # Lesen der Beschreibung
                        echo ""
                        echo "Beschreibung: "
                        cat ${imgfol}/${fol[bdec]}/comment.txt 
                        echo "--------------"
                        rq=1

                        # Entgültige Entscheidung
                        read -p "Soll dieses Backup verwendet werden? (y/n): " cdec
                        rq=0 
                        while [ $rq -eq 0 ]; do
                            if [[ $cdec == "y" ]]; then
                                rq=1
                                req=1
                            elif [[ $cdec == "n" ]]; then
                                rq=1
                            else 
                                read -p "Auswahl nicht möglich (y/n): " cdec
                            fi
                        done
                    done

                    # Prüfe status
                    if [[ $(cat ${imgfol}/${fol[$bdec]}/state.txt) == "Complete" ]]; then
                        state="full"
                    elif [[ $(cat ${imgfol}/${fol[$bdec]}/state.txt) == "Partition" ]]; then
                        state="part"
                    else
                        echo "Es wurde keine Information darüber gefunden, ob es sich um ein Volles oder Partitions Backup handelt." 
                        echo "[1] Vollbackup"
                        echo "[2] Partitionsbackup"
                        read -p "Wahl: " sdec
                        if [ $sdec -eq 1 ]; then
                            state="full"
                        elif [ $sdec -eq 2 ]; then
                            state="part"
                        else
                            echo "Auswahl nicht möglich beende Script"
                            exit
                        fi
                    fi
                        
                    if [ -f  ${imgfol}/${fol[$bdec]}/pinfo.sh ]; then
                        source ${imgfol}/${fol[$bdec]}/pinfo.sh
                    else
                        echo "Veraltetes Backup wird nicht mehr unterstützt"
                    fi
                fi

                # Starte den Wiederherstellungsprozess
                if [ $prf -eq 1 ]; then
                    echo ""
                    echo "-- Recovery gestartet --"
                    echo "Verwende Backup: ${fol[$bdec]}"
                    rm -rf tmp/*
                fi

                # Suche der Speichermedien und bereite sie zu einem Auswahlmenü zu
                i=0             # Zähler
                echo ""
                while read p
                do
                    if [ $i -ne 0 ]; then
                        device[$i]=$p
                        echo "[$i] ${device[$i]}"
                    fi
                    ((i++))
                done < <(lsblk -d -o NAME)
                read -p "Welchen Datenträger möchten Sie verwenden (Nummer): " ddec


                # Wähle Datenträger
                if [ $prf -eq 1 ]; then 

                    if [[ $state == "part" ]]; then

                        # Hole Informationen
                        if [ $prf -eq 1 ]; then
                            echo ""
                            echo "Kopiere Ordner"
                            cp -a ${imgfol}/${fol[$bdec]}/*.gz tmp/

                            echo "Entpacke gzip Archiv und ermitteln der Größe..."
                            i=0
                            for x in tmp/p[0-9]*.gz
                            do
                                echo -n "$x..."
                                gunzip $x
                                calc=$(ls -s ${x%.*} | awk '{ print $1 }')
                                #calc=$(echo "scale=0; ($calc/100 * 110)" | bc)
                                size[$i]="+${calc}K"
                                echo "here"
                                echo ${size[$i]}
                                (( i++ ))
                            done
                            (( i-- ))

                            # Vergrößern eines Datenträgers
                            while [[ $sidc != "y"  ]] && [[ $sidc != "n" ]] 
                            do
                                read -p "Soll die letzte Partition erweitert werden? (y/n): " sidc
                                if [[ $sidc == "y" ]]; then
                                    echo "Letzte Partition wird erweitert..."
                                elif [[ $sidc == "n" ]]; then
                                    echo "Fahre fort..."
                                else
                                    read -p "Auswahl nicht möglich!... " sidc
                                fi  
                            done

                            read -p "Der komplette Datenträger ${device[$ddec]} wird überschrieben (z=ZEROS) [y/n/z]: " dec
                            if [[ $dec == "y" ]] || [[ $dec == "z" ]]; then

                                if [[ $dec == "z" ]]; then
                                    read -p "Die Lebensdauer eine SD Karte ist von ihren Schreibzyklen abhängig. Trotzdem fortfahren? (y/n): " dec
                                    if [[ $dec == "y" ]]; then
                                        echo "Überschreibe den kompletten Datenträger ${device[$ddec]} mit /dev/null ..."
                                        pv -tpreb /dev/zero | dd of=/dev/${device[$ddec]} bs=32M conv=noerror && sync
                                    fi
                                fi
                            fi

                        # # #
                        # Entfernen der bestehenden Partitionen am Datenträger

                            # Suche der Partitionen und deren Größen im Format Byte
                            if [ $prf -eq 1 ]; then
                                i=0             # Zähler
                                j=0
                                while read p
                                do
                                    if  [[ $p == *"${device[$ddec]}"* ]]; then
                                        if [ $i -ne 0 ]; then
                                            part[$j]=$p
                                            echo $p
                                            ((j++))
                                        fi
                                        ((i++))
                                    fi
                                done < <(lsblk -l -o NAME)
                            fi
                            part=($(printf "%s\n" "${part[@]}" | sort -u))
                            echo ${part[@]}

                            if [[ ${part[@]} == "" ]]; then

                                echo "Keine Partitionen erkannt."

                            else

                                if [ $prf -eq 1 ]; then
                                # Entferne den freien Speicher auf der ausgewählten Partition und entferne es

                                    echo ""
                                    echo "Prüfe ob das Dateisystem ${part[$pdec]} einhängt/gemountet ist."
                                    for (( x=0; x<${#part[@]}; x++ ));
                                    do
                                        echo ""
                                        if mountpoint -q /dev/${part[$x]} &> /dev/null; then
                                            echo "${part[$x]} ist eingehängt. Entferne..."
                                            umount /dev/${part[$x]} &> /dev/null

                                        elif mount -l | grep /dev/${part[$x]} &> /dev/null; then
                                            echo "${part[$x]} ist eingehängt. Entferne..."
                                            umount /dev/${part[$x]} &> /dev/null

                                        else
                                            echo "${part[$x]} ist nicht eingehängt. Fahre fort..."
                                        fi
                                    done
                                fi

                                # Löschen der bestehenden Partition
                                if [ $prf -eq 1 ]; then

                                    echo ""
                                    echo "Lösche alle Partition auf dem Datenträger ${device[$ddec]} ..."
                                    #(echo o; echo n; echo p; echo 1; echo ; echo; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null

                                    for (( x=(${#part[@]} - 1);  x >= 0; x-- )); do
                                        echo "Delete Partition: ${part[$x]}"

                                        #if [ $x -eq 1 ]; then
                                        #    (echo d; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                                        #else
                                            (echo d; echo $x; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                                        #fi
                                    done
                                fi
                            fi
                        #
                        # # #

                        partprobe &> /dev/null

                        # # #
                        # Erstellen der Partitionen

                            # Finde letzte Partition
                            partAmount=0
                            if [ $prf -eq 1 ]; then
                                for (( x=0;  x < ${#opsize[@]}; x++ )); do
                                    partType=$(awk -F';' '{print $1;}' <<<${opsize[$x]})
                                    if [[ $partType != "Free" ]]; then
                                        (( partAmount++ ))
                                    fi
                                done
                            fi
                            
                            # Erstellen der Partitionen 
                            if [ $prf -eq 1 ]; then
                                echo "Erstelle Partitionen..."
                                pnumber=1
                                for (( x=0;  x < ${#opsize[@]}; x++ )); do

                                    partType=$(awk -F';' '{print $1;}' <<<${opsize[$x]})
                                    if [[ $partType != "Free" ]]; then
                                  
                                        ssec=$(awk -F';' '{print $2;}' <<<${opsize[$x]})
                                        ssec=$(sed 's/s//g' <<< $ssec)
                                        if [ $pnumber -eq $partAmount ] && [[ $sidc == "y" ]]; then
                                            ssiz=""
                                        else
                                            ssiz=$(awk -F';' '{print $3;}' <<<${opsize[$x]})
                                            ssiz=$(sed 's/s//g' <<< $ssiz)
                                        fi
                                        
                                        if [ $pnumber -eq 1 ]; then
                                            ( echo t; echo $pnumber; echo c; echo w) | fdisk /dev/${device[$ddec]} #&> /dev/null
                                        fi
                                        ( echo n; echo p; echo $pnumber; echo $ssec; echo $ssiz; echo w) | fdisk /dev/${device[$ddec]} #&> /dev/null
                                        (( pnumber++ ))
                                    fi
                                done
                            fi
                        #
                        # # #

                        partprobe &> /dev/null

                            # Wiederherstellen der Image Dateien
                            if [ $prf -eq 1 ]; then
                                echo "Erstelle Partitionen..."
                                echo "!! Dieser Vorgang kann einige Zeit in Anspruch nehmen...  !!"
                                echo "!! Bitte warten Sie auch wenn der Vorgang 100% erreicht hat... !!"
                                echo ""
                                i=1

                                for x in tmp/p[0-9]*
                                do
                                    echo "Write to /dev/${device[$ddec]}p$i..."
                                    pv -tpreb $x | dd of=/dev/${device[$ddec]}p$i bs=4M && sync

                                    if [ $i -gt 1 ]; then
                                        echo "Überprüfe das Dateisystem..."
                                            e2fsck -f /dev/${device[$ddec]}p$i &> /dev/null

                                        echo "Vergrößere Dateisystem auf maximum..."
                                            resize2fs -p /dev/${device[$ddec]}p$i &> /dev/null

                                        echo "Überprüfe das Dateisystem..."
                                            e2fsck -f /dev/${device[$ddec]}p$i &> /dev/null
                                    fi

                                    (( i++ ))
                                done
                            fi

                            echo ""
                            echo "Setze Boot Flag"
                            parted /dev/${device[$ddec]} set 1 lba on &> /dev/null

                            partprobe &> /dev/null
                            echo "Image wurde wiederhergestellt."
                            for x in 1 2 3; do sleep 0.5; echo -ne "\a"; done

                        fi # state = part
                    fi # $prf -eq 1

                    if [[ $state == "full" ]]; then
                        echo "Vollständiges Backup erkannt. Überschreibe Datenträger!"
                        echo "!! Sollten der Recovery-Prozess 100% erreicht haben, der Skript aber nicht mehr reagieren, dann muss der Datenträger entfernt werden !!"
                        gzip -dc ${imgfol}/${fol[$bdec]}/*.gz | pv -tpreb | dd bs=4M of=/dev/${device[$ddec]} && sync
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
