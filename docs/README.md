# LinkyMonitor
Exploiter et Afficher les infos des compteurs électriques Linky (EDF)

<b>Pourquoi?</b> (Origine du projet)<br/>
J'ai dit oui au linky après qu'ils m'aient assuré que ce serait transparent pour l'EJP et pour la production photovoltaïque..<br/>
Pour la prod, c'est OK. <br/>
Pour l'EJP, il n'y a plus d'asservissement, ni de préavis disponible. <br/>
Les relais asservis sur un signal analogique spécifique ne fonctionnent plus. Perte totale de la loupiotte orange qui me signalait les jours EJP.<br/>
Pas content, il fallait faire quelque chose…<p/>
On veut au minimum pouvoir:<ul>
<li>Allumer une LED qui nous prévient des périodes EJP</li>
<li>Afficher les consommation et la production en temps réel</li>
<li>Pouvoir loguer tout ça pour faire des stats</li></ul>

<b>Comment?</b><br/>
Le linky offre une interface série spécifique qui se monitore assez facilement via une raspberry.<br/>
C'est très bien documenté là: <a href="https://blog.bigd.fr/suivre-sa-consommation-electrique/">https://blog.bigd.fr/suivre-sa-consommation-electrique/</a><br/>
Le linky offre aussi un relais connecté en cas d'EJP.<p>
Il va donc falloir:<ul>
<li>Bricoler un peu d'électronique pour s'interfacer à l'interface série du Linky</li>
<li>Créer un petit script d'acquisition et stockage des données Linky (ici on a choisi de faire tourner ça sur RPi zéro)</li>
<li>Afficher les données en temps réel sur un petit écran OLED</li>
<li>Intégrer tout ça à un boitier DIY</li>
</ul>
<hr/>

<b>Interface physique avec le compteur Linky</b><br/>
Tout est sur le site de Charles Hallard (<a href="http://hallard.me/demystifier-la-teleinfo/">http://hallard.me/demystifier-la-teleinfo/</a><br/>
Pour la carte d'acquisition, ça ressemble à ceci:<br/>
<img width="50%" src="http://hallard.me/blog/wp-content/uploads/2015/07/montage-de-base-1024x547.jpg"/>
<hr/>

<b>Scripts acquis et visualisation</b><br/>
<b>LinkyAcq.pl</b><br/>
Process chargé des acquisitions :<ul> 
<li>Aquiert les lignes linky sur /dev/ttyAMA0, Acquisition avec timeout en cas de pb, Acquisition de chaque ligne avec vérification du checksum</li>
<li>Lit les variables <b>HCHC</b>: index heures creuses, <b>HCHP</b>: index heures pointe, <b>PTEC</b>: type de période ("HN.." pour les heures normales), IINST: intensité vue par le compteur, <b>PAPP</b>: puissance consommée</li>
<li>Si lancé avec l'option -l : Rafraichit l'écran OLED avec la valeur EJP (OUI|NON) et les valeurs PAPP et PINJ en KW (calculé:  (PAPP=0)?IINST*0.22:0  )</li>
<li>Attend une série de N lignes PAPP (par défaut 8 occurrences configurable dans fichier de conf), les transforme en une ligne de logs au format suivant<br>
<tt>2021/02/20 19:10:22	DATA	Periode=HN.., IndexHN=000688322, IndexHPM=000080072, PuissConsommee=00000, IConsommee=013</tt>
</li>
</ul>


<b>LinkyGraphCreate.pl</b><br/>
Process chargé des visualisations HTML:<ul> 
<li> lire les lignes DATA d'un fichier de log journalier</li>
<li> Calcule la puissance injectée en se basant sur IINST et sur une PAPP=0</li>
<li>Calcule les totaux consommés et les coûts associés</li>
</ul>
LinkyGraphCreate produit une page HTML utilisant le module <a href="https://dygraphs.com">DyGraphs</a>, bibliothèque javascript de visualisation de données.
(<a href="https://dygraphs.com/LICENSE.txt">MIT license</a>)
<hr/>

<b>Un peu de documentation</b><br/>
<b>LinkyMonitoriDoc.pdf</b><br/>
Le descriptif complet de la config OS sur RPi, du cablage, et de l'exploitation des scripts

<p>Have fun...</p>

