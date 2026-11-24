extends CharacterBody3D

# --- SIGNAUX ---
signal endurance_modifiee(actuelle: float, maximum: float)
signal qi_modifie(actuel: float, maximum: float)
signal royaume_modifie(nouveau_royaume: int)

# --- PARAMÈTRES DE DÉPLACEMENT & INERTIE ---
@export_group("Mouvement & Inertie")
@export var vitesse : float = 6.0
@export var acceleration : float = 38.0           # Vitesse à laquelle le personnage atteint sa vitesse max
@export var friction : float = 32.0               # Vitesse de freinage (empêche les arrêts secs)
@export var vitesse_rotation_pivot : float = 12.0 # Vitesse de pivotement (plus bas = virages plus lourds)
@export var force_saut : float = 5.5

# --- PARAMÈTRES DU DASH ---
@export_group("Dash & Mobilité")
@export var vitesse_dash : float = 22.0
@export var duree_dash : float = 0.22
@export var cooldown_dash_base : float = 0.75
@export var cooldown_dash_min : float = 0.05
@export var fenetre_double_tap : float = 0.25
@export var cout_endurance_base : float = 15.0

# --- PARAMÈTRES D'ATTAQUE, COUNTER & AIM ASSIST ---
@export_group("Attaque, Parade & Counter")
@export var degats_base : float = 20.0
@export var degats_poise_base : float = 25.0
@export var cout_endurance_attaque : float = 8.0
@export var duree_attaque : float = 0.26
@export var fenetre_combo : float = 0.8

@export var fenetre_parry_permissive : float = 0.32
@export var fenetre_counter_swbf2 : float = 0.45
@export var duree_counter_rapide : float = 0.11
@export var degats_poise_parry : float = 45.0

@export var impulsion_attaque : float = 5.5
@export var impulsion_finisher : float = 8.5
@export var impulsion_counter : float = 2.5

@export_group("Aim Assist (Soft-Lock)")
@export var portee_aim_assist : float = 4.5       # Distance max pour attirer légèrement l'attaque
@export var angle_max_aim_assist_deg : float = 50.0 # Angle max de correction automatique (en degrés)

# --- STATISTIQUES DE CULTIVATION ---
@export_group("Cultivation & Combat")
@export var royaume_actuel : int = 1
@export var pv_max : float = 150.0
@export var endurance_max : float = 100.0
@export var regen_endurance : float = 7.5
@export var qi_max : float = 100.0
@export var regen_qi : float = 5.0
@export var poise_base : float = 50.0

# --- RÉFÉRENCES AUX NŒUDS ---
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

# États défensifs
var est_invulnerable : bool = false
var reduction_degats : float = 0.0
var poise_actuelle : float = 50.0
var est_brise : bool = false

var dernier_temps_appui : Dictionary = {
	"avancer": -1.0, "reculer": -1.0, "gauche": -1.0, "droite": -1.0
}

func _ready() -> void:
	pv_actuels = pv_max
	endurance_actuelle = endurance_max
	qi_actuel = qi_max
	poise_actuelle = poise_base
	
	hitbox_attaque.body_entered.connect(_on_hitbox_attaque_body_entered)
	
	endurance_modifiee.emit(endurance_actuelle, endurance_max)
	qi_modifie.emit(qi_actuel, qi_max)
	royaume_modifie.emit(royaume_actuel)

func _physics_process(delta: float) -> void:
	var temps_actuel : float = Time.get_ticks_msec() / 1000.0

	# 1. Régénérations passives
	if not est_en_dash and not est_en_garde and endurance_actuelle < endurance_max:
		endurance_actuelle = min(endurance_max, endurance_actuelle + regen_endurance * delta)
		endurance_modifiee.emit(endurance_actuelle, endurance_max)

	if qi_actuel < qi_max:
		qi_actuel = min(qi_max, qi_actuel + regen_qi * delta)
		qi_modifie.emit(qi_actuel, qi_max)

	# 2. Gravité
	if not is_on_floor():
		if est_en_dash:
			velocity.y = 0.0
		else:
			velocity.y -= gravite * delta

	if est_brise:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	# 3. Gestion de la Garde
	gerer_garde(temps_actuel)

	# 4. Double-Tap Dash (Dash Cancel autorisé à tout moment)
	if not est_en_dash and peut_dash:
		verifier_double_tap()

	# 5. Attaque ou Counter SWBF2
	if Input.is_action_just_pressed("attaquer") and not est_en_dash:
		if est_en_garde and (temps_actuel - temps_dernier_coup_bloque <= fenetre_counter_swbf2):
			declencher_counter_swbf2()
		elif not est_en_attaque:
			est_en_garde = false
			visuel_garde.visible = false
			tenter_attaque()

	# 6. Mouvement (Priorité : Dash > Engagement d'attaque > Déplacement avec inertie)
	if est_en_dash:
		velocity.x = direction_dash.x * vitesse_dash
		velocity.z = direction_dash.z * vitesse_dash
	elif est_en_attaque:
		velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)
	else:
		gerer_deplacement_normal(delta)

	move_and_slide()

func gerer_garde(temps_actuel: float) -> void:
	var veut_bloquer : bool = Input.is_action_pressed("bloquer") and not est_en_dash and (not est_en_attaque or est_en_counter)
	
	if veut_bloquer and not est_en_garde:
		est_en_garde = true
		temps_debut_garde = temps_actuel
		visuel_garde.visible = true
		flash_fenetre_parry()
	elif not veut_bloquer and est_en_garde:
		est_en_garde = false
		visuel_garde.visible = false

func flash_fenetre_parry() -> void:
	var mat := visuel_garde.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
		await get_tree().create_timer(fenetre_parry_permissive).timeout
		if est_en_garde and mat:
			mat.albedo_color = Color(0.95, 0.77, 0.06, 0.45)

func gerer_deplacement_normal(delta: float) -> void:
	if Input.is_action_just_pressed("sauter") and is_on_floor():
		velocity.y = force_saut

	var input_dir := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var vitesse_cible_max : float = vitesse * 0.55 if est_en_garde else vitesse
	
	if direction:
		# Accélération progressive au lieu d'un changement instantané de vélocité
		velocity.x = move_toward(velocity.x, direction.x * vitesse_cible_max, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * vitesse_cible_max, acceleration * delta)
		
		# Rotation progressive du PivotAttaque (turn rate)
		var angle_cible : float = atan2(-direction.x, -direction.z)
		pivot_attaque.rotation.y = lerp_angle(pivot_attaque.rotation.y, angle_cible, vitesse_rotation_pivot * delta)
		
		var sprite := get_node_or_null("Sprite3D")
		if sprite and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		# Décélération progressive par friction au sol
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

# --- SOFT-LOCK / AIM ASSIST LÉGER VERS L'ENNEMI LE PLUS PROCHE ---
func orienter_legerement_vers_ennemi_proche() -> void:
	var ennemis : Array = get_tree().get_nodes_in_group("ennemis")
	if ennemis.is_empty():
		return

	var ennemi_plus_proche : Node3D = null
	var distance_min : float = portee_aim_assist
	var direction_actuelle : Vector3 = -pivot_attaque.global_transform.basis.z.normalized()

	for ennemi in ennemis:
		if not is_instance_valid(ennemi) or not (ennemi is Node3D):
			continue
		var vers_ennemi : Vector3 = ennemi.global_position - global_position
		vers_ennemi.y = 0.0
		var dist : float = vers_ennemi.length()
		
		if dist <= distance_min and dist > 0.1:
			var angle_ecart : float = rad_to_deg(direction_actuelle.angle_to(vers_ennemi.normalized()))
			# On n'assiste que si l'ennemi est globalement devant ou sur le flanc (dans le cône défini)
			if angle_ecart <= angle_max_aim_assist_deg:
				distance_min = dist
				ennemi_plus_proche = ennemi

	if ennemi_plus_proche:
		var dir_cible : Vector3 = (ennemi_plus_proche.global_position - global_position).normalized()
		dir_cible.y = 0.0
		var angle_cible : float = atan2(-dir_cible.x, -dir_cible.z)
		# Correction fluide (65% vers l'ennemi pour assister sans forcer brutalement)
		pivot_attaque.rotation.y = lerp_angle(pivot_attaque.rotation.y, angle_cible, 0.65)
		
		var sprite := get_node_or_null("Sprite3D")
		if sprite and abs(dir_cible.x) > 0.15:
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

func calculer_cout_dash() -> float:
	if royaume_actuel >= 7:
		return 0.0
	return max(0.0, cout_endurance_base * (1.0 - (royaume_actuel - 1) * 0.15))

func calculer_cooldown_dash() -> float:
	var progression : float = clamp((royaume_actuel - 1) / 9.0, 0.0, 1.0)
	return lerp(cooldown_dash_base, cooldown_dash_min, progression)

func tenter_dash(dir: Vector3) -> void:
	var cout : float = calculer_cout_dash()
	if endurance_actuelle < cout:
		return

	if est_en_attaque:
		est_en_attaque = false
		est_en_counter = false
		hitbox_attaque.monitoring = false
		visuel_slash.visible = false

	est_en_garde = false
	visuel_garde.visible = false

	endurance_actuelle -= cout
	endurance_modifiee.emit(endurance_actuelle, endurance_max)
	
	est_en_dash = true
	peut_dash = false
	direction_dash = dir
	
	# Le pivot s'aligne immédiatement avec la direction du dash
	pivot_attaque.rotation.y = atan2(-dir.x, -dir.z)
	
	est_invulnerable = true
	reduction_degats = 0.75
	poise_actuelle = poise_base * 2.5
	
	var sprite := get_node_or_null("Sprite3D")
	if sprite:
		sprite.modulate = Color(0.5, 0.9, 1.0, 0.5)

	await get_tree().create_timer(duree_dash * 0.65).timeout
	est_invulnerable = false

	await get_tree().create_timer(duree_dash * 0.35).timeout
	est_en_dash = false
	reduction_degats = 0.0
	poise_actuelle = poise_base
	
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	await get_tree().create_timer(calculer_cooldown_dash()).timeout
	peut_dash = true

func tenter_attaque() -> void:
	if endurance_actuelle < cout_endurance_attaque:
		return

	endurance_actuelle -= cout_endurance_attaque
	endurance_modifiee.emit(endurance_actuelle, endurance_max)

	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	index_combo = (index_combo % 3) + 1 if (temps_actuel - temps_derniere_attaque <= fenetre_combo) else 1

	temps_derniere_attaque = temps_actuel
	est_en_attaque = true
	est_en_counter = false
	cibles_touchees_coup_actuel.clear()

	# Ajuste légèrement l'orientation vers l'ennemi proche avant de verrouiller le coup
	orienter_legerement_vers_ennemi_proche()

	direction_attaque_verrouillee = -pivot_attaque.global_transform.basis.z.normalized()
	var elan : float = impulsion_finisher if index_combo == 3 else impulsion_attaque
	velocity.x = direction_attaque_verrouillee.x * elan
	velocity.z = direction_attaque_verrouillee.z * elan

	hitbox_attaque.scale = Vector3(1.3, 1.0, 1.3) if index_combo == 3 else Vector3.ONE
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true

	await get_tree().create_timer(duree_attaque).timeout

	if est_en_attaque and not est_en_counter:
		hitbox_attaque.monitoring = false
		visuel_slash.visible = false
		est_en_attaque = false

func declencher_counter_swbf2() -> void:
	temps_dernier_coup_bloque = -10.0
	
	est_en_attaque = true
	est_en_counter = true
	cibles_touchees_coup_actuel.clear()

	# Oriente légèrement le counter vers l'attaquant proche
	orienter_legerement_vers_ennemi_proche()

	direction_attaque_verrouillee = -pivot_attaque.global_transform.basis.z.normalized()
	velocity.x = direction_attaque_verrouillee.x * impulsion_counter
	velocity.z = direction_attaque_verrouillee.z * impulsion_counter

	var mat_slash := visuel_slash.material_override as StandardMaterial3D
	if mat_slash:
		mat_slash.albedo_color = Color(1.0, 0.9, 0.2)

	hitbox_attaque.scale = Vector3.ONE
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true
	print(">>> COUNTER SWBF2 EXÉCUTÉ !")

	await get_tree().create_timer(duree_counter_rapide).timeout

	hitbox_attaque.monitoring = false
	visuel_slash.visible = false
	est_en_attaque = false
	est_en_counter = false
	
	if mat_slash:
		mat_slash.albedo_color = Color(0.0, 0.85, 1.0)

func recevoir_degats(degats_pv: float, degats_poise: float, attaquant: Node3D) -> void:
	if est_invulnerable:
		print("ESQUIVE PARFAITE (iFrames du Dash) !")
		return

	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	var dir_recul : Vector3 = (global_position - attaquant.global_position).normalized()
	dir_recul.y = 0.0

	if est_en_garde:
		temps_dernier_coup_bloque = temps_actuel
		if temps_actuel - temps_debut_garde <= fenetre_parry_permissive:
			print("PARRY PARFAIT (Sekiro) !")
			if attaquant.has_method("subir_degats_poise_parry"):
				attaquant.subir_degats_poise_parry(degats_poise_parry)
			return
		else:
			var cout_block : float = degats_poise * 0.6
			endurance_actuelle = max(0.0, endurance_actuelle - cout_block)
			endurance_modifiee.emit(endurance_actuelle, endurance_max)
			velocity += dir_recul * 4.0
			print("COUP BLOQUÉ ! Endurance: %.0f" % endurance_actuelle)
			return

	var degats_subis : float = degats_pv * (1.0 - reduction_degats)
	pv_actuels -= degats_subis
	poise_actuelle = max(0.0, poise_actuelle - degats_poise)
	velocity += dir_recul * 5.0

	print("TOUCHÉ ! PV: %.0f | Poise restante: %.0f" % [pv_actuels, poise_actuelle])

	if poise_actuelle <= 0.0 and not est_brise:
		declencher_brisure_garde_joueur()

func declencher_brisure_garde_joueur() -> void:
	est_brise = true
	est_en_garde = false
	visuel_garde.visible = false
	print("ALERTE : VOTRE GARDE (POISE) EST BRISÉE !")
	await get_tree().create_timer(1.2).timeout
	est_brise = false
	poise_actuelle = poise_base

func _on_hitbox_attaque_body_entered(body: Node3D) -> void:
	if body == self or body in cibles_touchees_coup_actuel:
		return

	cibles_touchees_coup_actuel.append(body)

	var multiplicateur : float = 1.5 if (index_combo == 3 and not est_en_counter) else 1.0
	var degats_finaux : float = degats_base * multiplicateur * (1.0 + (royaume_actuel - 1) * 0.5)
	var degats_poise_finaux : float = degats_poise_base * multiplicateur

	if body.has_method("recevoir_degats"):
		if body.has_method("recevoir_degats_avances"):
			body.recevoir_degats_avances(degats_finaux, degats_poise_finaux, global_position, est_en_counter)
		else:
			body.recevoir_degats(degats_finaux, degats_poise_finaux, global_position)
