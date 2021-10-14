#!/bin/bash

obligatoire=0

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
    if [[ "$2" =~ [A-Za-z0-9]* ]] || [ "$2" = "" ]
    then
        echo ""
        echo "Voici les parametres :"
        echo "-h OU --help : affiche les aides"
        echo "[OBLIGATOIRE] -d OU --data-base : specifie le nom de la base de donnees"
        echo "[OBLIGATOIRE] -u OU --user: specifie le nom de l'utitilisateur"
        echo "[OBLIGATOIRE] -p OU --password : specifie le mot de passe de l'utilisateur de la base de donnee"
        echo "[OBLIGATOIRE] -i OU --ip : specifie l'interface reseaux a utiliser OU l'adresse IP (v4 ou v6)"
        echo ""
        exit
    else
        echo "Parametre incorrect pour "$1
        echo "Utiliser l'option -h ou --help pour afficher les options"
    fi
fi

number=$((($#/2)+1))

while [ "$number" -gt 0 ]
do
    if [ "$1" = "-d" ] || [ "$1" = "--data-base" ]
    then
        if [[ "$2" =~ [A-Za-z0-9]* ]]
        then
            dataname=$2
            obligatoire=$(($obligatoire+1))
            shift
            shift
        else
            echo ""
            echo "Parametre incorrect pour "$1
            echo "Utiliser l'option -h ou --help pour afficher les options"
            echo ""
            exit
        fi
    fi

    if [ "$1" = "-u" ] || [ "$1" = "--user" ]
    then
        if [[ "$2" =~ [A-Za-z0-9]* ]]
            then
                datauser=$2
                obligatoire=$(($obligatoire+1))
                shift
                shift
            else
                echo ""
                echo "Parametre incorrect pour "$1
                echo "Utiliser l'option -h ou --help pour afficher les options"
                echo ""
                exit
            fi
    fi

    if [ "$1" = "-p" ] || [ "$1" = "--password" ]
    then
        datapdw=$2
        obligatoire=$(($obligatoire+1))
        shift
        shift
    fi

    if [ "$1" = "--ip" ]
    then
        if [[ "$2" =~ [a-zA-Z0-9]* ]] || [ "$2" != "" ]
        then
            ip=$2
            obligatoire=$(($obligatoire+1))
            shift 2
        else
			echo ""
            echo "Parametre incorrect pour "$1
            echo "Utiliser l'option -h ou --help pour afficher les options"
            echo ""
            exit
        fi
    fi
	number=$(($number-1))

    if [ "$1" = "-i" ]
    then
        if [[ "$2" =~ [a-zA-Z0-9]* ]] || [ "$2" != "" ]
        then
            interfaces=$2
            ip=$(ifconfig $interfaces | awk '/inet / {print $2}' | cut -d ':' -f2)
            obligatoire=$(($obligatoire+1))
            shift 2
        else
            echo ""
            echo "Parametre incorrect pour "$1
            echo "Utiliser l'option -h ou --help pour afficher les options"
            echo ""
            exit
        fi
    fi
    number=$(($number-1))
done
if [ "$obligatoire" -lt 4 ]
then
    echo ""
    echo "Certaines options obligatoire ne sont pas renseigner correctement ($obligatoire sur 4)"
    echo "Utiliser l'option -h ou --help pour afficher les options"
    echo ""
    exit
fi

echo "Voici un resumer des informations"
echo ""
echo "Nom de la base de donnees : $dataname"
echo "Nom de l'utilisateur de la base de donnees : $datauser"
echo "Mot de passe de l'utilisateur de la base de donnees: $datapdw"
echo "Adresse IP avec laquel sera configurer le serveur : $ip"
echo ""
echo "Ces informations sont-elles correct ? (o/N) : "
read valide
if [ $valide = "n" ] || [ $valide = "N" ] || [ $valide = "" ]
then
	exit
fi