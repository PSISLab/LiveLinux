LiveLinux
=========

Tools for creating live systems, inspired from [https://help.ubuntu.com/community/LiveCDCustomizationFromScratch](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch)

TODO
----

### Configure auto-login

TO enable auto-login, set an admin user with `llm <target> set username <admin username>`. This user will be created at boot time.

If you prefer, you can also create an admin user with a fixed password in the chroot environment but make sure there is no user with ID 999.

### Set keymap



Roadmap
-------

* _Versions futures_ 1.x
	* Modifier le splash screen
	* Création d'un paquet .deb
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
	* Vérification du périférique de destination avec la commande `write`, pour éviter un désastre
	* Gérer le partitionnement de l'image
	* Gérer un volume persistant privé
	* Gérer les mises à jour du système/firmware
	* Calcul automatique de la taille de l'image nécessaire
	* Ecrire la version avant de générer l'image
* _Versions futures_ 2.x
	* Restaurer une version packagée, ou importer une image ISO
	* Gérer un volume persistant publique

Changelog
---------

* _Version de développement_
	* Possibilité de choisir la disposition du clavier au boot
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
* Version __0.1__ (27/11/2013)
	* Gestion des versions
	* Manipulation de variables avec les commandes `set` et `get`
	* Ecriture de l'image sur un périférique avec la commande `write`
	* Création d'une image disque ou ISO avec la command `release` 
	* Manipulation de l'environnement avec la commande `chroot`
	* Initialisation d'un environnement avec la command `setup`