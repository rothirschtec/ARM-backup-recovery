#!/bin/bash 
usr=$USER
prf=1
imgfol="part_img"

check_dependencies() {
    dep=("lib32z1" "lib32ncurses5")

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

    echo "wms-one Backup tool"
    echo "Author: René Zingerle"
    echo "Date: 12.05.2015"
    echo "Version: 0.05 [BETA]"
    echo "Infos: http://wmsblog.rothirsch-tec.at/wmsone_backup/index.html"
    echo "---------------------"

    echo ""
    echo "Bitte führen Sie den Datenträger jetzt/erneut in den Card Reader ein!"
    read -p "Bestätigen Sie mit dem Befehl (mount): " plugged
    exit=0
    while [ $exit -eq 0 ]; do
        if [[ $plugged == "mount" ]]; then
            
            # Warte 5 Sekunde
            wait=5
            echo -n "Warte für 5 Sekunden ["
            for ((x=0; x<$wait; x++))
            do
                echo -n "."
                sleep 1
            done
            echo "]"

            if check_dependencies; then
               
                echo "Wählen Sie zwischen 2 Optionen:"
                echo    "[1] Komplett Backup des Datenträgers (Großes Image)" 
                echo    "[2] Verkleinern der Partitionen für kleinstmögliches Backup (Kleines Image)"
                read -p "Wählen Sie (1/2) " shrinkdec

                if [[ $shrinkdec == "1" ]]; then
                    echo "Befehl akzeptiert, erstelle Vollbackup!"
                elif [[ $shrinkdec == "2" ]]; then
                    echo "Befehl akzeptiert, sichere kompletten Datenträger!"
                fi

                if [[ $shrinkdec == "1" ]] || [[ $shrinkdec == "2" ]]; then

                    if [ $prf -eq 1 ]; then
                    # Erstelle Ordner-Struktur    
                        mkdir -p tmp
                        mkdir -p ${imgfol}
                    fi
                    
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
                        partprobe /dev/${device[$ddec]} 
                    fi

                    if [[ $shrinkdec == "2" ]]; then

                        # Suche der Partitionen und deren Größen im Format Byte
                        if [ $prf -eq 1 ]; then

                            # HEAD
                            i=0                         # @param i: Zähler für while Schleife
                            part[$i]="Part Array"       # @param part: Array für Partitionsnamen
                            psize[$i]="Partition Sizes" # @param psize: Array für Partitionsgrößen

                            # MAIN
                            while read p
                            do
                            # Durchläuft alle Datenträger

                                if [[ $p == *${device[$ddec]}* ]] && [[ $p != *${device[$ddec]} ]]; then
                                # Durchläuft nur die Partitionen nicht aber das Gerät selbst
                                    ((i++))
                                    part[$i]=$p

                                    # Entkopple Partitionen vom System wenn diese eingehängt sind
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
                        # Wähle zu Partition
                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo "[$x] ${part[$x]} with ${psize[$x]}"
                                fi
                            done
                            read -p "Welche der gewählten Partitionen soll verkleinert werden? (Nummer): " pdec
                        fi

                        # Verkleinern der Systempartition
                        if [ $prf -eq 1 ]; then

                            echo "Überprüfe das Dateisystem..."
                            e2fsck -f /dev/${part[$pdec]}

                            echo "Verkleinere Dateisystem ${part[$pdec]}... "
                            resize2fs -M /dev/${part[$pdec]} 
                            rbc=$(tune2fs -l /dev/${part[$pdec]} | grep "Block count" | tail -1)
                            bsz=$(tune2fs -l /dev/${part[$pdec]} | grep "Block size" | tail -1)
                            rbc=${rbc##* }
                            bsz=${bsz##* }
                            ((psizadd=(${rbc}*${bsz})/1000))
                            #read -p "$rbc * $bsz = $psizadd" dec

                            echo "Finde den Startsektor der Partition"
                            starsec=$(fdisk -l |grep /dev/${part[$pdec]} | awk '{ print $2 }')

                            echo "Minimiere die Partitionsgröße: ${part[$pdec]}..."
                            (echo d; echo $pdec; echo n; echo p; echo $pdec; echo $starsec ; echo +${psizadd}K; echo w) | fdisk /dev/${device[$ddec]}

                            echo "Überprüfe das Dateisystem..."
                            e2fsck -f /dev/${part[$pdec]}

                        fi
                    fi

                    # Sichern der Partitionen
                    if [ $prf -eq 1 ]; then

                        read -p "Möchten Sie das Image in einen Unterordner legen? (y/n)" foldec
                        i=0
                        while [ $i -eq 0  ]; do
                            if [[ $foldec == "y" ]]; then
                                i=1      
                                ls -R ${imgfol}/ | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\// /g' -e 's/^/ /'
                                read -p "Wie soll der Ordner heißen: " bak_fol
                                NOW=${bak_fol}/$(date +"%Y_%m_%dat%H_%M_%S")
                            elif [[ $foldec == "n" ]]; then
                                i=1      
                                NOW=$(date +"%Y_%m_%dat%H_%M_%S")
                            else
                                read -p "Auswahl nicht möglich (y/n)" foldec 
                            fi
                        done
                        mkdir -p ${imgfol}/$NOW

                        if [[ $shrinkdec == "2" ]]; then
                            echo "Sichere die Partitionen..."
                            for (( x=0; x<${#part[@]}; x++ ));
                            do
                                if [ $x -ne 0 ]; then
                                    echo "Sicher partition ${part[$x]}..."
                                    echo "Dieser Vorgang kann einige Zeit in Anspruch nehmen!..."
                                    pv -tpreb /dev/${part[$x]} | dd bs=4M | gzip > ${imgfol}/$NOW/p${x}_wmsone.img.gz && sync
                                fi
                            done
                            echo "Partition" > ${imgfol}/$NOW/state.txt
                        elif [[ $shrinkdec == "1" ]]; then
                            echo "Sichere den kompletten Datenträger..."
                            echo "Dieser Vorgang kann einige Zeit in Anspruch nehmen!..."
                            pv -tpreb /dev/${device[$ddec]} | dd bs=4M | gzip > ${imgfol}/$NOW/complete_wmsone.img.gz && sync
                            echo "Complete" > ${imgfol}/$NOW/state.txt
                        fi
                    fi

                    # Beschreiben des Backups
                    if [ $prf -eq 1 ]; then

                        i=0
                        read -p "Möchten Sie das Backup beschreiben? (y/n) " cdec
                        while [ $i -eq 0  ]; do
                            if [[ $cdec == "y" ]]; then
                                read -p "Einzeilige Beschreibung oder mittels vi? (e/v) " edec
                                j=0
                                while [ $j -eq 0  ]; do
                                    if [[ $edec == "v" ]]; then
                                        vi ${imgfol}/$NOW/comment.txt
                                        j=1
                                    elif [[ $edec == "e" ]]; then
                                        read -p "Beschreibung: " comment
                                        echo $comment > ${imgfol}/$NOW/comment.txt
                                        j=1
                                    else
                                        read -p "Auswahl nicht möglich. Wählen Sie (e)inzeilig oder (v)i! " edec
                                        j=0
                                    fi
                                done
                                i=1
                            elif [[ $cdec == "n" ]]; then
                                echo "Keine Beschreibung ausgewählt!"
                                echo "Keine Beschreibung angegeben!" > ${imgfol}/$NOW/comment.txt
                                i=1
                            else
                                read -p "Auswahl nicht möglich. Wählen Sie (y)es oder (n)o! " cdec
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

