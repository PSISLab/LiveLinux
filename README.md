LiveLinux
=========

Tools for creating live systems, inspired from [https://help.ubuntu.com/community/LiveCDCustomizationFromScratch](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch)

Roadmap
-------

* _Versions futures_ 1.x
	* Création d'un paquet .deb
	* Vérification du périférique de destination avec la commande `write`, pour éviter un désastre
	* Gérer le partitionnement de l'image
	* Gérer un volume persistant privé
	* Gérer les mises à jour du système en lecture seule
* _Versions futures_ 2.x
	* Restaurer une version packagée, ou importer une image ISO
	* Gérer un volume persistant publique

Changelog
---------

* _Version de développement_
* Version __0.1__
	* Gestion des versions
	* Manipulation de variables avec les commandes `set` et `get`
	* Ecriture de l'image sur un périférique avec la commande `write`
	* Création d'une image disque ou ISO avec la command `release` 
	* Manipulation de l'environnement avec la commande `chroot`
	* Initialisation d'un environnement avec la command `setup`