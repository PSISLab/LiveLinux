LiveLinuxMaker
==============

Tool for creating live linux system.
(See also [LiveCDCustomizationFromScratch](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch)).


Installation
------------

	wget -O LiveLinux-0.2.tar.gz https://github.com/PSISLab/LiveLinux/archive/v0.2.tar.gz
	tar xzf LiveLinux-0.2.tar.gz
	sudo LiveLinux-0.2/setup.sh


Utilisation
-----------

`llm <target> <command> [command args...]`

Commandes disponibles :

* help : Affiche l'aide
* setup : Initialise un espace de travail 
* chroot : Lance l'espace de travail (dans un chrot) pour pouvoir y apporter des modifications
* release : Crée une image ISO ou une image disque de l'espace de travail
* releases : Affiche la liste des images crées
* write : Copie la l'image disque sur un disque
* set : Définit une variable de configuration
* unset : Supprime une variable de configuration
* get : Lit une variable de configuration


Détail des commandes
--------------------

### **help** : Affiche l'aide

Utilisation : `llm <target> help [command]`

Si `command` est spécifiée, affiche l'aide relative à cette commande.

### **setup** : Initialise un espace de travail

Utilisation : `llm <target> setup`

Crée le dossier `<target>` et installe un espace de travail pour éditer la nouvelle distribution live.

### **chroot** : Lance l'espace de travail (dans un chrot) pour pouvoir y apporter des modifications

Utilisation : `llm <target> chroot [cmd [args...]]`

Si une commande est spécifiée avec l'option `cmd [args...]`, alors elle est executée dans l'espace de travail. Sinon, un shell est démarré.

### **release** : Crée une image ISO ou une image disque de l'espace de travail

Utilisation : `llm <target> release [--iso] [--img [--write <device>]] [[-m|--minor]|[-M|--major]|[-v|--version <major.minor.build>]`

Il faut choisir au moins une option parmis `--iso` et `--img`, sinon aucune image n'est générée.
Il est aussi possible d'utiliser l'option `--write <device>` conjointement à `--img` afin de copier l'image disque générée sur le disque spécifié (voir la commande `write`).

Par défaut le numéro de build du projet est incrémenté de 1 avant de créer l'image. Cela peut être controlé avec les options suivantes :

* `-m` ou `--minor` : Incrémente la version mineure du projet
* `-M` ou `--major` : Incrémente la version majeur du projet
* `--version` : Force la version du projet

### **releases** : Affiche la liste des images crées

Utilisation : `llm <target> releases`

### **write** : Copie la l'image disque sur un disque

Utilisation : `llm <target> write [-v|--version <version>] device`

L'option `-v` ou `--version` permet de choisir quelle version d'image copier. Sinon, la dernière version générée est copiée.

### **set** : Définit une variable de configuration

Utilisation : `llm <target> set <var> <value>`

### **unset** : Supprime une variable de configuration

Utilisation : `llm <target> unset <var>`

### **get** : Lit une variable de configuration

Utilisation : `llm <target> get <var>`


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
	* Possibilité de choisir la disposition du clavier au boot
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
	* GPL V3
* Version __0.1__ (27/11/2013)
	* Gestion des versions
	* Manipulation de variables avec les commandes `set` et `get`
	* Ecriture de l'image sur un périférique avec la commande `write`
	* Création d'une image disque ou ISO avec la command `release` 
	* Manipulation de l'environnement avec la commande `chroot`
	* Initialisation d'un environnement avec la command `setup`
