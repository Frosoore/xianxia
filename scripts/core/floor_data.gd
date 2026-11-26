class_name FloorData
extends Resource
## Définition d'un des 100 Étages Dimensionnels (thème, biome, densité de monstres, atmosphère, taille).

enum Biome {
	PRAIRIE_JADE,
	FORET_BAMBOUS,
	STEPPE_SILENCIEUSE,
	DESERT_ARIDE,
	NEIGE_ETERNELLE,
	VOLCAN_CELESTE,
	MER_NUAGES,
	RUINES_NOCTURNES,
	CITADELLE_DAO,
	ABIME_HORS_RECIT
}

@export_range(1, 100) var numero_etage : int = 1
@export var nom : String = "Les Prairies de Jade Brumeux"
@export var sous_titre : String = "Premier Ciel — Terre des Mortels"
@export var biome : Biome = Biome.PRAIRIE_JADE
@export_range(1, 10) var royaume_recommande : int = 1
@export var niveau_recommande : int = 1
@export var densite_monstres : String = "Modérée"
@export var taille_dimension : float = 240.0
@export var couleur_ciel_haut : Color = Color(0.18, 0.42, 0.52, 1.0)
@export var couleur_ciel_horizon : Color = Color(0.62, 0.82, 0.78, 1.0)
@export var couleur_brume : Color = Color(0.46, 0.72, 0.66, 1.0)
@export var couleur_sol : Color = Color(0.22, 0.34, 0.24, 1.0)
@export var densite_brume : float = 0.0055
@export var scene_dediee : String = ""

func get_titre_complet() -> String:
	return "Étage %d / 100 — %s" % [numero_etage, nom]
