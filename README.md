LiveLinux
=========

Tools for creating live systems, inspired from [https://help.ubuntu.com/community/LiveCDCustomizationFromScratch](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch)

Roadmap
-------

* _Versions futures_ 1.x
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
	* Possibilité de modifier les paramètres Casper (login, hostname, ect)
* Version __0.1__ (27/11/2013)
	* Gestion des versions
	* Manipulation de variables avec les commandes `set` et `get`
	* Ecriture de l'image sur un périférique avec la commande `write`
	* Création d'une image disque ou ISO avec la command `release` 
	* Manipulation de l'environnement avec la commande `chroot`
	* Initialisation d'un environnement avec la command `setup`