extends CharacterBody3D

# --- PARAMÈTRES DE DÉPLACEMENT & INERTIE ---
@export_group("Mouvement & Inertie")
@export var vitesse : float = 6.0
@export var acceleration : float = 38.0
@export var friction : float = 32.0
@export var vitesse_rotation_pivot : float = 12.0
@export var force_saut : float = 5.5

# --- PARAMÈTRES DU DASH & VOL SUR ÉPÉE ---
@export_group("Dash & Mobilité")
@export var vitesse_dash : float = 22.0
@export var duree_dash : float = 0.22
@export var fenetre_double_tap : float = 0.25
@export var vitesse_verticale_vol : float = 7.5
@export var altitude_max_vol : float = 14.0

# --- PARAMÈTRES D'ATTAQUE, COUNTER & AIM ASSIST ---
@export_group("Attaque, Parade & Counter")
@export var cout_endurance_attaque : float = 8.0
@export var duree_attaque : float = 0.26
@export var fenetre_combo : float = 0.8

@export var fenetre_parry_permissive : float = 0.32
@export var fenetre_counter_swbf2 : float = 0.45
@export var duree_counter_rapide : float = 0.11
@export var degats_poise_parry : float = 45.0
@export var multiplicateur_critique_brise : float = 1.5

@export var impulsion_attaque : float = 5.5
@export var impulsion_finisher : float = 8.5
@export var impulsion_counter : float = 2.5

@export_group("Aim Assist (Soft-Lock)")
@export var portee_aim_assist : float = 4.5
@export var angle_max_aim_assist_deg : float = 50.0

# --- CULTIVATION & POISE ---
@export_group("Cultivation & Combat")
@export_range(1, 10) var royaume_actuel : int = 1
@export var delai_regen_poise : float = 2.5
@export var vitesse_regen_poise : float = 25.0
@export var duree_brisure_garde : float = 1.2

# --- RÉFÉRENCES AUX NŒUDS ---
@onready var stats: StatsComponent = $StatsComponent
@onready var cultivation: CultivationComponent = $CultivationComponent
@onready var skills: SkillsComponent = $SkillsComponent
@onready var animator_25d: SpriteAnimator25D = $SpriteAnimator25D
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var aura_meditation: MeshInstance3D = $AuraMeditation
@onready var barriere_qi: MeshInstance3D = $BarriereQi
@onready var epee_volante: MeshInstance3D = $EpeeVolante
@onready var camera: Camera3D = $Camera3D
@onready var pivot_attaque: Node3D = $PivotAttaque
@onready var hitbox_attaque: Area3D = $PivotAttaque/HitboxAttaque
@onready var visuel_slash: MeshInstance3D = $PivotAttaque/HitboxAttaque/VisuelSlash
@onready var visuel_garde: MeshInstance3D = $PivotAttaque/VisuelGarde

# --- ÉTATS INTERNES ---
var gravite : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pv_actuels : float = 150.0
var endurance_actuelle : float = 100.0
var qi_actuel : float = 100.0

var est_en_dash : bool = false
var peut_dash : bool = true
var direction_dash : Vector3 = Vector3.ZERO
var est_en_vol_epee : bool = false

var est_en_attaque : bool = false
var est_en_counter : bool = false
var index_combo : int = 0
var temps_derniere_attaque : float = -10.0
var cibles_touchees_coup_actuel : Array = []
var direction_attaque_verrouillee : Vector3 = Vector3.ZERO

# États de Garde / Parry / Counter SWBF2
var est_en_garde : bool = false
var temps_debut_garde : float = -10.0
var temps_dernier_coup_bloque : float = -10.0

# États défensifs & Poise
var est_invulnerable : bool = false
var reduction_degats : float = 0.0
var reduction_degats_poise : float = 0.0
var poise_actuelle : float = 50.0
var temps_depuis_dernier_coup_subi : float = 0.0
var est_brise : bool = false

var _id_action_attaque : int = 0
var _id_flash_garde : int = 0
var _id_dash : int = 0
var _id_brisure : int = 0
var _id_shake : int = 0

var dernier_temps_appui : Dictionary = {
	"avancer": -1.0, "reculer": -1.0, "gauche": -1.0, "droite": -1.0
}

const COULEUR_SLASH_NORMAL := Color(0.0, 0.85, 1.0)
const COULEUR_SLASH_COUNTER := Color(1.0, 0.9, 0.2)
const COULEUR_GARDE_PARRY := Color(1.0, 1.0, 1.0, 0.8)
const COULEUR_GARDE_NORMALE := Color(0.95, 0.77, 0.06, 0.45)

func _ready() -> void:
	royaume_actuel = clampi(royaume_actuel, 1, 10)
	stats.set_royaume(royaume_actuel, false)
	var niv_init := stats.get_realm_data(royaume_actuel).niveau_requis
	if stats.niveau_actuel < niv_init:
		stats.definir_niveau_minimum(niv_init)
	cultivation.initialiser(stats)
	skills.initialiser(self, stats)
	animator_25d.initialiser(sprite_3d)

	pv_actuels = stats.get_pv_max()
	endurance_actuelle = stats.get_endurance_max()
	qi_actuel = stats.get_qi_max()
	poise_actuelle = stats.get_poise_max()

	hitbox_attaque.monitoring = false
	visuel_slash.visible = false
	visuel_garde.visible = false
	aura_meditation.visible = false
	barriere_qi.visible = false
	epee_volante.visible = false
	hitbox_attaque.body_entered.connect(_on_hitbox_attaque_body_entered)

	EventBus.breakthrough_completed.connect(_on_breakthrough_completed)
	EventBus.breakthrough_failed.connect(_on_breakthrough_failed)

	emettre_tous_les_signaux.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mediter"):
		if cultivation.est_en_meditation:
			cultivation.arreter_meditation()
		elif is_on_floor() and not est_en_vol_epee and not est_en_dash and not est_en_attaque and not est_en_garde and not est_brise:
			cultivation.demarrer_meditation()
		return

	if event.is_action_pressed("percee"):
		if not est_brise and not est_en_dash:
			cultivation.tenter_percee()
		return

	if event.is_action_pressed("vol_epee"):
		basculer_vol_epee()
		return

	# Sorts de Qi (1 à 4)
	if not est_brise and not est_en_dash:
		for slot in range(1, 5):
			if event.is_action_pressed("sort_%d" % slot):
				cultivation.arreter_meditation()
				skills.tenter_lancer_sort(slot)
				return

	# Raccourcis bac à sable
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP or event.keycode == KEY_KP_ADD:
			changer_royaume(royaume_actuel + 1, false, true)
		elif event.keycode == KEY_PAGEDOWN or event.keycode == KEY_KP_SUBTRACT:
			changer_royaume(royaume_actuel - 1, false, false)
		elif event.keycode == KEY_L:
			stats.ajouter_niveaux_debug(10)
			emettre_tous_les_signaux()
		elif event.keycode == KEY_T:
			cultivation.preparer_percee_debug()
			emettre_tous_les_signaux()
		elif event.keycode == KEY_F9:
			_basculer_scene_bac_a_sable()

func _basculer_scene_bac_a_sable() -> void:
	var actuelle := get_tree().current_scene
	var vers_vallee := actuelle != null and actuelle.scene_file_path.ends_with("monde.tscn")
	var cible := "res://scenes/vallee_brume_emeraude.tscn" if vers_vallee else "res://scenes/monde.tscn"
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(cible)

func basculer_vol_epee() -> void:
	if est_en_vol_epee:
		_desactiver_vol_epee()
		return
	if not stats.peut_voler_sur_epee():
		EventBus.skill_feedback.emit("Vol sur Épée débloqué au Royaume 4 : Noyau d'Or !", Color(1.0, 0.72, 0.3))
		return
	if est_brise or est_en_dash:
		return

	cultivation.arreter_meditation()
	est_en_vol_epee = true
	epee_volante.visible = true
	if is_on_floor():
		velocity.y = 4.5
	EventBus.sword_flight_toggled.emit(true)
	print("[MOBILITÉ] Vol sur Épée activé ! [Espace] Monter | [Shift/Ctrl] Descendre | [V] Quitter")

func _desactiver_vol_epee() -> void:
	if not est_en_vol_epee:
		return
	est_en_vol_epee = false
	epee_volante.visible = false
	EventBus.sword_flight_toggled.emit(false)

func consommer_qi(montant: float) -> void:
	qi_actuel = maxf(0.0, qi_actuel - montant)
	EventBus.player_qi_changed.emit(qi_actuel, stats.get_qi_max())

func emettre_tous_les_signaux() -> void:
	EventBus.player_pv_changed.emit(pv_actuels, stats.get_pv_max())
	EventBus.player_poise_changed.emit(poise_actuelle, stats.get_poise_max(), est_brise)
	EventBus.player_endurance_changed.emit(endurance_actuelle, stats.get_endurance_max())
	EventBus.player_qi_changed.emit(qi_actuel, stats.get_qi_max())
	EventBus.player_realm_changed.emit(royaume_actuel, stats.get_nom_royaume_affiche())
	EventBus.player_level_changed.emit(stats.niveau_actuel, stats.xp_actuelle, stats.get_xp_requise_niveau(), stats.points_stats_libres)
	EventBus.player_power_changed.emit(stats.get_puissance_globale())
	cultivation.emettre_etat()

func changer_royaume(nouveau_royaume: int, restaurer_jauges: bool = false, ajuster_niveau_debug: bool = false) -> void:
	var cible := clampi(nouveau_royaume, 1, 10)
	if cible == royaume_actuel:
		return

	var ratio_pv := pv_actuels / maxf(1.0, stats.get_pv_max())
	var ratio_qi := qi_actuel / maxf(1.0, stats.get_qi_max())
	var ratio_end := endurance_actuelle / maxf(1.0, stats.get_endurance_max())
	var ratio_poise := poise_actuelle / maxf(1.0, stats.get_poise_max())

	royaume_actuel = cible
	stats.set_royaume(royaume_actuel, true)
	if ajuster_niveau_debug:
		stats.definir_niveau_minimum(stats.get_realm_data(royaume_actuel).niveau_requis)
	if est_en_vol_epee and not stats.peut_voler_sur_epee():
		_desactiver_vol_epee()

	if restaurer_jauges:
		pv_actuels = stats.get_pv_max()
		qi_actuel = stats.get_qi_max()
		endurance_actuelle = stats.get_endurance_max()
		poise_actuelle = stats.get_poise_max()
		est_brise = false
	else:
		pv_actuels = stats.get_pv_max() * ratio_pv
		qi_actuel = stats.get_qi_max() * ratio_qi
		endurance_actuelle = stats.get_endurance_max() * ratio_end
		poise_actuelle = 0.0 if est_brise else stats.get_poise_max() * ratio_poise

	cultivation.sur_changement_royaume_manuel()
	emettre_tous_les_signaux()
	print("[ROYAUME] %s (%s) | Niv. %d | Puissance: %s | Dégâts base: %s | PV: %s" % [
		stats.get_nom_royaume_affiche(),
		stats.get_titre_cosmologique(),
		stats.niveau_actuel,
		NumberFormatter.format(stats.get_puissance_globale()),
		NumberFormatter.format(stats.get_degats_attaque(1.0)),
		NumberFormatter.format(stats.get_pv_max())
	])

func _on_breakthrough_completed(nouveau_royaume: int, _chance_finale: float) -> void:
	changer_royaume(nouveau_royaume, true, false)
	cultivation.finaliser_percee_reussie()

func _on_breakthrough_failed(_royaume_cible: int, _raison: String) -> void:
	if cultivation.est_en_tribulation:
		cultivation.finaliser_percee_echouee(true)

func secouer_camera(intensite: float = 0.2, duree: float = 0.2) -> void:
	if not is_instance_valid(camera):
		return
	_id_shake += 1
	var id_local := _id_shake
	var temps := 0.0
	while temps < duree and is_inside_tree() and _id_shake == id_local:
		var facteur := 1.0 - (temps / maxf(0.01, duree))
		camera.h_offset = randf_range(-intensite, intensite) * facteur
		camera.v_offset = randf_range(-intensite, intensite) * facteur
		await get_tree().process_frame
		temps += get_process_delta_time()
	if is_instance_valid(camera) and _id_shake == id_local:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _physics_process(delta: float) -> void:
	var temps_actuel : float = Time.get_ticks_msec() / 1000.0

	# 1. Régénérations passives & consommation du Vol sur Épée
	var endurance_max := stats.get_endurance_max()
	if not est_en_dash and not est_en_garde and endurance_actuelle < endurance_max:
		endurance_actuelle = minf(endurance_max, endurance_actuelle + stats.get_regen_endurance() * delta)
		EventBus.player_endurance_changed.emit(endurance_actuelle, endurance_max)

	var qi_max := stats.get_qi_max()
	if est_en_vol_epee and royaume_actuel < 7:
		var drain := qi_max * 0.025 * delta
		consommer_qi(drain)
		if qi_actuel <= 0.0:
			_desactiver_vol_epee()
			EventBus.skill_feedback.emit("Qi épuisé : fin du Vol sur Épée", Color(0.45, 0.75, 1.0))
	elif qi_actuel < qi_max:
		var mult_qi := cultivation.multiplicateur_regen_qi_meditation if cultivation.est_en_meditation else 1.0
		qi_actuel = minf(qi_max, qi_actuel + stats.get_regen_qi() * mult_qi * delta)
		EventBus.player_qi_changed.emit(qi_actuel, qi_max)

	temps_depuis_dernier_coup_subi += delta
	var poise_max := stats.get_poise_max()
	if not est_brise and temps_depuis_dernier_coup_subi >= delai_regen_poise and poise_actuelle < poise_max:
		poise_actuelle = minf(poise_max, poise_actuelle + stats.get_regen_poise(vitesse_regen_poise) * delta)
		EventBus.player_poise_changed.emit(poise_actuelle, poise_max, est_brise)

	# 2. Gravité (suspendue pendant le Dash et le Vol sur Épée)
	if est_en_vol_epee:
		epee_volante.rotation.y = pivot_attaque.rotation.y
		epee_volante.position.y = -0.05 + sin(temps_actuel * 6.0) * 0.06
	elif not is_on_floor():
		if est_en_dash:
			velocity.y = 0.0
		else:
			velocity.y -= gravite * delta

	if est_brise:
		aura_meditation.visible = false
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		animator_25d.mettre_a_jour(delta, velocity, is_on_floor(), false, false, false, false, true)
		return

	# 2.5 Mode Méditation Active
	if cultivation.est_en_meditation:
		var input_mouvement := Input.get_vector("gauche", "droite", "avancer", "reculer")
		if input_mouvement.length_squared() > 0.01 or Input.is_action_just_pressed("sauter") or Input.is_action_just_pressed("attaquer") or Input.is_action_pressed("bloquer"):
			cultivation.arreter_meditation()
			aura_meditation.visible = false
		else:
			cultivation.tick_meditation(delta)
			aura_meditation.visible = true
			aura_meditation.rotation.y += delta * 2.2
			var pulse := 1.0 + sin(temps_actuel * 5.0) * 0.08
			aura_meditation.scale = Vector3(pulse, 1.0, pulse)
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
			move_and_slide()
			animator_25d.mettre_a_jour(delta, velocity, is_on_floor(), false, false, true, false, false)
			return
	else:
		aura_meditation.visible = false

	# 3. Garde
	gerer_garde(temps_actuel)

	# 4. Double-Tap Dash
	if not est_en_dash and peut_dash:
		verifier_double_tap()

	# 5. Attaque ou Counter SWBF2
	if Input.is_action_just_pressed("attaquer") and not est_en_dash:
		if est_en_garde and not est_en_counter and (temps_actuel - temps_dernier_coup_bloque <= fenetre_counter_swbf2):
			declencher_counter_swbf2()
		elif not est_en_attaque:
			desactiver_garde()
			tenter_attaque()

	# 6. Mouvement
	if est_en_dash:
		velocity.x = direction_dash.x * vitesse_dash
		velocity.z = direction_dash.z * vitesse_dash
		if est_en_vol_epee:
			velocity.y = 0.0
	elif est_en_attaque:
		velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)
		if est_en_vol_epee:
			velocity.y = move_toward(velocity.y, 0.0, 20.0 * delta)
	elif est_en_vol_epee:
		gerer_deplacement_vol(delta)
	else:
		gerer_deplacement_normal(delta)

	move_and_slide()
	animator_25d.mettre_a_jour(delta, velocity, is_on_floor(), est_en_dash, est_en_garde, false, est_en_vol_epee, est_brise)

func gerer_deplacement_vol(delta: float) -> void:
	var input_dir := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var mult_vol := lerpf(2.2, 3.6, clampf((royaume_actuel - 4) / 6.0, 0.0, 1.0))
	var vitesse_vol : float = vitesse * mult_vol * (0.6 if est_en_garde else 1.0)

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * vitesse_vol, acceleration * 1.4 * delta)
		velocity.z = move_toward(velocity.z, direction.z * vitesse_vol, acceleration * 1.4 * delta)
		var angle_cible : float = atan2(-direction.x, -direction.z)
		pivot_attaque.rotation.y = lerp_angle(pivot_attaque.rotation.y, angle_cible, vitesse_rotation_pivot * delta)
		var sprite := get_node_or_null("Sprite3D")
		if sprite and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * 0.8 * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * 0.8 * delta)

	var dir_y := 0.0
	if Input.is_action_pressed("sauter") and global_position.y < altitude_max_vol:
		dir_y = 1.0
	elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		dir_y = -1.0

	if dir_y != 0.0:
		velocity.y = move_toward(velocity.y, dir_y * vitesse_verticale_vol, 32.0 * delta)
	else:
		velocity.y = move_toward(velocity.y, 0.0, 24.0 * delta)

func gerer_garde(temps_actuel: float) -> void:
	var veut_bloquer : bool = Input.is_action_pressed("bloquer") and not est_en_dash and (not est_en_attaque or est_en_counter)

	if veut_bloquer and not est_en_garde:
		est_en_garde = true
		temps_debut_garde = temps_actuel
		visuel_garde.visible = true
		flash_fenetre_parry()
	elif not veut_bloquer and est_en_garde:
		desactiver_garde()

func desactiver_garde() -> void:
	_id_flash_garde += 1
	est_en_garde = false
	visuel_garde.visible = false

func flash_fenetre_parry() -> void:
	_id_flash_garde += 1
	var id_local := _id_flash_garde
	var mat := visuel_garde.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = COULEUR_GARDE_PARRY
		await get_tree().create_timer(fenetre_parry_permissive).timeout
		if _id_flash_garde == id_local and est_en_garde and mat:
			mat.albedo_color = COULEUR_GARDE_NORMALE

func gerer_deplacement_normal(delta: float) -> void:
	if Input.is_action_just_pressed("sauter") and is_on_floor():
		velocity.y = force_saut

	var input_dir := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var vitesse_cible_max : float = vitesse * 0.55 if est_en_garde else vitesse

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * vitesse_cible_max, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * vitesse_cible_max, acceleration * delta)

		var angle_cible : float = atan2(-direction.x, -direction.z)
		pivot_attaque.rotation.y = lerp_angle(pivot_attaque.rotation.y, angle_cible, vitesse_rotation_pivot * delta)

		var sprite := get_node_or_null("Sprite3D")
		if sprite and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func _direction_horizontale(vecteur: Vector3) -> Vector3:
	var v := Vector3(vecteur.x, 0.0, vecteur.z)
	if v.length_squared() < 0.0001:
		return Vector3.ZERO
	return v.normalized()

func orienter_legerement_vers_ennemi_proche() -> void:
	var ennemis : Array = get_tree().get_nodes_in_group("ennemis")
	if ennemis.is_empty():
		return

	var ennemi_plus_proche : Node3D = null
	var distance_min : float = portee_aim_assist
	var direction_actuelle : Vector3 = _direction_horizontale(-pivot_attaque.global_transform.basis.z)
	if direction_actuelle == Vector3.ZERO:
		direction_actuelle = Vector3.FORWARD

	for ennemi in ennemis:
		if not is_instance_valid(ennemi) or not (ennemi is Node3D):
			continue
		var vers_ennemi : Vector3 = ennemi.global_position - global_position
		vers_ennemi.y = 0.0
		var dist : float = vers_ennemi.length()

		if dist <= distance_min and dist > 0.1:
			var angle_ecart : float = rad_to_deg(direction_actuelle.angle_to(vers_ennemi.normalized()))
			if angle_ecart <= angle_max_aim_assist_deg:
				distance_min = dist
				ennemi_plus_proche = ennemi

	if ennemi_plus_proche:
		var dir_cible : Vector3 = _direction_horizontale(ennemi_plus_proche.global_position - global_position)
		if dir_cible == Vector3.ZERO:
			return
		var angle_cible : float = atan2(-dir_cible.x, -dir_cible.z)
		pivot_attaque.rotation.y = lerp_angle(pivot_attaque.rotation.y, angle_cible, 0.65)

		var sprite := get_node_or_null("Sprite3D")
		if sprite and absf(dir_cible.x) > 0.15:
			sprite.flip_h = dir_cible.x < 0

func verifier_double_tap() -> void:
	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	var correspondance_vecteurs : Dictionary = {
		"avancer": Vector3(0, 0, -1), "reculer": Vector3(0, 0, 1),
		"gauche": Vector3(-1, 0, 0), "droite": Vector3(1, 0, 0)
	}

	for action in correspondance_vecteurs.keys():
		if Input.is_action_just_pressed(action):
			var ecart : float = temps_actuel - dernier_temps_appui[action]
			if ecart <= fenetre_double_tap:
				var dir_locale : Vector3 = correspondance_vecteurs[action]
				var dir_monde : Vector3 = (transform.basis * dir_locale).normalized()
				tenter_dash(dir_monde)
				dernier_temps_appui[action] = -1.0
			else:
				dernier_temps_appui[action] = temps_actuel

func _annuler_attaque_en_cours() -> void:
	_id_action_attaque += 1
	est_en_attaque = false
	est_en_counter = false
	hitbox_attaque.monitoring = false
	visuel_slash.visible = false
	var mat_slash := visuel_slash.material_override as StandardMaterial3D
	if mat_slash:
		mat_slash.albedo_color = COULEUR_SLASH_NORMAL

func tenter_dash(dir: Vector3) -> void:
	var cout : float = stats.get_cout_dash()
	if endurance_actuelle < cout:
		return

	cultivation.arreter_meditation()
	if est_en_attaque:
		_annuler_attaque_en_cours()

	desactiver_garde()

	endurance_actuelle -= cout
	EventBus.player_endurance_changed.emit(endurance_actuelle, stats.get_endurance_max())

	_id_dash += 1
	var id_local := _id_dash

	est_en_dash = true
	peut_dash = false
	direction_dash = dir

	pivot_attaque.rotation.y = atan2(-dir.x, -dir.z)

	est_invulnerable = true
	reduction_degats = 0.75
	reduction_degats_poise = 0.60

	var sprite := get_node_or_null("Sprite3D")
	if sprite:
		sprite.modulate = Color(0.5, 0.9, 1.0, 0.5)

	await get_tree().create_timer(duree_dash * 0.65).timeout
	if _id_dash != id_local:
		return
	est_invulnerable = false

	await get_tree().create_timer(duree_dash * 0.35).timeout
	if _id_dash != id_local:
		return
	est_en_dash = false
	reduction_degats = 0.0
	reduction_degats_poise = 0.0

	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	await get_tree().create_timer(stats.get_cooldown_dash()).timeout
	if _id_dash == id_local:
		peut_dash = true

func tenter_attaque() -> void:
	if endurance_actuelle < cout_endurance_attaque:
		return

	endurance_actuelle -= cout_endurance_attaque
	EventBus.player_endurance_changed.emit(endurance_actuelle, stats.get_endurance_max())

	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	index_combo = (index_combo % 3) + 1 if (temps_actuel - temps_derniere_attaque <= fenetre_combo) else 1

	temps_derniere_attaque = temps_actuel
	_id_action_attaque += 1
	var id_local := _id_action_attaque

	est_en_attaque = true
	est_en_counter = false
	cibles_touchees_coup_actuel.clear()

	orienter_legerement_vers_ennemi_proche()

	direction_attaque_verrouillee = _direction_horizontale(-pivot_attaque.global_transform.basis.z)
	var elan : float = impulsion_finisher if index_combo == 3 else impulsion_attaque
	velocity.x = direction_attaque_verrouillee.x * elan
	velocity.z = direction_attaque_verrouillee.z * elan

	var mat_slash := visuel_slash.material_override as StandardMaterial3D
	if mat_slash:
		mat_slash.albedo_color = COULEUR_SLASH_NORMAL

	# La taille et la vitesse de l'attaque scalent avec le Royaume et le Niveau !
	var taille_base : float = stats.get_facteur_taille()
	var mult_finisher : float = 1.35 if index_combo == 3 else 1.0
	var s_xz : float = taille_base * mult_finisher
	var s_y : float = maxf(1.0, taille_base * 0.65)
	hitbox_attaque.scale = Vector3(s_xz, s_y, s_xz)
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true
	animator_25d.jouer_coup(index_combo == 3, false)

	await get_tree().create_timer(stats.get_duree_attaque(duree_attaque)).timeout

	if _id_action_attaque == id_local:
		hitbox_attaque.monitoring = false
		visuel_slash.visible = false
		est_en_attaque = false

func declencher_counter_swbf2() -> void:
	temps_dernier_coup_bloque = -10.0

	_id_action_attaque += 1
	var id_local := _id_action_attaque

	est_en_attaque = true
	est_en_counter = true
	cibles_touchees_coup_actuel.clear()

	orienter_legerement_vers_ennemi_proche()

	direction_attaque_verrouillee = _direction_horizontale(-pivot_attaque.global_transform.basis.z)
	velocity.x = direction_attaque_verrouillee.x * impulsion_counter
	velocity.z = direction_attaque_verrouillee.z * impulsion_counter

	var mat_slash := visuel_slash.material_override as StandardMaterial3D
	if mat_slash:
		mat_slash.albedo_color = COULEUR_SLASH_COUNTER

	var taille_c : float = stats.get_facteur_taille()
	hitbox_attaque.scale = Vector3(taille_c, maxf(1.0, taille_c * 0.65), taille_c)
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true
	animator_25d.jouer_coup(false, true)
	print(">>> COUNTER SWBF2 EXÉCUTÉ !")

	await get_tree().create_timer(stats.get_duree_attaque(duree_counter_rapide)).timeout

	if _id_action_attaque == id_local:
		hitbox_attaque.monitoring = false
		visuel_slash.visible = false
		est_en_attaque = false
		est_en_counter = false
		if mat_slash:
			mat_slash.albedo_color = COULEUR_SLASH_NORMAL

func recevoir_degats(degats_pv: float, degats_poise: float, attaquant: Node3D) -> void:
	var pos := attaquant.global_position if is_instance_valid(attaquant) else global_position
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, attaquant, pos))

func recevoir_degats_info(info: DamageInfo) -> void:
	if est_invulnerable:
		print("ESQUIVE PARFAITE (iFrames du Dash) !")
		EventBus.dash_evade_succeeded.emit(self, info.attaquant)
		return

	if cultivation.est_en_meditation:
		cultivation.arreter_meditation()

	# Barrière de Qi active : absorbe 100% d'un impact (y compris Éclairs de Tribulation) contre du Qi !
	if skills.barriere_active and not info.est_imblocable:
		var cout_absorption := stats.get_qi_max() * 0.14
		if qi_actuel >= cout_absorption:
			consommer_qi(cout_absorption)
			secouer_camera(0.12, 0.12)
			print("BARRIÈRE DE QI : Impact absorbé (-%s Qi) !" % NumberFormatter.format(cout_absorption))
			return
		else:
			consommer_qi(qi_actuel)
			skills.desactiver_barriere()
			print("BARRIÈRE DE QI BRISÉE (Qi insuffisant) !")

	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	var dir_recul : Vector3 = _direction_horizontale(global_position - info.position_origine)
	var facteur_supp_poise : float = DamageInfo.calculer_facteur_suppression_poise(info.royaume_attaquant, royaume_actuel)

	if est_en_garde and not info.est_imblocable:
		temps_dernier_coup_bloque = temps_actuel
		if temps_actuel - temps_debut_garde <= fenetre_parry_permissive:
			if info.element == SkillData.Element.ECLAIR:
				var gain_qi := stats.get_qi_max() * 0.15
				qi_actuel = minf(stats.get_qi_max(), qi_actuel + gain_qi)
				EventBus.player_qi_changed.emit(qi_actuel, stats.get_qi_max())
				secouer_camera(0.15, 0.15)
				print("PARRY CÉLESTE ! Éclair dévié (+%s Qi) !" % NumberFormatter.format(gain_qi))
			else:
				print("PARRY PARFAIT (Sekiro) !")
			EventBus.parry_succeeded.emit(self, info.attaquant)
			animator_25d.jouer_parry()
			if is_instance_valid(info.attaquant) and info.attaquant.has_method("subir_degats_poise_parry"):
				info.attaquant.subir_degats_poise_parry(stats.get_degats_poise(2.0), royaume_actuel)
			return
		else:
			var ratio_poise_coup : float = (info.degats_poise * facteur_supp_poise) / maxf(1.0, stats.get_poise_max())
			var cout_block : float = clampf(ratio_poise_coup * 55.0, 0.0, stats.get_endurance_max() * 1.2)
			if endurance_actuelle < cout_block:
				endurance_actuelle = 0.0
				EventBus.player_endurance_changed.emit(endurance_actuelle, stats.get_endurance_max())
				velocity += dir_recul * 7.0
				print("GARDE ENFONCÉE (Endurance épuisée) !")
				declencher_brisure_garde_joueur()
				return
			endurance_actuelle -= cout_block
			EventBus.player_endurance_changed.emit(endurance_actuelle, stats.get_endurance_max())
			velocity += dir_recul * (0.5 if facteur_supp_poise == 0.0 else 4.0)
			print("COUP BLOQUÉ ! Endurance: %.0f" % endurance_actuelle)
			return

	temps_depuis_dernier_coup_subi = 0.0
	var multiplicateur_critique : float = multiplicateur_critique_brise if est_brise else 1.0
	var degats_subis : float = info.degats_pv * (1.0 - reduction_degats) * multiplicateur_critique
	var degats_poise_subis : float = info.degats_poise * (1.0 - reduction_degats_poise) * facteur_supp_poise

	var pv_max := stats.get_pv_max()
	pv_actuels = maxf(0.0, pv_actuels - degats_subis)
	EventBus.player_pv_changed.emit(pv_actuels, pv_max)
	EventBus.entity_damaged.emit(self, info)
	animator_25d.jouer_impact(Color(1.8, 0.7, 0.7, 1.0))

	var poise_max := stats.get_poise_max()
	if not est_brise and degats_poise_subis > 0.0:
		poise_actuelle = maxf(0.0, poise_actuelle - degats_poise_subis)
		EventBus.player_poise_changed.emit(poise_actuelle, poise_max, est_brise)

	# Aucun recul si un mortel (2+ Royaumes en dessous) tente d'ébranler votre posture
	if facteur_supp_poise > 0.0:
		velocity += dir_recul * (7.0 if est_brise else 5.0)
	print("TOUCHÉ (-%s) ! PV: %s / %s | Poise: %s / %s" % [
		NumberFormatter.format(degats_subis),
		NumberFormatter.format(pv_actuels),
		NumberFormatter.format(pv_max),
		NumberFormatter.format(poise_actuelle),
		NumberFormatter.format(poise_max)
	])

	if pv_actuels <= 0.0:
		EventBus.entity_died.emit(self, info.attaquant)
		reinitialiser_joueur_bac_a_sable()
		return

	if poise_actuelle <= 0.0 and not est_brise:
		declencher_brisure_garde_joueur()

func declencher_brisure_garde_joueur() -> void:
	_id_brisure += 1
	var id_local := _id_brisure

	est_brise = true
	poise_actuelle = 0.0
	cultivation.arreter_meditation()
	_desactiver_vol_epee()
	if est_en_attaque:
		_annuler_attaque_en_cours()
	desactiver_garde()

	EventBus.player_poise_changed.emit(poise_actuelle, stats.get_poise_max(), est_brise)
	EventBus.entity_guard_broken.emit(self)
	print("ALERTE : VOTRE GARDE (POISE) EST BRISÉE !")

	await get_tree().create_timer(duree_brisure_garde).timeout
	if _id_brisure != id_local:
		return

	est_brise = false
	var poise_max := stats.get_poise_max()
	poise_actuelle = poise_max
	EventBus.player_poise_changed.emit(poise_actuelle, poise_max, est_brise)

func reinitialiser_joueur_bac_a_sable() -> void:
	print("PV À 0 ! Réinitialisation du Joueur (mode bac à sable).")
	_id_brisure += 1
	_id_dash += 1
	cultivation.arreter_meditation()
	skills.desactiver_barriere()
	_desactiver_vol_epee()
	_annuler_attaque_en_cours()
	desactiver_garde()

	est_brise = false
	est_en_dash = false
	peut_dash = true
	est_invulnerable = false
	reduction_degats = 0.0
	reduction_degats_poise = 0.0
	velocity = Vector3.ZERO

	var sprite := get_node_or_null("Sprite3D")
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	pv_actuels = stats.get_pv_max()
	endurance_actuelle = stats.get_endurance_max()
	qi_actuel = stats.get_qi_max()
	poise_actuelle = stats.get_poise_max()
	emettre_tous_les_signaux()

func _on_hitbox_attaque_body_entered(body: Node3D) -> void:
	if body == self or body in cibles_touchees_coup_actuel:
		return

	cibles_touchees_coup_actuel.append(body)

	var multiplicateur : float = 1.65 if (index_combo == 3 and not est_en_counter) else 1.0
	var est_crit : bool = randf() <= stats.get_chance_critique()
	var mult_crit : float = stats.get_multiplicateur_critique() if est_crit else 1.0
	var variance_dokkan : float = randf_range(0.92, 1.08)

	var degats_finaux := stats.get_degats_attaque(multiplicateur) * mult_crit * variance_dokkan
	var info := DamageInfo.creer(
		degats_finaux,
		stats.get_degats_poise(multiplicateur),
		self,
		global_position,
		est_en_counter,
		stats.get_puissance_destruction(),
		SkillData.Element.NEUTRE,
		false,
		est_crit,
		royaume_actuel
	)

	if est_en_counter:
		EventBus.counter_executed.emit(self, body)

	stats.gagner_xp(18.0 * royaume_actuel)

	if body.has_method("recevoir_degats_info"):
		body.recevoir_degats_info(info)
	elif body.has_method("recevoir_degats_avances"):
		body.recevoir_degats_avances(info.degats_pv, info.degats_poise, info.position_origine, info.est_counter)
	elif body.has_method("recevoir_degats"):
		body.recevoir_degats(info.degats_pv, info.degats_poise, info.position_origine)
