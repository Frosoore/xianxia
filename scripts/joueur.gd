extends CharacterBody3D

# --- SIGNAUX ---
signal endurance_modifiee(actuelle: float, maximum: float)
signal qi_modifie(actuel: float, maximum: float)
signal royaume_modifie(nouveau_royaume: int)

# --- PARAMÈTRES DE DÉPLACEMENT ---
@export_group("Mouvement")
@export var vitesse : float = 6.0
@export var force_saut : float = 5.5

# --- PARAMÈTRES DU DASH ---
@export_group("Dash & Mobilité")
@export var vitesse_dash : float = 22.0
@export var duree_dash : float = 0.22
@export var cooldown_dash_base : float = 0.75
@export var cooldown_dash_min : float = 0.05
@export var fenetre_double_tap : float = 0.25
@export var cout_endurance_base : float = 15.0

# --- PARAMÈTRES D'ATTAQUE & COUNTER ---
@export_group("Attaque, Parade & Counter")
@export var degats_base : float = 20.0
@export var degats_poise_base : float = 25.0
@export var cout_endurance_attaque : float = 8.0
@export var duree_attaque : float = 0.22
@export var fenetre_combo : float = 0.8

@export var fenetre_parry_permissive : float = 0.32 # Fenêtre généreuse façon Sekiro
@export var fenetre_counter_swbf2 : float = 0.45    # Fenêtre après un blocage pour déclencher le counter
@export var duree_counter_rapide : float = 0.11     # Attaque giga rapide
@export var degats_poise_parry : float = 45.0       # Dégâts de posture infligés à l'attaquant sur un Parry

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

	# Si garde brisée, le joueur est brièvement étourdi
	if est_brise:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	# 3. Gestion de la Garde (Maintien du bouton bloquer)
	gerer_garde(temps_actuel)

	# 4. Double-Tap Dash (Dash Cancel autorisé à tout moment)
	if not est_en_dash and peut_dash:
		verifier_double_tap()

	# 5. Attaque ou Counter SWBF2
	if Input.is_action_just_pressed("attaquer") and not est_en_dash:
		# Si on maintient la garde ET qu'on vient de bloquer/parer un coup : COUNTER SWBF2 !
		if est_en_garde and (temps_actuel - temps_dernier_coup_bloque <= fenetre_counter_swbf2):
			declencher_counter_swbf2()
		elif not est_en_attaque:
			# Si on attaque normalement, la garde s'abaisse
			est_en_garde = false
			visuel_garde.visible = false
			tenter_attaque()

	# 6. Mouvement
	if est_en_dash:
		velocity.x = direction_dash.x * vitesse_dash
		velocity.z = direction_dash.z * vitesse_dash
	else:
		gerer_deplacement_normal()

	move_and_slide()

func gerer_garde(temps_actuel: float) -> void:
	# On peut garder en permanence sauf pendant un dash ou une attaque normale (mais on garde pendant un Counter !)
	var veut_bloquer : bool = Input.is_action_pressed("bloquer") and not est_en_dash and (not est_en_attaque or est_en_counter)
	
	if veut_bloquer and not est_en_garde:
		est_en_garde = true
		temps_debut_garde = temps_actuel
		visuel_garde.visible = true
		# Teinte blanche brillante pendant la fenêtre de Parry parfait
		flash_fenetre_parry()
	elif not veut_bloquer and est_en_garde:
		est_en_garde = false
		visuel_garde.visible = false

func flash_fenetre_parry() -> void:
	var mat := visuel_garde.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8) # Éclat blanc pour visualiser la fenêtre Parry
		await get_tree().create_timer(fenetre_parry_permissive).timeout
		if est_en_garde and mat:
			mat.albedo_color = Color(0.95, 0.77, 0.06, 0.45) # Retour au doré (blocage standard)

func gerer_deplacement_normal() -> void:
	if Input.is_action_just_pressed("sauter") and is_on_floor():
		velocity.y = force_saut

	var input_dir := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var vitesse_effective : float = vitesse
	if est_en_garde and not est_en_counter:
		vitesse_effective = vitesse * 0.55
	elif est_en_attaque and not est_en_counter:
		vitesse_effective = vitesse * 0.4
	
	if direction:
		velocity.x = direction.x * vitesse_effective
		velocity.z = direction.z * vitesse_effective
		
		pivot_attaque.look_at(pivot_attaque.global_position + direction, Vector3.UP)
		
		var sprite := get_node_or_null("Sprite3D")
		if sprite and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		velocity.x = move_toward(velocity.x, 0, vitesse_effective)
		velocity.z = move_toward(velocity.z, 0, vitesse_effective)

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

	hitbox_attaque.scale = Vector3(1.3, 1.0, 1.3) if index_combo == 3 else Vector3.ONE
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true

	await get_tree().create_timer(duree_attaque).timeout

	if est_en_attaque and not est_en_counter:
		hitbox_attaque.monitoring = false
		visuel_slash.visible = false
		est_en_attaque = false

# --- MÉCANIQUE DE COUNTER FAÇON STAR WARS BATTLEFRONT II ---
func declencher_counter_swbf2() -> void:
	# Consomme la fenêtre de counter pour éviter le spam infini sur un seul blocage
	temps_dernier_coup_bloque = -10.0
	
	est_en_attaque = true
	est_en_counter = true
	# IMPORTANT : est_en_garde reste TRUE et visuel_garde reste VISIBLE pendant tout le coup !
	cibles_touchees_coup_actuel.clear()

	# Visuel doré/blanc ultra rapide
	var mat_slash := visuel_slash.material_override as StandardMaterial3D
	if mat_slash:
		mat_slash.albedo_color = Color(1.0, 0.9, 0.2) # Éclair doré pour distinguer le Counter

	hitbox_attaque.scale = Vector3.ONE
	hitbox_attaque.monitoring = true
	visuel_slash.visible = true
	print(">>> COUNTER SWBF2 EXÉCUTÉ ! (Garde maintenue + Coup ultra-rapide quasi imblocable)")

	await get_tree().create_timer(duree_counter_rapide).timeout

	hitbox_attaque.monitoring = false
	visuel_slash.visible = false
	est_en_attaque = false
	est_en_counter = false
	
	if mat_slash:
		mat_slash.albedo_color = Color(0.0, 0.85, 1.0) # Retour au cyan normal

# --- RÉCEPTION DES DÉGÂTS (PARRY SEKIRO, BLOCAGE & POISE) ---
func recevoir_degats(degats_pv: float, degats_poise: float, attaquant: Node3D) -> void:
	# 1. iFrames du Dash
	if est_invulnerable:
		print("ESQUIVE PARFAITE (iFrames du Dash) !")
		return

	var temps_actuel : float = Time.get_ticks_msec() / 1000.0
	var dir_recul : Vector3 = (global_position - attaquant.global_position).normalized()
	dir_recul.y = 0.0

	# 2. Gestion de la Garde (fonctionne aussi pendant un Counter SWBF2 !)
	if est_en_garde:
		temps_dernier_coup_bloque = temps_actuel # Ouvre la fenêtre de Counter SWBF2 !
		
		# Vérification du Parry Parfait (Sekiro)
		if temps_actuel - temps_debut_garde <= fenetre_parry_permissive:
			print("PARRY PARFAIT (Sekiro) ! 0 dégât | +%.0f dégâts Poise renvoyés ! [Appuyez sur Attaquer pour Counter !]" % degats_poise_parry)
			# Renvoie des dégâts de Poise massifs à l'attaquant
			if attaquant.has_method("subir_degats_poise_parry"):
				attaquant.subir_degats_poise_parry(degats_poise_parry)
			return
		else:
			# Blocage Standard (garde levée depuis plus longtemps)
			var cout_block : float = degats_poise * 0.6
			endurance_actuelle = max(0.0, endurance_actuelle - cout_block)
			endurance_modifiee.emit(endurance_actuelle, endurance_max)
			velocity += dir_recul * 4.0 # Le fameux mini-recul qui permet de caler le Counter SWBF2 !
			print("COUP BLOQUÉ ! Mini-recul subi | Endurance: %.0f [Appuyez sur Attaquer maintenant pour Counter !]" % endurance_actuelle)
			return

	# 3. Impact direct (sans garde)
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

	# Le Counter SWBF2 n'est pas boosté en dégâts (fidèle à votre demande), juste ultra rapide et quasi imblocable
	var multiplicateur : float = 1.5 if (index_combo == 3 and not est_en_counter) else 1.0
	var degats_finaux : float = degats_base * multiplicateur * (1.0 + (royaume_actuel - 1) * 0.5)
	var degats_poise_finaux : float = degats_poise_base * multiplicateur

	if body.has_method("recevoir_degats"):
		# On transmet "est_en_counter" pour signaler que le coup est quasi imblocable
		if body.has_method("recevoir_degats_avances"):
			body.recevoir_degats_avances(degats_finaux, degats_poise_finaux, global_position, est_en_counter)
		else:
			body.recevoir_degats(degats_finaux, degats_poise_finaux, global_position)
