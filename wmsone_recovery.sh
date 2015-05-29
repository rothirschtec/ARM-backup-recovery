#!/bin/bash

echo "wms-one Recovery tool"
echo "Author: René Zingerle"
echo "Date: 12.05.2015"
echo "Version: 0.05 [BETA]"
echo "Infos: http://wmsblog.rothirsch-tec.at/wmsone_backup/index.html"
echo "---------------------"

usr=$USER
prf=1
dbg=0

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

# Prüfe ober der ausführende Benutzer root ist.
if [[ $usr == "root" ]]; then

    if check_dependencies; then
        # Wähle Backup
        if [ $prf -eq 1 ]; then
           
            req=0 
            while [ $req -eq 0 ]; do

                # Lese Inhalt des Backup Ordner
                i=0
                echo ""
                while read p
                do
                    fol[$i]=$p
                    echo "[$i] ${fol[$i]}"
                    ((i++))
                done < <(ls -1 part_img)

                # Entscheidung welcher Ordner verwendet werden soll 
                rq=0
                while [ $rq -eq 0 ]; do
                    read -p "Welches Backup soll wiederhergestellt werden (Nummer): " bdec
                    re='^[0-9]+$'
                    if [ $bdec -lt 0 ] || [ $bdec -gt ${#fol[@]} ] || ! [[ $bdec =~ $re ]]; then
                        echo "Auswahl nicht möglich"
                    else
                        rq=1
                    fi
                done
                

                # Lesen der Beschreibung
                echo ""
                echo "Beschreibung: "
                cat part_img/${fol[$bdec]}/comment.txt 
                echo "--------------"
                rq=1

                # Entgültige Entscheidung
                read -p "Soll dieses Backup verwendet werden? (y/n)" cdec
                rq=0 
                while [ $rq -eq 0 ]; do
                    if [[ $cdec == "y" ]]; then
                        rq=1
                        req=1
                    elif [[ $cdec == "n" ]]; then
                        rq=1
                    else 
                        read -p "Auswahl nicht möglich (y/n)" cdec
                    fi
                done
            done

            # Prüfe status
            if [[ $(cat part_img/${fol[$bdec]}/state.txt) == "Complete" ]]; then
                state="full"
            elif [[ $(cat part_img/${fol[$bdec]}/state.txt) == "Partition" ]]; then
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
            else
                part[$i]="Disk Array"
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
                    cp -a part_img/${fol[$bdec]}/*.gz tmp/

                    echo "Entpacke gzip Archiv und ermitteln der Größe..."
                    i=0
                    for x in tmp/*
                    do
                        echo -n "$x..."
                        gunzip $x
                        calc=$(ls -s ${x%.*} | awk '{ print $1 }')
                        #calc=$(echo "scale=0; ($calc/100 * 110)" | bc)
                        size[$i]=$calc
                        echo ${size[$i]}
                        (( i++ ))
                    done
                fi

                read -p "Der komplette Datenträger ${device[$ddec]} wird überschrieben (y/n)" dec
                if [[ $dec == "y" ]]; then

                    if [ $prf -eq 1 ]; then
                        read -p "Kompletten Datenträger mit Nullen überschreiben? (y/n)" dec
                        if [[ $dec == "y" ]]; then
                            read -p "Die Lebensdauer eine SD Karte ist von ihren Schreibzyklen abhängig. Trotzdem fortfahren? (y/n)" dec
                            if [[ $dec == "y" ]]; then
                                echo "Überschreibe den kompletten Datenträger ${device[$ddec]} mit /dev/null ..."
                                pv -tpreb /dev/zero | dd of=/dev/${device[$ddec]} bs=32M
                            fi
                        fi
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

                    if [ $prf -eq 1 ]; then
                    # Entferne den freien Speicher auf der ausgewählten Partition und entferne es
                        echo "Prüfe ob das Dateisystem ${part[$pdec]} einhängt/gemountet ist."
                        for (( x=0; x<${#part[@]}; x++ ));
                        do
                            if [ $x -ne 0 ]; then
                                if mountpoint -q /dev/${part[$x]}; then
                                    echo "${part[$x]} ist eingehängt. Entferne..."
                                    umount /dev/${part[$x]}
                                elif mount -l | grep /dev/${part[$x]}; then
                                    echo "${part[$x]} ist eingehängt. Entferne..."
                                    umount /dev/${part[$x]}
                                else
                                    echo "${part[$x]} ist nicht eingehängt. Fahre fort..."
                                fi
                            fi
                        done
                    fi

                    # Löschen der bestehenden Partition
                    if [ $prf -eq 1 ]; then
                        echo "Lösche alle Partition auf dem Datenträger ${device[$ddec]} ..."
                        for (( x=(${#part[@]} - 1);  x > 0; x-- )); do
                            echo "Remote ${part[$x]}"
                            if [ $dbg -eq 1 ]; then
                                (echo d; echo $x; echo w) | fdisk /dev/${device[$ddec]}
                            else
                                (echo d; echo $x; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
                            fi
                        done
                    fi

                    # Erstellen der Partitionen 
                    if [ $prf -eq 1 ]; then
                        echo "Erstelle Partitionen..."
                        for (( x=0;  x < ${#size[@]}; x++ )); do
                            echo "Partition $x"
                            if [ $dbg -eq 1 ]; then
                                ( echo n; echo p; echo $(( x + 1 )); echo ; echo +${size[$x]}K; echo w) | fdisk /dev/${device[$ddec]}
                            else
                                ( echo n; echo p; echo $(( x + 1 )); echo ; echo +${size[$x]}K; echo w) | fdisk /dev/${device[$ddec]} &> /dev/null
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
                        echo "!! Sollten der Recovery-Prozess 100% erreicht haben, der Skript aber nicht mehr reagieren, dann muss der Datenträger entfernt werden !!"
                        echo ""
                        i=1
                        for x in tmp/*
                        do
                            pv -tpreb $x | dd bs=4M of=/dev/${part[$i]}
                            echo "Überprüfe das Dateisystem..."
                            e2fsck -f /dev/${part[$i]}
                            echo "Vergrößere Dateisystem auf maximum..."
                            resize2fs -p /dev/${part[$i]} 
                            echo "Überprüfe das Dateisystem..."
                            e2fsck -f /dev/${part[$i]}
                            if [ $i -eq 1 ]; then
                                echo "Setze das Boot Flag"
                                parted /dev/${device[$ddec]} set $i lba on
                            fi
                            (( i++ ))
                        done
                    fi

                    echo ""
                    echo "Image wurde wiederhergestellt."

                fi # state = part
            fi # $prf -eq 1

            if [[ $state == "full" ]]; then
                echo "Vollständiges Backup erkannt. Überschreibe Datenträger!"
                echo "!! Sollten der Recovery-Prozess 100% erreicht haben, der Skript aber nicht mehr reagieren, dann muss der Datenträger entfernt werden !!"
                gzip -dc part_img/${fol[$bdec]}/*.gz | pv -tpreb | dd bs=4M of=/dev/${device[$ddec]}
            fi

        # Beende Script wenn $prf 0
        fi

    # Beende den Script wenn die Abhängigkeiten nicht gegeben sind
    else
        echo ""
        echo "-- ! Bitte installieren Sie die Abhängigkeiten --"
    fi

# Beende den Script wenn er nicht vom User root ausgeführt wird!
else
    echo "Der Script muss als Root ausgeführt werden."
fi
