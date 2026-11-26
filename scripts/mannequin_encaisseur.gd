extends CharacterBody3D
## Mannequin d'entraînement IMMORTEL : n'affiche pas de PV mais les dégâts subis (dernier coup, cumul combo, Poise)
## et fait apparaître des chiffres de dégâts flottants 3D façon Dokkan Battle.

@export_group("Statistiques Mannequin")
@export var poise_max : float = 100.0
@export var delai_regen_poise : float = 2.5
@export var vitesse_regen_poise : float = 35.0
@export var duree_brisure_garde : float = 1.8
@export var delai_reset_combo : float = 4.0

@onready var label_etat: Label3D = $Label3D
@onready var corps_mesh: MeshInstance3D = $CorpsMesh

var poise_actuelle : float = 100.0
var est_brise : bool = false
var temps_depuis_dernier_coup : float = 0.0
var dernier_degat : float = 0.0
var degats_combo_total : float = 0.0
var nb_coups_combo : int = 0
var gravite : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var materiau_corps : StandardMaterial3D

var _id_brisure : int = 0
var _id_flash : int = 0

const COULEUR_NORMALE := Color(0.75, 0.22, 0.17)
const COULEUR_BRISEE := Color(0.95, 0.75, 0.1)

func _ready() -> void:
	poise_actuelle = poise_max
	if corps_mesh.material_override is StandardMaterial3D:
		materiau_corps = corps_mesh.material_override
	EventBus.player_stats_recalculated.connect(_synchroniser_poise_sur_joueur)
	EventBus.player_realm_changed.connect(func(_n: int, _t: String) -> void: _synchroniser_poise_sur_joueur())
	_synchroniser_poise_sur_joueur.call_deferred()
	mettre_a_jour_affichage()

func _synchroniser_poise_sur_joueur() -> void:
	var j := get_tree().get_first_node_in_group("joueur")
	if is_instance_valid(j) and j.has_node("StatsComponent"):
		var s := j.get_node("StatsComponent") as StatsComponent
		if s:
			var ratio := poise_actuelle / maxf(1.0, poise_max)
			poise_max = s.get_poise_max() * 1.8
			poise_actuelle = 0.0 if est_brise else poise_max * ratio
			mettre_a_jour_affichage()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravite * delta

	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	temps_depuis_dernier_coup += delta
	if nb_coups_combo > 0 and temps_depuis_dernier_coup >= delai_reset_combo:
		degats_combo_total = 0.0
		nb_coups_combo = 0
		mettre_a_jour_affichage()

	if not est_brise and temps_depuis_dernier_coup >= delai_regen_poise and poise_actuelle < poise_max:
		poise_actuelle = minf(poise_max, poise_actuelle + maxf(vitesse_regen_poise, poise_max * 0.35) * delta)
		mettre_a_jour_affichage()

	move_and_slide()

func recevoir_degats_avances(degats_pv: float, degats_poise: float, position_attaquant: Vector3, est_counter: bool) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, position_attaquant, est_counter))

func recevoir_degats(degats_pv: float, degats_poise: float, position_attaquant: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, position_attaquant, false))

func recevoir_degats_info(info: DamageInfo) -> void:
	temps_depuis_dernier_coup = 0.0

	var multiplicateur_critique_posture : float = 1.5 if est_brise else 1.0
	var degats_effectifs : float = info.degats_pv * multiplicateur_critique_posture

	dernier_degat = degats_effectifs
	degats_combo_total += degats_effectifs
	nb_coups_combo += 1
	EventBus.entity_damaged.emit(self, info)

	NumberFormatter.spawn_floating_damage(self, global_position, degats_effectifs, info.est_critique, info.est_counter, est_brise)

	var dir_recul : Vector3 = global_position - info.position_origine
	dir_recul.y = 0.0
	dir_recul = dir_recul.normalized() if dir_recul.length_squared() > 0.0001 else Vector3.ZERO

	if not est_brise:
		poise_actuelle = maxf(0.0, poise_actuelle - info.degats_poise)
		velocity += dir_recul * 3.5

		if poise_actuelle <= 0.0:
			declencher_brisure_garde(dir_recul)
		else:
			flash_impact(Color(1.0, 1.0, 1.0))
	else:
		velocity += dir_recul * 6.0
		flash_impact(Color(1.0, 0.85, 0.0))

	mettre_a_jour_affichage()

func declencher_brisure_garde(dir_recul: Vector3) -> void:
	_id_brisure += 1
	_id_flash += 1
	var id_local := _id_brisure

	est_brise = true
	velocity += dir_recul * 12.0
	EventBus.entity_guard_broken.emit(self)
	print("BRISURE DE GARDE (POISE BROKEN) !")

	if materiau_corps:
		materiau_corps.albedo_color = COULEUR_BRISEE

	mettre_a_jour_affichage()

	await get_tree().create_timer(duree_brisure_garde).timeout
	if _id_brisure != id_local:
		return

	est_brise = false
	poise_actuelle = poise_max
	if materiau_corps:
		materiau_corps.albedo_color = COULEUR_NORMALE
	mettre_a_jour_affichage()

func flash_impact(couleur_flash: Color) -> void:
	if not materiau_corps:
		return
	_id_flash += 1
	var id_local := _id_flash
	materiau_corps.albedo_color = couleur_flash
	await get_tree().create_timer(0.08).timeout
	if _id_flash == id_local and materiau_corps:
		materiau_corps.albedo_color = COULEUR_BRISEE if est_brise else COULEUR_NORMALE

func mettre_a_jour_affichage() -> void:
	var ligne_degats := "Coup : %s | Combo : %s (%d)" % [
		NumberFormatter.format(dernier_degat),
		NumberFormatter.format(degats_combo_total),
		nb_coups_combo
	]
	if est_brise:
		label_etat.text = "%s\n[GARDE BRISÉE ! x1.5]" % ligne_degats
		label_etat.modulate = Color(1.0, 0.85, 0.0)
	else:
		label_etat.text = "%s\nPoise : %s" % [ligne_degats, NumberFormatter.format(poise_actuelle)]
		label_etat.modulate = Color(1.0, 1.0, 1.0)
