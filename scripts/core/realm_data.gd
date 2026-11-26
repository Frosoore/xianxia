class_name RealmData
extends Resource
## Définition data-driven d'un Royaume de Cultivation (1 à 10), échelle exponentielle MMORPG / Dokkan Battle.

@export_group("Identité")
@export_range(1, 10) var niveau : int = 1
@export var nom : String = "Raffinement Corporel"
@export var titre_cosmologique : String = "Mortel"
@export_multiline var description : String = ""

@export_group("Prérequis de Percée (MMORPG)")
@export var niveau_requis : int = 1
@export var puissance_requise : float = 0.0
@export var qi_cultivation_requis : float = 400.0
@export var nb_eclairs_tribulation : int = 0
@export var difficulte_tribulation : float = 1.0
@export var a_epreuve_du_coeur : bool = false

@export_group("Statistiques de Base (Échelle Exponentielle)")
@export var pv_max_base : float = 150.0
@export var qi_max_base : float = 100.0
@export var regen_qi_base : float = 5.0
@export var endurance_max_base : float = 100.0
@export var regen_endurance_base : float = 7.5
@export var poise_max_base : float = 50.0
@export var multiplicateur_degats : float = 1.0

@export_group("Mobilité & Dash")
@export_range(0.0, 1.0) var facteur_cout_dash : float = 1.0
@export var cooldown_dash : float = 0.75
@export var peut_marcher_sur_eau : bool = false
@export var peut_voler_sur_epee : bool = false
@export var peut_vol_libre : bool = false
@export var peut_blink : bool = false

@export_group("Destruction & Ontologie")
@export_range(1, 10) var puissance_destruction : int = 1

func get_nom_affiche() -> String:
	return "Royaume %d : %s" % [niveau, nom]
