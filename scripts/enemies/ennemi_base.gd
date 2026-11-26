class_name EnnemiBase
extends CharacterBody3D
## IA modulaire pour les ennemis réels du jeu (Patrouille, Aggro, Poursuite, Attaque Mêlée/Distance, Stagger, Mort).
## Respecte l'échelle exponentielle Dokkan Battle et le système de Poise / Parry / Counter.

enum Etat {
	PATROUILLE,
	POURSUITE,
	PREPARATION,
	ATTAQUE,
	STAGGER,
	MORT
}

@export_group("Identité & Échelle")
@export var nom_ennemi : String = "Disciple Démoniaque"
@export var titre_ennemi : String = ""
@export_range(1, 10) var royaume_ennemi : int = 1
@export var est_boss : bool = false

@export_group("Statistiques de Combat")
@export var pv_max : float = 180.0
@export var poise_max : float = 80.0
@export var delai_regen_poise : float = 3.0
@export var vitesse_regen_poise : float = 20.0
@export var duree_stagger : float = 2.0
@export var degats_pv : float = 22.0
@export var degats_poise : float = 26.0

@export_group("Comportement IA")
@export var vitesse_deplacement : float = 4.2
@export var portee_aggro : float = 10.0
@export var portee_attaque : float = 2.4
@export var est_distance : bool = false
@export var portee_recul_distance : float = 4.5
@export var vitesse_projectile : float = 16.0
@export var duree_telegraphe : float = 0.55
@export var duree_hitbox : float = 0.22
@export var cooldown_attaque : float = 1.6
@export var rayon_patrouille : float = 3.5

@export_group("Visuel & Récompenses")
@export var couleur_normale : Color = Color(0.65, 0.18, 0.25, 1.0)
@export var couleur_telegraphe : Color = Color(1.0, 0.25, 0.5, 1.0)
@export var couleur_stagger : Color = Color(0.95, 0.78, 0.12, 1.0)
@export var recompense_xp : float = 80.0
@export var recompense_cultivation : float = 45.0

@onready var corps_mesh: MeshInstance3D = get_node_or_null("CorpsMesh") as MeshInstance3D
@onready var sprite_3d: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var animator_25d: SpriteAnimator25D = get_node_or_null("SpriteAnimator25D") as SpriteAnimator25D
@onready var label_etat: Label3D = $Label3D
@onready var zone_attaque: Area3D = $ZoneAttaque
@onready var visuel_attaque: MeshInstance3D = $ZoneAttaque/VisuelAttaque

var etat : Etat = Etat.PATROUILLE
var pv_actuels : float = 180.0
var poise_actuelle : float = 80.0
var gravite : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _materiau : StandardMaterial3D = null
var _joueur : Node3D = null
var _pos_origine : Vector3 = Vector3.ZERO
var _cible_patrouille : Vector3 = Vector3.ZERO
var _temps_avant_prochaine_attaque : float = 0.0
var _temps_depuis_dernier_coup : float = 0.0
var _cibles_touchees : Array = []
var _id_action : int = 0
var _id_flash : int = 0
var _boss_engage : bool = false

func _ready() -> void:
	add_to_group("ennemis")
	_pos_origine = global_position
	_cible_patrouille = _pos_origine
	pv_actuels = pv_max
	poise_actuelle = poise_max

	if is_instance_valid(corps_mesh):
		if corps_mesh.material_override is StandardMaterial3D:
			_materiau = (corps_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			corps_mesh.material_override = _materiau
		else:
			_materiau = StandardMaterial3D.new()
			corps_mesh.material_override = _materiau
		_materiau.albedo_color = couleur_normale

	if is_instance_valid(animator_25d) and is_instance_valid(sprite_3d):
		animator_25d.initialiser(sprite_3d)

	zone_attaque.monitoring = false
	visuel_attaque.visible = false
	zone_attaque.body_entered.connect(_on_zone_attaque_body_entered)
	_mettre_a_jour_label()

func _physics_process(delta: float) -> void:
	if etat == Etat.MORT:
		return

	if not is_on_floor():
		velocity.y -= gravite * delta

	_temps_avant_prochaine_attaque = maxf(0.0, _temps_avant_prochaine_attaque - delta)
	_temps_depuis_dernier_coup += delta

	if etat != Etat.STAGGER and _temps_depuis_dernier_coup >= delai_regen_poise and poise_actuelle < poise_max:
		var regen_eff : float = maxf(vitesse_regen_poise, poise_max * 0.25)
		poise_actuelle = minf(poise_max, poise_actuelle + regen_eff * delta)
		_notifier_etat_ui()

	if not is_instance_valid(_joueur):
		var j := get_tree().get_first_node_in_group("joueur")
		if j is Node3D:
			_joueur = j as Node3D

	match etat:
		Etat.PATROUILLE:
			_process_patrouille(delta)
		Etat.POURSUITE:
			_process_poursuite(delta)
		Etat.PREPARATION, Etat.ATTAQUE:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			if etat == Etat.PREPARATION and is_instance_valid(_joueur):
				_regarder_vers(_joueur.global_position)
		Etat.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)

	move_and_slide()
	if is_instance_valid(animator_25d):
		animator_25d.mettre_a_jour(delta, velocity, is_on_floor(), false, false, false, false, etat == Etat.STAGGER)

func _process_patrouille(delta: float) -> void:
	if is_instance_valid(_joueur):
		var dist_j : float = _distance_horizontale(global_position, _joueur.global_position)
		if dist_j <= portee_aggro:
			_engager_combat()
			return

	var dist_cible : float = _distance_horizontale(global_position, _cible_patrouille)
	if dist_cible < 0.6:
		var angle : float = randf() * TAU
		var rayon : float = randf_range(1.0, rayon_patrouille)
		_cible_patrouille = _pos_origine + Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon)
	else:
		var dir : Vector3 = _dir_horizontale(global_position, _cible_patrouille)
		velocity.x = move_toward(velocity.x, dir.x * vitesse_deplacement * 0.45, 14.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * vitesse_deplacement * 0.45, 14.0 * delta)
		_regarder_vers(_cible_patrouille)

func _process_poursuite(delta: float) -> void:
	if not is_instance_valid(_joueur):
		etat = Etat.PATROUILLE
		return

	var dist_j : float = _distance_horizontale(global_position, _joueur.global_position)
	if dist_j > portee_aggro * 1.85 and not est_boss:
		etat = Etat.PATROUILLE
		return

	_regarder_vers(_joueur.global_position)

	if dist_j <= portee_attaque and _temps_avant_prochaine_attaque <= 0.0:
		_lancer_attaque()
		return

	var dir : Vector3 = _dir_horizontale(global_position, _joueur.global_position)
	if est_distance and dist_j < portee_recul_distance:
		# Recul tactique pour un cultivateur à distance
		velocity.x = move_toward(velocity.x, -dir.x * vitesse_deplacement * 0.75, 18.0 * delta)
		velocity.z = move_toward(velocity.z, -dir.z * vitesse_deplacement * 0.75, 18.0 * delta)
	elif dist_j > portee_attaque * 0.85:
		velocity.x = move_toward(velocity.x, dir.x * vitesse_deplacement, 18.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * vitesse_deplacement, 18.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

func _engager_combat() -> void:
	etat = Etat.POURSUITE
	if est_boss and not _boss_engage:
		_boss_engage = true
		EventBus.boss_encounter_started.emit(nom_ennemi, titre_ennemi, pv_actuels, pv_max, poise_actuelle, poise_max)

func _lancer_attaque() -> void:
	_id_action += 1
	var id_local : int = _id_action
	etat = Etat.PREPARATION
	_mettre_a_jour_label()
	if _materiau:
		_materiau.albedo_color = couleur_telegraphe
	if is_instance_valid(animator_25d):
		animator_25d.definir_teinte_etat(Color(1.45, 0.55, 0.72, 1.0))
	elif is_instance_valid(sprite_3d):
		sprite_3d.modulate = Color(1.45, 0.55, 0.72, 1.0)

	await get_tree().create_timer(duree_telegraphe).timeout
	if not is_inside_tree() or _id_action != id_local or etat != Etat.PREPARATION:
		return

	etat = Etat.ATTAQUE
	_cibles_touchees.clear()
	if is_instance_valid(animator_25d):
		animator_25d.jouer_coup(est_boss, false)

	if est_distance:
		_tirer_projectile_ennemi()
	else:
		zone_attaque.monitoring = true
		visuel_attaque.visible = true

	await get_tree().create_timer(duree_hitbox).timeout
	if not is_inside_tree() or _id_action != id_local:
		return

	zone_attaque.monitoring = false
	visuel_attaque.visible = false
	_temps_avant_prochaine_attaque = cooldown_attaque
	if etat == Etat.ATTAQUE:
		etat = Etat.POURSUITE
		if _materiau:
			_materiau.albedo_color = couleur_normale
		if is_instance_valid(animator_25d):
			animator_25d.definir_teinte_etat(Color.WHITE)
		elif is_instance_valid(sprite_3d):
			sprite_3d.modulate = Color.WHITE
		_mettre_a_jour_label()

func _tirer_projectile_ennemi() -> void:
	if not is_instance_valid(_joueur):
		return
	var racine := get_tree().current_scene
	if racine == null:
		return
	var dir : Vector3 = _dir_horizontale(global_position, _joueur.global_position)
	if dir == Vector3.ZERO:
		dir = -global_transform.basis.z.normalized()

	var info := DamageInfo.creer(
		degats_pv,
		degats_poise,
		self,
		global_position,
		false,
		royaume_ennemi,
		SkillData.Element.ECLAIR,
		false
	)
	var proj := ProjectileQi.new()
	racine.add_child(proj)
	proj.initialiser(
		self,
		global_position + Vector3(0.0, 1.1, 0.0) + dir * 0.9,
		dir,
		vitesse_projectile,
		portee_attaque + 4.0,
		info,
		couleur_telegraphe,
		SkillData.Element.ECLAIR
	)

func _on_zone_attaque_body_entered(body: Node3D) -> void:
	if etat != Etat.ATTAQUE or body == self or body in _cibles_touchees:
		return
	if not body.is_in_group("joueur"):
		return
	_cibles_touchees.append(body)
	var info := DamageInfo.creer(degats_pv, degats_poise, self, global_position, false, royaume_ennemi)
	if body.has_method("recevoir_degats_info"):
		body.recevoir_degats_info(info)
	elif body.has_method("recevoir_degats"):
		body.recevoir_degats(degats_pv, degats_poise, self)

func subir_degats_poise_parry(montant_poise: float, royaume_defenseur: int = 1) -> void:
	if etat == Etat.MORT or etat == Etat.STAGGER:
		return
	var facteur_supp : float = DamageInfo.calculer_facteur_suppression_poise(royaume_defenseur, royaume_ennemi)
	if facteur_supp <= 0.0:
		_mettre_a_jour_label("POISE IMPÉNÉTRABLE (R%d) !" % royaume_ennemi)
		print("[SUPPRESSION ROYAUME] Parry R%d impuissant face à la Poise de %s (R%d) !" % [
			royaume_defenseur, nom_ennemi, royaume_ennemi
		])
		return
	_temps_depuis_dernier_coup = 0.0
	poise_actuelle = maxf(0.0, poise_actuelle - montant_poise * facteur_supp)
	_notifier_etat_ui()
	if poise_actuelle <= 0.0:
		_declencher_stagger(Vector3.ZERO)

func recevoir_degats(p_degats_pv: float, p_degats_poise: float, position_attaquant: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(p_degats_pv, p_degats_poise, null, position_attaquant, false))

func recevoir_degats_info(info: DamageInfo) -> void:
	if etat == Etat.MORT:
		return

	if etat == Etat.PATROUILLE:
		_engager_combat()

	_temps_depuis_dernier_coup = 0.0
	var est_brise : bool = (etat == Etat.STAGGER)
	var mult_posture : float = 1.5 if est_brise else 1.0
	var degats_effectifs : float = info.degats_pv * mult_posture

	pv_actuels = maxf(0.0, pv_actuels - degats_effectifs)
	EventBus.entity_damaged.emit(self, info)
	NumberFormatter.spawn_floating_damage(self, global_position, degats_effectifs, info.est_critique, info.est_counter, est_brise)

	var dir_recul : Vector3 = _dir_horizontale(info.position_origine, global_position)
	var facteur_supp : float = DamageInfo.calculer_facteur_suppression_poise(info.royaume_attaquant, royaume_ennemi)

	if not est_brise:
		if facteur_supp <= 0.0:
			# Suppression de Royaume : un cultivateur 2+ Royaumes en dessous ne peut même pas égratigner la Poise !
			_flash_impact(Color(0.75, 0.75, 0.85))
			_mettre_a_jour_label("POISE IMPÉNÉTRABLE (R%d)" % royaume_ennemi)
			print("[SUPPRESSION ROYAUME] Attaque R%d : 0 dégât Poise sur %s (R%d) !" % [
				info.royaume_attaquant, nom_ennemi, royaume_ennemi
			])
		else:
			poise_actuelle = maxf(0.0, poise_actuelle - info.degats_poise * facteur_supp)
			velocity += dir_recul * (2.0 if est_boss else 3.5)
			if poise_actuelle <= 0.0:
				_declencher_stagger(dir_recul)
			else:
				_flash_impact(Color(1.0, 1.0, 1.0))
	else:
		velocity += dir_recul * (3.5 if est_boss else 5.5)
		_flash_impact(Color(1.0, 0.85, 0.0))

	_notifier_etat_ui()
	_sur_degats_subis(info)

	if pv_actuels <= 0.0:
		_mourir(info.attaquant)

# Hook surchargeable par les Boss (ex: Phase 2, réactions méta-narratives)
func _sur_degats_subis(_info: DamageInfo) -> void:
	pass

func _declencher_stagger(dir_recul: Vector3) -> void:
	_id_action += 1
	var id_local : int = _id_action
	etat = Etat.STAGGER
	zone_attaque.monitoring = false
	visuel_attaque.visible = false
	velocity += dir_recul * (5.0 if est_boss else 9.0)

	if _materiau:
		_materiau.albedo_color = couleur_stagger
	if is_instance_valid(animator_25d):
		animator_25d.definir_teinte_etat(Color(1.25, 1.05, 0.45, 1.0))
	EventBus.entity_guard_broken.emit(self)
	_notifier_etat_ui()

	await get_tree().create_timer(duree_stagger).timeout
	if not is_inside_tree() or _id_action != id_local or etat == Etat.MORT:
		return

	etat = Etat.POURSUITE
	poise_actuelle = poise_max
	if _materiau:
		_materiau.albedo_color = couleur_normale
	if is_instance_valid(animator_25d):
		animator_25d.definir_teinte_etat(Color.WHITE)
	_notifier_etat_ui()

func _flash_impact(couleur: Color) -> void:
	if is_instance_valid(animator_25d):
		animator_25d.jouer_impact(Color(1.6, 1.6, 1.6, 1.0) if etat != Etat.STAGGER else Color(1.4, 1.2, 0.5, 1.0))
	if not _materiau:
		return
	_id_flash += 1
	var id_local : int = _id_flash
	_materiau.albedo_color = couleur
	await get_tree().create_timer(0.08).timeout
	if _id_flash == id_local and _materiau and etat != Etat.MORT:
		_materiau.albedo_color = couleur_stagger if etat == Etat.STAGGER else (
			couleur_telegraphe if etat == Etat.PREPARATION else couleur_normale
		)

func _mourir(tueur: Node) -> void:
	_id_action += 1
	etat = Etat.MORT
	zone_attaque.monitoring = false
	visuel_attaque.visible = false
	remove_from_group("ennemis")

	if _boss_engage:
		_boss_engage = false
		EventBus.boss_encounter_ended.emit()

	# Récompenses XP + Cultivation pour le joueur
	var cible_joueur := tueur if (is_instance_valid(tueur) and tueur.is_in_group("joueur")) else _joueur
	if is_instance_valid(cible_joueur):
		if cible_joueur.has_node("StatsComponent"):
			var s := cible_joueur.get_node("StatsComponent") as StatsComponent
			if s:
				s.gagner_xp(recompense_xp)
		if cible_joueur.has_node("CultivationComponent"):
			var c := cible_joueur.get_node("CultivationComponent") as CultivationComponent
			if c and c.stats and c.stats.royaume_actuel < 10:
				c.cultivation_actuelle = minf(c.get_cultivation_requise(), c.cultivation_actuelle + recompense_cultivation)
				c.emettre_etat()

	EventBus.entity_died.emit(self, tueur)
	print("[VICTOIRE] %s (R%d) vaincu ! (+%s XP, +%s Cultivation)" % [
		nom_ennemi, royaume_ennemi, NumberFormatter.format(recompense_xp), NumberFormatter.format(recompense_cultivation)
	])

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.45)
	tw.chain().tween_callback(queue_free)

func _notifier_etat_ui() -> void:
	_mettre_a_jour_label()
	if _boss_engage:
		EventBus.boss_status_updated.emit(pv_actuels, pv_max, poise_actuelle, poise_max, etat == Etat.STAGGER)

func _mettre_a_jour_label(alerte: String = "") -> void:
	if not is_node_ready():
		return
	var prefixe : String = "[R%d] %s" % [royaume_ennemi, nom_ennemi]
	if etat == Etat.PREPARATION:
		# L'indicateur d'attaque reste TOUJOURS visible tant que la préparation n'est pas brisée !
		label_etat.text = "%s\n%s" % [prefixe, alerte if alerte != "" else "!! ATTAQUE IMMINENTE !!"]
		label_etat.modulate = Color(1.0, 0.25, 0.48)
	elif alerte != "":
		label_etat.text = "%s\n%s" % [prefixe, alerte]
		label_etat.modulate = Color(1.0, 0.35, 0.55)
	elif etat == Etat.STAGGER:
		label_etat.text = "%s\nPV : %s | [BRISÉ !]" % [prefixe, NumberFormatter.format(pv_actuels)]
		label_etat.modulate = Color(1.0, 0.85, 0.2)
	else:
		label_etat.text = "%s\nPV : %s | Poise : %s" % [prefixe, NumberFormatter.format(pv_actuels), NumberFormatter.format(poise_actuelle)]
		label_etat.modulate = Color(1.0, 1.0, 1.0)

func _regarder_vers(cible_pos: Vector3) -> void:
	var dir : Vector3 = _dir_horizontale(global_position, cible_pos)
	if dir == Vector3.ZERO:
		return
	# Pivote la zone d'attaque (comme PivotAttaque du joueur) pour garder le Sprite3D HD-2D face caméra !
	zone_attaque.rotation.y = atan2(-dir.x, -dir.z)
	if is_instance_valid(sprite_3d) and absf(dir.x) > 0.12:
		sprite_3d.flip_h = dir.x < 0.0

func _distance_horizontale(a: Vector3, b: Vector3) -> float:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.length()

func _dir_horizontale(de: Vector3, vers: Vector3) -> Vector3:
	var d := Vector3(vers.x - de.x, 0.0, vers.z - de.z)
	if d.length_squared() < 0.0001:
		return Vector3.ZERO
	return d.normalized()
