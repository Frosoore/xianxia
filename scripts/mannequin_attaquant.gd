extends CharacterBody3D
## Mannequin Attaquant IMMORTEL (HD-2D Pixel Art) : teste le Parry, le Block et le Counter.

@export var intervalle_attaque : float = 2.2
@export var ratio_degats_pv_joueur : float = 0.16
@export var degats_poise_coup : float = 30.0
@export var poise_max : float = 100.0
@export var duree_brisure_garde : float = 2.0
@export var delai_reset_combo : float = 4.0

@onready var sprite_3d: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var animator_25d: SpriteAnimator25D = get_node_or_null("SpriteAnimator25D") as SpriteAnimator25D
@onready var label_etat: Label3D = $Label3D
@onready var zone_attaque: Area3D = $ZoneAttaqueEnnemi
@onready var visuel_coup: MeshInstance3D = %VisuelCoupEnnemi

var poise_actuelle : float = 100.0
var est_brise : bool = false
var joueur_cible : Node3D = null
var cibles_touchees_coup_actuel : Array = []
var _id_brisure : int = 0

var dernier_degat : float = 0.0
var degats_combo_total : float = 0.0
var nb_coups_combo : int = 0
var temps_depuis_dernier_coup : float = 0.0
var _statut_action : String = ""

const COULEUR_BASE_SPRITE := Color(0.92, 0.78, 1.15, 1.0)
const COULEUR_TELEGRAPHE_SPRITE := Color(1.45, 0.55, 0.85, 1.0)
const COULEUR_BRISEE_SPRITE := Color(1.25, 1.05, 0.45, 1.0)

func _ready() -> void:
	poise_actuelle = poise_max
	if is_instance_valid(sprite_3d):
		sprite_3d.modulate = COULEUR_BASE_SPRITE
	if is_instance_valid(animator_25d) and is_instance_valid(sprite_3d):
		animator_25d.initialiser(sprite_3d)

	zone_attaque.monitoring = false
	visuel_coup.visible = false
	zone_attaque.body_entered.connect(_on_zone_attaque_body_entered)
	EventBus.player_stats_recalculated.connect(_synchroniser_poise_sur_joueur)
	EventBus.player_realm_changed.connect(func(_n: int, _t: String) -> void: _synchroniser_poise_sur_joueur())
	_synchroniser_poise_sur_joueur.call_deferred()
	_mettre_a_jour_label()
	boucle_attaque()

func _synchroniser_poise_sur_joueur() -> void:
	var j := get_tree().get_first_node_in_group("joueur")
	if is_instance_valid(j) and j.has_node("StatsComponent"):
		var s := j.get_node("StatsComponent") as StatsComponent
		if s:
			var ratio := poise_actuelle / maxf(1.0, poise_max)
			poise_max = s.get_poise_max() * 1.8
			poise_actuelle = 0.0 if est_brise else poise_max * ratio
			_mettre_a_jour_label()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(joueur_cible):
		joueur_cible = get_tree().get_first_node_in_group("joueur")
		if not joueur_cible and get_parent():
			joueur_cible = get_parent().get_node_or_null("Joueur")

	if is_instance_valid(joueur_cible) and not est_brise:
		var dir := Vector3(joueur_cible.global_position.x - global_position.x, 0.0, joueur_cible.global_position.z - global_position.z)
		if dir.length_squared() > 0.01:
			var dn := dir.normalized()
			zone_attaque.rotation.y = atan2(-dn.x, -dn.z)
			if is_instance_valid(sprite_3d) and absf(dn.x) > 0.12:
				sprite_3d.flip_h = dn.x < 0.0

	temps_depuis_dernier_coup += delta
	if nb_coups_combo > 0 and temps_depuis_dernier_coup >= delai_reset_combo:
		degats_combo_total = 0.0
		nb_coups_combo = 0
		_mettre_a_jour_label()

	if is_instance_valid(animator_25d):
		animator_25d.mettre_a_jour(delta, Vector3.ZERO, true, false, false, false, false, est_brise)

func boucle_attaque() -> void:
	while is_inside_tree():
		await get_tree().create_timer(intervalle_attaque).timeout
		if not is_inside_tree() or est_brise:
			continue

		_statut_action = "PRÉPARE UN COUP..."
		_mettre_a_jour_label()
		if is_instance_valid(sprite_3d):
			sprite_3d.modulate = COULEUR_TELEGRAPHE_SPRITE
		await get_tree().create_timer(0.45).timeout

		if not is_inside_tree() or est_brise:
			continue

		cibles_touchees_coup_actuel.clear()
		_statut_action = "ATTAQUE !"
		_mettre_a_jour_label()
		zone_attaque.monitoring = true
		visuel_coup.visible = true
		if is_instance_valid(animator_25d):
			animator_25d.jouer_coup(false, false)

		await get_tree().create_timer(0.2).timeout

		if not is_inside_tree():
			return
		zone_attaque.monitoring = false
		visuel_coup.visible = false
		if not est_brise:
			_statut_action = ""
			_mettre_a_jour_label()
			if is_instance_valid(sprite_3d):
				sprite_3d.modulate = COULEUR_BASE_SPRITE

func _on_zone_attaque_body_entered(body: Node3D) -> void:
	if est_brise or body == self or body in cibles_touchees_coup_actuel:
		return
	var degats_adaptes := 25.0
	var poise_adaptee := degats_poise_coup
	var royaume_adapte := 1
	if body.has_node("StatsComponent"):
		var stats := body.get_node("StatsComponent") as StatsComponent
		if stats:
			degats_adaptes = stats.get_pv_max() * ratio_degats_pv_joueur
			poise_adaptee = stats.get_poise_max() * 0.55
			royaume_adapte = stats.royaume_actuel

	var info := DamageInfo.creer(degats_adaptes, poise_adaptee, self, global_position, false, royaume_adapte, SkillData.Element.NEUTRE, false, false, royaume_adapte)
	if body.has_method("recevoir_degats_info"):
		cibles_touchees_coup_actuel.append(body)
		body.recevoir_degats_info(info)
	elif body.has_method("recevoir_degats"):
		cibles_touchees_coup_actuel.append(body)
		body.recevoir_degats(degats_adaptes, poise_adaptee, self)

func subir_degats_poise_parry(degats_poise: float, _royaume_def: int = 1) -> void:
	if est_brise:
		return
	poise_actuelle = maxf(0.0, poise_actuelle - degats_poise)
	_statut_action = "PARÉ !"
	_mettre_a_jour_label()
	if poise_actuelle <= 0.0:
		declencher_brisure()

func recevoir_degats_info(info: DamageInfo) -> void:
	temps_depuis_dernier_coup = 0.0
	var mult_posture := 1.5 if est_brise else 1.0
	var degats_effectifs := info.degats_pv * mult_posture

	dernier_degat = degats_effectifs
	degats_combo_total += degats_effectifs
	nb_coups_combo += 1

	EventBus.entity_damaged.emit(self, info)
	NumberFormatter.spawn_floating_damage(self, global_position, degats_effectifs, info.est_critique, info.est_counter, est_brise)
	if is_instance_valid(animator_25d):
		animator_25d.jouer_impact(Color(1.6, 1.6, 1.6, 1.0))

	subir_degats_poise_parry(info.degats_poise)
	_mettre_a_jour_label()

func recevoir_degats_avances(degats_pv: float, degats_poise: float, pos: Vector3, est_counter: bool) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, pos, est_counter))

func recevoir_degats(degats_pv: float, degats_poise: float, pos: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, pos, false))

func declencher_brisure() -> void:
	_id_brisure += 1
	var id_local := _id_brisure

	est_brise = true
	zone_attaque.monitoring = false
	visuel_coup.visible = false
	_statut_action = "[GARDE BRISÉE !]"
	_mettre_a_jour_label()
	EventBus.entity_guard_broken.emit(self)
	if is_instance_valid(sprite_3d):
		sprite_3d.modulate = COULEUR_BRISEE_SPRITE

	await get_tree().create_timer(duree_brisure_garde).timeout
	if not is_inside_tree() or _id_brisure != id_local:
		return

	est_brise = false
	poise_actuelle = poise_max
	_statut_action = ""
	_mettre_a_jour_label()
	if is_instance_valid(sprite_3d):
		sprite_3d.modulate = COULEUR_BASE_SPRITE

func _mettre_a_jour_label() -> void:
	var ligne_degats := "Coup : %s | Cumul : %s" % [
		NumberFormatter.format(dernier_degat),
		NumberFormatter.format(degats_combo_total)
	]
	if est_brise:
		label_etat.text = "%s\n[GARDE BRISÉE !]" % ligne_degats
	elif _statut_action != "":
		label_etat.text = "%s\n%s (Poise : %s)" % [ligne_degats, _statut_action, NumberFormatter.format(poise_actuelle)]
	else:
		label_etat.text = "%s\nPoise : %s" % [ligne_degats, NumberFormatter.format(poise_actuelle)]
