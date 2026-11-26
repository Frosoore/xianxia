class_name TribulationManager
extends Node3D
## Orchestre les Percées & Tribulations Célestes en temps réel.
## La réussite dépend majoritairement du SKILL pendant la Tribulation (~80% : Parry Céleste, Dash iFrames, esquive)
## et secondairement de la LUCK / Destin (~20% : stat Chance + aléa cosmique).

@export_group("Paramètres Tribulation")
@export var rayon_eclair : float = 2.4
@export var duree_telegraphe_suivi : float = 0.25
@export var duree_telegraphe_verrouille : float = 0.58
@export var intervalle_entre_eclairs : float = 0.62
@export var ratio_degats_pv_par_eclair : float = 0.30
@export var degats_poise_eclair : float = 40.0
@export var rayon_onde_ascension : float = 8.0

var _id_tribulation : int = 0
var _en_cours : bool = false
var _joueur_vaincu : bool = false

# Suivi du Skill en direct pendant la Tribulation
var _score_skill : float = 0.30
var _bonus_luck : float = 0.05
var _eclair_touche_vague : bool = false

# Sauvegarde atmosphère
var _env_sauvegarde : bool = false
var _lumiere_energie_origine : float = 1.0
var _lumiere_couleur_origine : Color = Color.WHITE
var _ciel_horizon_origine : Color = Color(0.66, 0.67, 0.69, 1.0)
var _ciel_top_origine : Color = Color(0.38, 0.45, 0.55, 1.0)

func _ready() -> void:
	EventBus.breakthrough_started.connect(_on_breakthrough_started)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.parry_succeeded.connect(_on_parry_succeeded)
	EventBus.dash_evade_succeeded.connect(_on_dash_evade_succeeded)
	EventBus.entity_damaged.connect(_on_entity_damaged)

func _on_entity_died(cible: Node, _tueur: Node) -> void:
	if _en_cours and is_instance_valid(cible) and cible.is_in_group("joueur"):
		_joueur_vaincu = true

func _on_parry_succeeded(defenseur: Node, attaquant: Node) -> void:
	if _en_cours and attaquant == self and is_instance_valid(defenseur) and defenseur.is_in_group("joueur"):
		_eclair_touche_vague = true
		_score_skill = minf(1.0, _score_skill + 0.24)
		EventBus.tribulation_mastery_updated.emit(_score_skill, _bonus_luck)
		print("[TRIBULATION SKILL] Parry Céleste ! Maîtrise : %.0f%%" % (_score_skill * 100.0))

func _on_dash_evade_succeeded(esquiveur: Node, source: Node) -> void:
	if _en_cours and source == self and is_instance_valid(esquiveur) and esquiveur.is_in_group("joueur"):
		_eclair_touche_vague = true
		_score_skill = minf(1.0, _score_skill + 0.16)
		EventBus.tribulation_mastery_updated.emit(_score_skill, _bonus_luck)
		print("[TRIBULATION SKILL] Esquive Parfaite (iFrames) ! Maîtrise : %.0f%%" % (_score_skill * 100.0))

func _on_entity_damaged(cible: Node, info: DamageInfo) -> void:
	if _en_cours and info.attaquant == self and is_instance_valid(cible) and cible.is_in_group("joueur"):
		_eclair_touche_vague = true
		_score_skill = maxf(0.05, _score_skill - 0.18)
		EventBus.tribulation_mastery_updated.emit(_score_skill, _bonus_luck)
		print("[TRIBULATION SKILL] Éclair encaissé ! Maîtrise : %.0f%%" % (_score_skill * 100.0))

func _trouver_joueur() -> Node3D:
	var j := get_tree().get_first_node_in_group("joueur")
	if j is Node3D:
		return j
	return null

func _on_breakthrough_started(royaume_cible: int, nb_eclairs: int) -> void:
	var joueur := _trouver_joueur()
	if joueur == null:
		return

	_id_tribulation += 1
	var id_local := _id_tribulation
	_en_cours = true
	_joueur_vaincu = false
	_score_skill = 0.30
	_bonus_luck = 0.05

	var difficulte := 1.0
	if joueur.has_node("StatsComponent"):
		var stats := joueur.get_node("StatsComponent") as StatsComponent
		if stats:
			_bonus_luck = stats.calculer_bonus_luck_percee()
			difficulte = stats.get_difficulte_tribulation_prochain_royaume()

	_basculer_ciel_orage(true)
	EventBus.tribulation_mastery_updated.emit(_score_skill, _bonus_luck)

	var nb_vagues := clampi(maxi(nb_eclairs, 2), 2, 12)
	var eclairs_par_vague := 1 if nb_eclairs <= 12 else (2 if nb_eclairs <= 27 else 3)
	var duree_verrou := maxf(0.32, duree_telegraphe_verrouille / sqrt(difficulte))
	var intervalle := maxf(0.28, (intervalle_entre_eclairs / sqrt(difficulte)) - (nb_vagues - 2) * 0.02)

	await get_tree().create_timer(0.8).timeout

	for vague in range(1, nb_vagues + 1):
		if not is_inside_tree() or _id_tribulation != id_local:
			return
		if _joueur_vaincu or not is_instance_valid(joueur):
			_terminer_echec(royaume_cible, "Terrassé par la Foudre Céleste !")
			return

		_eclair_touche_vague = false
		EventBus.tribulation_lightning_incoming.emit(vague, nb_vagues, _score_skill, _bonus_luck)

		_declencher_eclair(joueur, royaume_cible, Vector3.ZERO, duree_verrou)
		for extra in range(1, eclairs_par_vague):
			var angle := randf() * TAU
			var decalage := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.2, 4.4)
			_declencher_eclair(joueur, royaume_cible, decalage, duree_verrou)

		var duree_totale_eclair := duree_telegraphe_suivi + duree_verrou + 0.25
		await get_tree().create_timer(duree_totale_eclair).timeout

		if not is_inside_tree() or _id_tribulation != id_local:
			return
		if _joueur_vaincu:
			_terminer_echec(royaume_cible, "Terrassé par la Foudre Céleste !")
			return

		# Si le joueur est sorti de la zone sans subir d'impact (esquive de placement), petit bonus Skill
		if not _eclair_touche_vague:
			_score_skill = minf(1.0, _score_skill + 0.08)
			EventBus.tribulation_mastery_updated.emit(_score_skill, _bonus_luck)

		await get_tree().create_timer(intervalle).timeout

	if not is_inside_tree() or _id_tribulation != id_local:
		return

	# Résolution finale : SKILL (~80%) + LUCK (~20% avec léger aléa de Destin)
	var alea_destin := randf_range(-0.06, 0.08)
	var chance_finale := clampf(_score_skill * 0.80 + _bonus_luck + alea_destin, 0.05, 0.99)
	var tirage := randf()

	print("[VERDICT PERCÉE] Skill: %.0f%% (x0.80) + Luck: +%.0f%% (Destin: %+.0f%%) = %.0f%% | Tirage: %.0f%%" % [
		_score_skill * 100.0, _bonus_luck * 100.0, alea_destin * 100.0, chance_finale * 100.0, tirage * 100.0
	])

	if tirage <= chance_finale:
		_terminer_reussite(royaume_cible, joueur, chance_finale)
	else:
		var msg := "Rejet du Dao (Maîtrise %.0f%% + Luck %.0f%% → %.0f%%). Parez/Esquivez mieux !" % [
			_score_skill * 100.0, _bonus_luck * 100.0, chance_finale * 100.0
		]
		_terminer_echec(royaume_cible, msg)

func _declencher_eclair(joueur: Node3D, royaume_cible: int, decalage: Vector3, duree_verrou: float) -> void:
	if not is_instance_valid(joueur):
		return

	var pos_impact := joueur.global_position + decalage
	pos_impact.y = joueur.global_position.y

	var telegraphe := _creer_telegraphe(pos_impact)
	add_child(telegraphe)

	var temps_suivi := 0.0
	while temps_suivi < duree_telegraphe_suivi and is_inside_tree() and is_instance_valid(joueur):
		await get_tree().process_frame
		temps_suivi += get_process_delta_time()
		if is_instance_valid(joueur) and is_instance_valid(telegraphe):
			pos_impact = joueur.global_position + decalage
			telegraphe.global_position = Vector3(pos_impact.x, pos_impact.y + 0.06, pos_impact.z)

	if is_instance_valid(telegraphe):
		var mat_tel := telegraphe.material_override as StandardMaterial3D
		if mat_tel:
			mat_tel.albedo_color = Color(1.0, 0.2, 0.45, 0.72)
			mat_tel.emission = Color(1.0, 0.25, 0.55, 1.0)
		var tw := create_tween()
		tw.tween_property(telegraphe, "scale", Vector3(1.08, 1.0, 1.08), duree_verrou * 0.5)
		tw.tween_property(telegraphe, "scale", Vector3(0.92, 1.0, 0.92), duree_verrou * 0.5)

	await get_tree().create_timer(duree_verrou).timeout

	if is_instance_valid(telegraphe):
		telegraphe.queue_free()
	if not is_inside_tree():
		return

	_creer_vfx_eclair(pos_impact)
	_appliquer_degats_eclair(pos_impact, joueur, royaume_cible)

func _creer_telegraphe(pos: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon_eclair
	cyl.bottom_radius = rayon_eclair
	cyl.height = 0.05
	mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.65, 0.3, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.35, 1.0, 1.0)
	mat.emission_energy_multiplier = 1.8
	mesh_inst.material_override = mat
	mesh_inst.global_position = Vector3(pos.x, pos.y + 0.06, pos.z)
	return mesh_inst

func _creer_vfx_eclair(pos: Vector3) -> void:
	var conteneur := Node3D.new()
	add_child(conteneur)
	conteneur.global_position = pos

	var pilier := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.75
	cyl.height = 20.0
	pilier.mesh = cyl
	pilier.position = Vector3(0.0, 10.0, 0.0)

	var mat_pilier := StandardMaterial3D.new()
	mat_pilier.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_pilier.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_pilier.albedo_color = Color(0.85, 0.9, 1.0, 0.95)
	mat_pilier.emission_enabled = true
	mat_pilier.emission = Color(0.75, 0.65, 1.0, 1.0)
	mat_pilier.emission_energy_multiplier = 5.0
	pilier.material_override = mat_pilier
	conteneur.add_child(pilier)

	var flash := OmniLight3D.new()
	flash.light_color = Color(0.75, 0.8, 1.0)
	flash.light_energy = 10.0
	flash.omni_range = 12.0
	flash.position = Vector3(0.0, 2.5, 0.0)
	conteneur.add_child(flash)

	var onde := MeshInstance3D.new()
	var cyl_onde := CylinderMesh.new()
	cyl_onde.top_radius = rayon_eclair
	cyl_onde.bottom_radius = rayon_eclair
	cyl_onde.height = 0.15
	onde.mesh = cyl_onde
	onde.position = Vector3(0.0, 0.1, 0.0)
	onde.scale = Vector3(0.25, 1.0, 0.25)

	var mat_onde := StandardMaterial3D.new()
	mat_onde.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_onde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_onde.albedo_color = Color(0.8, 0.7, 1.0, 0.85)
	mat_onde.emission_enabled = true
	mat_onde.emission = Color(0.8, 0.7, 1.0, 1.0)
	mat_onde.emission_energy_multiplier = 3.0
	onde.material_override = mat_onde
	conteneur.add_child(onde)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(pilier, "scale", Vector3(0.05, 1.0, 0.05), 0.26)
	tw.tween_property(mat_pilier, "albedo_color:a", 0.0, 0.26)
	tw.tween_property(flash, "light_energy", 0.0, 0.24)
	tw.tween_property(onde, "scale", Vector3(1.5, 1.0, 1.5), 0.3)
	tw.tween_property(mat_onde, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(conteneur.queue_free)

func _appliquer_degats_eclair(pos_impact: Vector3, joueur: Node3D, royaume_cible: int) -> void:
	if is_instance_valid(joueur) and joueur.has_method("secouer_camera"):
		joueur.secouer_camera(0.25, 0.22)

	var cibles : Array = []
	if is_instance_valid(joueur):
		cibles.append(joueur)
	for ennemi in get_tree().get_nodes_in_group("ennemis"):
		if is_instance_valid(ennemi) and ennemi is Node3D:
			cibles.append(ennemi)
	for destr in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(destr) and destr is Node3D:
			cibles.append(destr)

	var degats_pv : float = 45.0
	var poise_eclair : float = degats_poise_eclair
	if is_instance_valid(joueur) and joueur.has_node("StatsComponent"):
		var stats := joueur.get_node("StatsComponent") as StatsComponent
		if stats:
			degats_pv = stats.get_pv_max() * ratio_degats_pv_par_eclair
			poise_eclair = stats.get_poise_max() * 0.65

	for cible in cibles:
		var cible_3d := cible as Node3D
		var dans_zone : bool = cible_3d.is_in_group("terrain_destructible")
		if not dans_zone:
			var delta_pos : Vector3 = cible_3d.global_position - pos_impact
			delta_pos.y = 0.0
			dans_zone = delta_pos.length() <= rayon_eclair + 1.0
		if dans_zone:
			var info := DamageInfo.creer(
				degats_pv,
				poise_eclair,
				self,
				pos_impact,
				false,
				maxi(royaume_cible, 5),
				SkillData.Element.ECLAIR,
				false,
				false,
				royaume_cible
			)
			if cible_3d.has_method("recevoir_degats_info"):
				cible_3d.recevoir_degats_info(info)
			elif cible_3d.has_method("recevoir_degats"):
				cible_3d.recevoir_degats(info.degats_pv, info.degats_poise, self)

func _terminer_reussite(royaume_cible: int, joueur: Node3D, chance_finale: float) -> void:
	_en_cours = false
	_basculer_ciel_orage(false)

	if is_instance_valid(joueur):
		_creer_onde_ascension(joueur.global_position)
		if joueur.has_method("secouer_camera"):
			joueur.secouer_camera(0.35, 0.35)

		var degats_onde := 50.0 * royaume_cible
		if joueur.has_node("StatsComponent"):
			var stats := joueur.get_node("StatsComponent") as StatsComponent
			if stats:
				degats_onde = stats.get_degats_attaque(3.5)

		for ennemi in get_tree().get_nodes_in_group("ennemis"):
			if not is_instance_valid(ennemi) or not (ennemi is Node3D):
				continue
			var ennemi_3d := ennemi as Node3D
			var dist : float = joueur.global_position.distance_to(ennemi_3d.global_position)
			if dist <= rayon_onde_ascension and ennemi_3d.has_method("recevoir_degats_info"):
				var info := DamageInfo.creer(
					degats_onde,
					120.0,
					joueur,
					joueur.global_position,
					false,
					royaume_cible,
					SkillData.Element.VENT,
					true,
					true
				)
				ennemi_3d.recevoir_degats_info(info)

	print(">>> PERCÉE RÉUSSIE ! Royaume %d atteint (Chance finale : %.0f%%) !" % [royaume_cible, chance_finale * 100.0])
	EventBus.breakthrough_completed.emit(royaume_cible, chance_finale)

func _terminer_echec(royaume_cible: int, raison: String) -> void:
	_en_cours = false
	_basculer_ciel_orage(false)
	print(">>> ÉCHEC DE LA TRIBULATION (Royaume %d) : %s" % [royaume_cible, raison])
	EventBus.breakthrough_failed.emit(royaume_cible, raison)

func _creer_onde_ascension(pos: Vector3) -> void:
	var sphere_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere_inst.material_override = mat

	add_child(sphere_inst)
	sphere_inst.global_position = pos + Vector3(0.0, 1.0, 0.0)
	sphere_inst.scale = Vector3(0.4, 0.4, 0.4)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(sphere_inst, "scale", Vector3(rayon_onde_ascension, rayon_onde_ascension * 0.6, rayon_onde_ascension), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(sphere_inst.queue_free)

func _basculer_ciel_orage(actif: bool) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return

	var light := racine.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world_env := racine.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sky_mat : ProceduralSkyMaterial = null
	if world_env and world_env.environment and world_env.environment.sky:
		sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial

	if not _env_sauvegarde:
		_env_sauvegarde = true
		if light:
			_lumiere_energie_origine = light.light_energy
			_lumiere_couleur_origine = light.light_color
		if sky_mat:
			_ciel_horizon_origine = sky_mat.sky_horizon_color
			_ciel_top_origine = sky_mat.sky_top_color

	var tw := create_tween().set_parallel(true)
	if actif:
		if light:
			tw.tween_property(light, "light_energy", 0.22, 0.7)
			tw.tween_property(light, "light_color", Color(0.55, 0.45, 0.88), 0.7)
		if sky_mat:
			tw.tween_property(sky_mat, "sky_top_color", Color(0.05, 0.03, 0.13), 0.7)
			tw.tween_property(sky_mat, "sky_horizon_color", Color(0.18, 0.10, 0.30), 0.7)
	else:
		if light:
			tw.tween_property(light, "light_energy", _lumiere_energie_origine, 0.9)
			tw.tween_property(light, "light_color", _lumiere_couleur_origine, 0.9)
		if sky_mat:
			tw.tween_property(sky_mat, "sky_top_color", _ciel_top_origine, 0.9)
			tw.tween_property(sky_mat, "sky_horizon_color", _ciel_horizon_origine, 0.9)
