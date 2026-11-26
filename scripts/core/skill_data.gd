class_name SkillData
extends Resource
## Définition data-driven d'une technique de Qi ou d'un art martial (GDD §2 & §5).

enum Element {
	NEUTRE,
	FEU,
	EAU,
	ECLAIR,
	VENT,
	TERRE,
	BOIS,
	CAUSAL,
	NARRATIF
}

enum TypeCompetence {
	PROJECTILE,
	ZONE,
	BARRIERE,
	BUFF,
	MELEE_SPECIALE,
	META_NARRATIF
}

@export_group("Identité")
@export var id : StringName = &""
@export var nom : String = "Technique de Qi"
@export_multiline var description : String = ""
@export var element : Element = Element.NEUTRE
@export var type_competence : TypeCompetence = TypeCompetence.PROJECTILE
@export_range(1, 10) var royaume_requis : int = 1

@export_group("Coûts & Rythme")
@export var cout_qi : float = 20.0
@export var cout_endurance : float = 0.0
@export var cooldown : float = 2.0
@export var duree : float = 0.4

@export_group("Effets & Combat")
@export var degats_pv_base : float = 30.0
@export var degats_poise_base : float = 25.0
@export var portee : float = 10.0
@export var vitesse_projectile : float = 18.0
@export var rayon_zone : float = 2.5
@export_range(0, 10) var bonus_destruction : int = 0
@export var couleur_vfx : Color = Color(0.2, 0.85, 1.0, 1.0)
