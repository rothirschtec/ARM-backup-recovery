#!/bin/bash

usr=$USER
prf=1

check_dependencies() {
    dep=("pv" "util-linux" "gzip")

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
        
        read -p "Möchten Sie vor dem Backup eine Partition verkleinern? (y/n)" shrinkdec
        if [[ $shrinkdec == "n" ]]; then
            echo "Befehl akzeptiert, sichern der Partitionen"
        fi

        if [[ $shrinkdec == "n" ]] || [[ $shrinkdec == "y" ]]; then
            
            if [ $prf -eq 1 ]; then
            # Suche der Speichermedien und bereite sie zu einem Auswahlmenü zu
                i=0             # Zähler
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
            fi

            if [ $prf -eq 1 ]; then
            # Suche der Partitionen und deren Größen im Format Byte
                i=0             # Zähler
                psize[0]="Partition Sizes"
                while read p
                do
                    if [[ $p == *${device[$ddec]}* ]]; then
                        if [ $i -ne 0 ]; then
                            part[$i]=$p
                            j=0
                            while read size
                            do
                                if [ $j -ne 0 ]; then
                                    psize[$i]=$size
                                fi
                                (( j++ ))
                            done < <(lsblk -l -o SIZE -b /dev/${part[$i]})
                        else
                            part[$i]="Part Array"
                        fi
                        ((i++))
                    fi
                done < <(lsblk -l -o NAME)
            fi


            if [ $prf -eq 1 ]; then
            # Auflisten der Auswahl
                echo "Sie haben sich für das Speichermedium ${device[$ddec]} mit folgenden Partitionen entschieden:"
                for (( x=0; x<${#part[@]}; x++ ));
                do
                    if [ $x -ne 0 ]; then
                        echo "${part[$x]} with ${psize[$x]}"
                    fi
                done
            fi

            if [[ $shrinkdec == "y" ]]; then
                if [ $prf -eq 1 ]; then
                # Wähle zu verkleinernte Partition
                    for (( x=0; x<${#part[@]}; x++ ));
                    do
                        if [ $x -ne 0 ]; then
                            echo "[$x] ${part[$x]}"
                        fi
                    done
                    read -p "Welche der gwählten Partitionen soll verkleinert werden? (Nummer):" pdec
                fi

                if [ $prf -eq 1 ]; then
                # Entferen den freien Speicher auf der ausgewählten Partition und entferne es
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


                # Verkleinern der Systempartition
                if [ $prf -eq 1 ]; then

                    ((psizadd=(${psize[$pdec]}+500000000)/1000))
                    echo $psizadd

                    echo "Finde den Startsektor der Partition heraus"
                    starsec=$(fdisk -l |grep /dev/${part[$pdec]} | awk '{ print $2 }')

                    echo "Überprüfe das Dateisystem..."
                    e2fsck -f /dev/${part[$pdec]}

                    echo "Verkleinere Dateisystem ${part[$pdec]}... auf das Minimum"
                    resize2fs -M /dev/${part[$pdec]} $psizadd

                    echo "Verkleiner die Partitionsgröße: ${part[$pdec]}..."
                    (echo d; echo $pdec; echo n; echo p; echo $pdec; echo $starsec ; echo +${psizadd}K; echo w) | fdisk /dev/${device[$ddec]}

                    echo "Check Filesystem..."
                    e2fsck -f /dev/${part[$pdec]}
                fi
            fi

            # Sichern der Partitionen
            if [ $prf -eq 1 ]; then

                echo "Sichere die Partitionen..."
                NOW=$(date +"%m_%d_%Yat%H_%M_%S")
                mkdir part_img/$NOW

                for (( x=0; x<${#part[@]}; x++ ));
                do
                    if [ $x -ne 0 ]; then
                        echo "Sicher partition ${part[$x]}..."
                        echo "Dieser Vorgang kann einige Zeit in Anspruch nehmen!..."
                        pv -tpreb /dev/${part[$x]} | dd bs=4M | gzip > part_img/$NOW/p${x}_wmsone.img.gz
                    fi
                done
            fi

            # Beschreiben des Backups
            if [ $prf -eq 1 ]; then

                i=0
                read -p "Möchten Sie das Backup beschreiben? (y/n)" cdec
                while [ $i -eq 0  ]; do
                    if [[ $cdec == "y" ]]; then
                        read -p "Einzeilige Beschreibung oder mittels vi? (e/v)" edec
                        j=0
                        while [ $j -eq 0  ]; do
                            if [[ $edec == "v" ]]; then
                                vi part_img/$NOW/comment.txt
                                j=1
                            elif [[ $edec == "e" ]]; then
                                read -p "Beschreibung: " comment
                                echo $comment > part_img/$NOW/comment.txt
                                j=1
                            else
                                read -p "Auswahl nicht möglich. Wählen Sie (e)inzeilig oder (v)i!" edec
                                j=0
                            fi
                        done
                        i=1
                    elif [[ $cdec == "n" ]]; then
                        read -p "Keine Beschreibung ausgewählt!"
                        echo "Keine Beschreibung angegeben!" > part_img/$NOW/comment.txt
                        i=1
                    else
                        read -p "Auswahl nicht möglich. Wählen Sie (y)es oder (n)o!" cdec
                        i=0
                    fi
                done

                echo ""
                echo "Die Partitionen wurden erfolgreich gesichert."
                    
            fi

        # Beende den Script bei Falscheingabe
        else
            echo "Nur Eingabe von (y)es oder (n)o möglich! Beende Befehl!"         
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

