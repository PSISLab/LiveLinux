LiveLinux
=========

Tools for creating live systems, inspired from [https://help.ubuntu.com/community/LiveCDCustomizationFromScratch](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch)

Installation
------------

	wget -O LiveLinux-0.2.tar.gz https://github.com/PSISLab/LiveLinux/archive/v0.2.tar.gz
	tar xzf LiveLinux-0.2.tar.gz
	sudo LiveLinux-0.2/setup.sh

Utilisation
-----------

`llm <target> <command> [command args...]`

Commandes :
* help [command]
* setup
* chroot [cmd [args...]]
* release [--iso] [--img] [[-m|--minor]|[-M|--major]|[-v|--version <major.minor.build>]
* write [-v|--version <version>] device
* set <var> <value>
* get <var>

### help

Affiche l'aide

### setup

Initialise un espace de travail pour créer la distribution live.

### chroot [cmd [args...]]

Permet de lancer l'espace de travail (dans un chrot) pour pouvoir y apporter des modifications. Si une commande est spécifiée avec l'option `cmd [args...]`, alors cette commande est executée dans l'espace de travail.

### release [--iso] [--img [--write <device>]] [[-m|--minor]|[-M|--major]|[-v|--version <major.minor.build>]

Crée une image ISO ou une image disque de l'espace de travail. Il faut choisir au moins une option parmis `--iso` et `--img`, sinon aucune image n'est générée.
Il est aussi possible d'utiliser l'option `--write <device>` conjointement à `--img` afin de copier l'image disque générée sur le disque spécifié (voir la commande `write`).

Par défaut le numéro de build du projet est incrémenté de 1 avant de créer l'image. Cela peut être controlé avec les options suivantes :
* `-m` ou `--minor` : Incrémente la version mineure du projet
* `-M` ou `--major` : Incrémente la version majeur du projet
* `--version` : Force la version du projet

### write [-v|--version <version>] device

Copie la dernière image disque sur le périfiérique spécifié. ATTENTION ! Aucune confirmation n'est demandée !

L'option `-v` ou `--version` permet de choisir quelle image copier.

HOWTO
-----

### Configurer le login automatique

Pour activer le login automatique d'un utilisateur, il faut utiliser la commande `llm <target> set autologin <username>`.

L'utilisateur doit exister. Il est par exemple possible de le créer avec la commande `llm <target> chroot adduser <username>`.

Pour désactiver le login automatique, utiliser simplement `llm <target> unset autologin`

### Changer la configuration clavier

Utiliser la commande `llm <target> chroot dpkg-reconfigure keyboard-configuration`

Roadmap
-------

* _Versions futures_ 1.x
	* Installation de la version serveur par défaut
	* Modifier le splash screen
	* Création d'un paquet .deb
	* Gérer le partitionnement de l'image
	* Gérer un volume persistant privé
	* Gérer les mises à jour du système/firmware
	* Ecrire la version avant de générer l'image
* _Versions futures_ 2.x
	* Restaurer une version packagée, ou importer une image ISO
	* Gérer un volume persistant publique

Changelog
---------

* _Version de développement_
* Version __0.2__ (01/12/2013)
	* Calcul automatique de la taille de l'image nécessaire
	* Vérification du périférique de destination avec la commande `write`, pour éviter un désastre
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
	* Possibilité de choisir la disposition du clavier au boot
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
* Version __0.1__ (27/11/2013)
	* Gestion des versions
	* Manipulation de variables avec les commandes `set` et `get`
	* Ecriture de l'image sur un périférique avec la commande `write`
	* Création d'une image disque ou ISO avec la command `release` 
	* Manipulation de l'environnement avec la commande `chroot`
	* Initialisation d'un environnement avec la command `setup`