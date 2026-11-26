# Game Design Document & Architecture Technique Godot 4

## Projet : Xianxia 2.5D Game

# 1\. Concept Fondamental (Core Concept)

Le projet **Xianxia 2.5D Game** est un Action-RPG 2.5D (style HD-2D) de fantasy orientale orienté **Xianxia Power Fantasy**. Il combine la profondeur théorique et narrative de la cultivation issue de *Tale of Immortal* avec l'exploration libre, le dynamisme et le sentiment d'accomplissement caractéristiques d'un *Elden Ring* ou *Skyrim*, le tout propulsé par le moteur **Godot 4**.  
**Structure Narrative Inspirée du Murim :** Le début de l'aventure emprunte au genre Murim sa hiérarchie claire (Sectes Orthodoxes vs Sectes Démoniaques, tournois de disciples) pour cadrer la progression initiale avant que l'échelle de puissance ne bascule pleinement dans le Xianxia cosmique.  
**Méthodologie de Production (Prototype / Bac à sable) :** Le prototype Godot 4 actuel sert de laboratoire de tests (« brouillon ») pour valider les sensations de jeu et les idées de gameplay avant la production finale (réalisée sans code généré par IA afin de respecter les choix de l'équipe).

# 2\. Piliers de Gameplay

* **La Power Fantasy et le Changement d'Échelle :** Évolution drastique d'un mortel vulnérable luttant contre la famine et des brigands vers une entité divinement puissante capable de fendre les montagnes et d'altérer le monde.  
* **Le Système de Cultivation et les Percées :** Absorption de Qi, accumulation de pilules et confrontation aux Tribulations Célestes (éclairs divins, démons du cœur) lors du franchissement des seuils de puissance.  
* **Synergies des Racines Spirituelles et Arts Martiaux :** Combinaisons d'éléments (Feu, Eau, Éclair, Vent, Terre, Bois) et manuels de Qi pour personnaliser un build de sorts et d'enchaînements uniques.  
* **Un Monde Ouvert Vivant et sans PNJ Immortels :** Exploration totalement débridée dès la fin de l'introduction. Aucun PNJ n'est immortel : la mort définitive de n'importe quelle entité ferme irréversiblement ses quêtes mais débloque le pillage et des conséquences systémiques (vengeances de secte, rivalités).  
* **Destruction Environnementale Dynamique :** Impact direct de la puissance du cultivateur sur le décor (rochers, bâtiments, arbres, falaises) qui se brise sous les attaques et les projections de Qi.

# 2.1. Système de Combat & Dynamic Fast-Paced Mobility

* **Dash Nerveux (Double-Tap) :** Déclenché par une double pression rapide sur une touche de direction. Consomme une faible quantité d'endurance en début de jeu, puis devient totalement gratuit avec l'élévation des royaumes. Son cooldown évolue progressivement selon le royaume de cultivation (de **0,75 seconde** au Royaume 1 jusqu'à **0,05–0,1 seconde** au Royaume 10). De plus, la régénération d'endurance de base est volontairement exigeante aux premiers royaumes (ex: **7,5/s** au Royaume 1\) pour imposer une réelle gestion de ressource, avant d'augmenter avec l'ascension et les investissements du joueur.  
* **Propriétés Défensives du Dash :** Octroie des fenêtres d'invulnérabilité (iFrames), réduit drastiquement les dégâts subis et booste temporairement la Poise durant son exécution.  
* **Parade & Contre-Attaque (Sekiro & SWBF2) :** Fenêtre de déviation (Parry) inspirée de *Sekiro* au moment de lever la garde, annulant dégâts et recul tout en infligeant de lourds dégâts de Poise à l'attaquant. Maintenir la garde donne un blocage standard (consomme de l'endurance, léger blockstun). Inspiré de *SWBF2*, appuyer sur **Attaquer tout en maintenant la garde enfoncée** pendant le recul déclenche une contre-attaque ultra-rapide sous protection constante. Ce contre n'est pas boosté en dégâts : sa force réside uniquement dans sa vitesse d'exécution extrême et le fait qu'il soit très difficilement bloquable.  
* **Attaques, Combos & Dash Cancel :** Enchaînement de base en 3 coups (coups 1 et 2 rapides à faible coût d'endurance ; 3ème coup *Finisher* plus large avec multiplicateur de dégâts et de dégâts de Poise). Possibilité d'interrompre instantanément une attaque en cours via un Dash Cancel pour maximiser la réactivité. Le dash aérien permet également un maintien temporaire de l'altitude (gravité suspendue pendant l'exécution).  
* **Attack Commitment & Inertie des Coups :** Lorsqu'une attaque est déclenchée, le personnage est verrouillé dans la direction de son coup et emporté vers l'avant par une brève impulsion physique (un pas engagé sur les coups normaux, plus prononcé sur le 3ème coup *Finisher*), l'empêchant de tourner, marcher ou sauter pendant toute la durée de l'attaque. La **seule échappatoire possible** durant cette fenêtre d'engagement est l'exécution d'un **Dash Cancel** (double-tap).  
* **Engagement Réduit sur le Counter (SWBF2) :** Lors d'une contre-attaque déclenchée depuis la garde (façon *Star Wars Battlefront II*), la durée d'engagement (*commitment*) et l'impulsion vers l'avant sont drastiquement réduites, permettant au joueur de conserver sa garde levée et de retrouver quasi instantanément sa mobilité.  
* **Système de Poise & Brisure de Garde (Stagger) :** Jauge d'équilibre régissant la résistance à l'interruption d'attaque, renforcée par le raffinement corporel et l'élévation du royaume. La Poise se régénère automatiquement après un délai sans subir d'impact. Lorsque la Poise tombe à 0, une Brisure de Garde (Stagger) est déclenchée, entraînant une forte projection en arrière, un étourdissement temporaire et un bonus de dégâts subis (coups critiques de posture) tant que la garde reste brisée.

# 2.2. Système MMORPG, Niveau Indépendant, Percées (Skill + Luck) & Échelle Dokkan Battle

* **Double Progression (Niveau indépendant du Royaume) :** Le personnage possède un **Niveau MMORPG** (`Niv. 1 → 600+`) alimenté par l'XP de combat, d'exploration et de méditation, totalement distinct de son **Royaume de Cultivation (1 à 10)**. Chaque niveau renforce globalement le personnage et accorde des points de statistiques libres à répartir entre 5 Voies : **Vélocité**, **Esprit**, **Épée**, **Corps** et **Chance / Destin (Luck)**.
* **Changement de Royaume Long, Exigeant & Mérité :** Passer d'un Royaume au suivant demande une vraie préparation (Cultivation longue à charger, **Niveau minimum requis** et **seuil de Puissance Globale**). Une fois la Tribulation Céleste lancée, le verdict final combine :
  * **Le Skill (~80 % du poids)** : construit en temps réel pendant la Tribulation via les **Parrys Célestes** sur les éclairs, les **Esquives Parfaites (Dash iFrames)** et le placement, sanctionné lourdement en cas d'éclair encaissé.
  * **La Luck / Destin (~20 % du poids)** : apportée par la stat *Chance* et un léger aléa cosmique ; insuffisante seule pour compenser un manque de maîtrise, mais capable de faire pencher une tentative serrée.
* **Échelle de Puissance Exponentielle (Style Dragon Ball Z Dokkan Battle) :** Les écarts entre Royaumes sont **gigantesques**. On démarre à quelques **dizaines de dégâts** au Royaume 1, pour monter aux **milliers** au Royaume 3, aux **millions / centaines de millions** aux Royaumes 6–8, puis aux **milliards / trillions** aux Royaumes 9–10, avec formatage `K / M / B / T` et chiffres flottants 3D à l'impact.
* **Cosmologie & Endgame Méta-Narratif (Powerscaling SCP-CN × H.P. Lovecraft) :** À haut Royaume (R7 → R10), le jeu bascule volontairement dans le powerscaling cosmologique et ontologique extrême : manipulation causale (*Coupure Causale*), effacement d'axiomes et réécriture des règles du monde (*Rature Narrative*). La **dernière zone du jeu** (*L'Abîme Hors-Récit*) est peuplée d'entités eldritch et transcendantes capables de modeler la réalité et la couche narrative du combat (altération dynamique des lois physiques, réécriture temporaire du HUD ou des règles d'affrontement).
* **Grandes Voies / Spécialisations :**  
  * **Voie de la Vélocité / Mobilité :** Investissement massif en Endurance, régénération, réduction de cooldown, compétences de déplacement et dashs en chaîne.  
  * **Voie des Arts Mystiques / Magie :** Qi maximal, puissance des techniques élémentaires, causales et sorts à distance.  
  * **Voie de l'Épée (Sword Cultivator) :** Dégâts critiques, vitesse d'attaque, maîtrise de l'épée volante et parades offensives.  
  * **Voie du Raffinement Corporel / Défense :** PV max, Poise / équilibre inébranlable, réduction de dégâts et combat rapproché brutal.
  * **Voie du Destin / Chance (Luck) :** Taux de coup critique, butin rare et faveur du Destin lors des Tribulations de Percée.

# 3\. Échelle des Royaumes de Cultivation (Progression)

| Royaume (Sous-niveaux) | Mobilité & Dash | Poise & Défense | Destructibilité du Décor | Tribulation & Capacité |
| :---- | :---- | :---- | :---- | :---- |
| **1\. Raffinement Corporel** | Course à pied, Dash basique (Coût standard). | Poise très faible, vulnérable aux stuns. | Impacts mineurs (vases, petit mobilier). | Aucune. Renforcement musculaire pur. |
| **2\. Condensation du Qi** | Sprint rapide, Dash fluide (-25% coût). | Poise modérée via enveloppe de Qi. | Fissures sur structures en bois/clôtures. | Purification du Qi, sorts élémentaires de base. |
| **3\. Établissement de la Fondation** | Marche sur l'eau, Dash très peu coûteux (-50%). | Hyper-armor moyenne sur attaques chargées. | Destruction de rochers et murs légers. | 3 Éclairs Célestes. Barrière de Qi active. |
| **4\. Noyau d'Or** | Vol sur épée (Sword Flying), Dash quasiment gratuit (-80%). | Forte résistance à l'interruption. | Effondrement d'arbres et petites maisons. | 6 Éclairs & Épreuve du Cœur. Domaine mineur. |
| **5\. Âme Naissante** | Vol libre rapide, Dash totalement gratuit (0 coût). | Poise massive, quasi inébranlable. | Destruction d'édifices complets et falaises. | 9 Éclairs & Démons intérieurs. Avatar spirituel. |
| **6\. Transformation de la Divinité** | Téléportation instantanée (Blink), Dash sans coût avec iFrames étendues. | Insensibilité aux Stagger ordinaires. | Dévastation du paysage et cratères immenses. | 12 Éclairs \+ Jugement Dao. Contrôle spatial. |
| **7\. Raffinement du Vide** | Vol suprasonique, traversée de la matière par Dash. | Poise divine, régénération de garde instantanée. | Ondes de choc rasant les reliefs environnants. | Tribulation du Vide. Fusion avec la matière. |
| **8\. Fusion / Intégration du Dao** | Mouvement omniprésent, Dash intangible. | Immunité au contrôle de foule classique. | Destruction environnementale à grande échelle. | Tribulation Élémentaire Ultime. Lois du Dao. |
| **9\. Grande Ascension / Demi-Immortel** | Déplacement absolu dans l'arène/monde. | Corps invulnérable par défaut. | Annihilation de l'environnement à chaque impact. | Tribulation d'Ascension Immortelle (81 Éclairs). |
| **10\. Immortel Véritable** | Mouvement divin irréalisable pour des mortels. | Poise et stabilité absolues. | Refaçonnage du monde à volonté. | Transcendance complète. Libération du cycle. |

# 4\. Direction Artistique et Technique (2.5D / HD-2D sous Godot 4\)

* **Environnements 3D :** Reliefs, montagnes enneigées et temples construits en 3D avec shaders de brume (Volumetric Fog), effets de lumière dynamique, et ombres projetées.  
* **Personnages & Effets 2D :** Sprites 2D haute résolution intégrés via **Sprite3D** avec gestion de la bilatéralité, activation des options *Shaded*, *Alpha Cut* et cartes de normales (Normal Maps) pour réagir à l'éclairage 3D.  
* **Règle d'Échelle Stricte (Pixel Density) :** Densité fixe établie à **1 mètre unit (3D) \= 128 pixels** afin d'assurer une cohérence visuelle parfaite entre les sprites et le décor 3D.

# 5\. Architecture Logicielle Godot 4 (Arborescence & Découplage)

## Organisation des dossiers (Project Structure)

```
res://
├── assets/
│   ├── 2d/ (sprites, textures, ui)
│   ├── 3d/ (meshing, environments)
│   ├── audio/ (sfx, bgm)
│   └── vfx/ (particles, shaders)
├── resources/ (Custom Resources .tres)
│   ├── items/
│   ├── realms/
│   └── skills/
├── scenes/
│   ├── characters/ (player, npcs, enemies)
│   ├── environment/ (levels, shrines)
│   ├── system/ (autoloads, game_manager)
│   └── ui/
└── scripts/
    ├── autoload/ (EventBus.gd, AudioManager.gd)
    ├── components/
    └── core/
```

## Architecture par Scènes, Signaux et Resources

* **EventBus Global (Autoload) :** Pattern observateur centralisé via un singleton *EventBus.gd* pour émettre et écouter les évènements système (ex. *qi\_changed*, *breakthrough\_started*, *entity\_died*) sans couplage fort.  
* **Data-Driven via Custom Resources (.tres) :** Utilisation massive de la classe **Resource** pour définir les compétences, manuels de Qi, royaumes et objets, facilitant le travail d'équilibrage sans toucher au code.  
* **Gestion Dynamique des Statistiques (StatsComponent) :** Les statistiques finales du joueur (endurance max, regen, coût/cooldown de dash, Poise, Qi) sont calculées dynamiquement via un composant dédié combinant : *Base du Royaume \+ Points de Stats \+ Bonus Passifs/Actifs des Arbres de Compétences*, plutôt d'être uniquement indexées sur le niveau de royaume.

# 6\. Répartition des Rôles de l'Équipe (3 à 4 Personnes)

* **Pôle 1 \- Architecture RPG & Systèmes :** Gestion de la Cultivation, des Percées, du Karma, des Inventaires, du système de Sauvegarde et de l'UI.  
* **Pôle 2 \- Gameplay Joueur & Combat :** Contrôleur Joueur 2.5D, physique des mouvements, mécanique de Vol sur épée (Sword Flying) et Hitboxes/Hurtboxes de combat.  
* **Pôle 3 \- World Building & IA :** Environnements 3D, Shaders graphiques (eau, brume, dissipation de Qi), éclairage dynamique et IA des bêtes spirituelles/ennemis.  
* **Pôle 4 (Optionnel / Polyvalent) \- Art 2D, VFX & Narration :** Direction artistique des Sprites 2D, animations de combat, effets de sorts (VFX), Sound Design et écriture du Lore.

# 7\. Feuille de Route (Roadmap)

* **Phase 1 : Socle Physique & Caméra 2.5D \[Terminée\]** \- Déplacement du personnage 2.5D, configuration de la caméra 3D orthographique/perspective et gestion des collisions de base.  
* **Phase 2 : Prototype de Combat & Bac à Sable \[En cours / Avancé\]** \- Intégration du HUD (Endurance, Qi, Royaume), combo en 3 temps, Dash Cancel, Parry à la Sekiro, Counter à la SWBF2, gestion de Poise/Stagger et arène de test avec deux mannequins (Encaisseur et Attaquant en boucle).  
* **Phase 3 : Pistes de Prototypage Suivantes & Première Percée** \- Méditation et chargement actif du Qi, première percée du royaume Mortel vers Établissement de la Fondation avec déclenchement des éclairs de tribulation en temps réel, vol sur épée, premiers sorts élémentaires et test de destruction du décor (rocher/mur).  
* **Phase 4 : Vertical Slice** \- Niveau complet "Vallée de la Brume d'Émeraude", autel de percée, 3 types d'ennemis, 1 mini-tribulation céleste et 1 boss gardien.