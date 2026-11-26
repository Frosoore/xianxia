class_name SkillsComponent
extends Node
## Gère les techniques de Qi, synergies élémentaires et techniques ontologiques/méta-narratives.
## Cooldowns, Taille des zones/projectiles et Dégâts de Poise scalent avec le Royaume et le Niveau.

var joueur : CharacterBody3D = null
var stats : StatsComponent = null

var skill_lame_qi : SkillData = null
var skill_barriere_qi : SkillData = null
var skill_foudre_ciel : SkillData = null
var skill_coupure_causale : SkillData = null
var skill_rature_narrative : SkillData = null

var _cooldowns_fin_ms : Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var barriere_active : bool = false
var _id_barriere : int = 0

func initialiser(p_joueur: CharacterBody3D, p_stats: StatsComponent) -> void:
	joueur = p_joueur
	stats = p_stats
	skill_lame_qi = _charger_skill("res://resources/skills/lame_de_qi.tres")
	skill_barriere_qi = _charger_skill("res://resources/skills/barriere_de_qi.tres")
	skill_foudre_ciel = _charger_skill("res://resources/skills/eclair_celeste.tres")
	skill_coupure_causale = _charger_skill("res://resources/skills/coupure_causale.tres")
	skill_rature_narrative = _charger_skill("res://resources/skills/rature_narrative.tres")

func _charger_skill(chemin: String) -> SkillData:
	if ResourceLoader.exists(chemin):
		var res := load(chemin)
		if res is SkillData:
			return res
	return null

func get_skill_slot(slot: int) -> SkillData:
	match slot:
		1: return skill_lame_qi
		2: return skill_barriere_qi
		3: return skill_foudre_ciel
		4:
			if stats and stats.royaume_actuel >= 10:
				return skill_rature_narrative
			return skill_coupure_causale
		_: return null

func get_cout_qi_effectif(slot: int) -> float:
	if stats == null:
		return 20.0
	var qi_max := stats.get_qi_max()
	match slot:
		1: return qi_max * 0.14
		2: return qi_max * 0.20
		3: return qi_max * 0.26
		4: return qi_max * (0.50 if stats.royaume_actuel >= 10 else 0.35)
		_: return qi_max * 0.15

func get_cooldown_restant(slot: int) -> float:
	var fin : int = int(_cooldowns_fin_ms.get(slot, 0))
	var reste := (fin - Time.get_ticks_msec()) / 1000.0
	return maxf(0.0, reste)

func tenter_lancer_sort(slot: int) -> bool:
	if joueur == null or stats == null:
		return false
	var skill := get_skill_slot(slot)
	if skill == null:
		return false

	if stats.royaume_actuel < skill.royaume_requis:
		var msg := "%s débloqué au Royaume %d !" % [skill.nom, skill.royaume_requis]
		EventBus.skill_feedback.emit(msg, Color(1.0, 0.55, 0.35))
		print("[SORT VERROUILLÉ] %s" % msg)
		return false

	if get_cooldown_restant(slot) > 0.0:
		return false

	var cout_qi := get_cout_qi_effectif(slot)
	if joueur.qi_actuel < cout_qi:
		EventBus.skill_feedback.emit("Qi insuffisant pour %s !" % skill.nom, Color(0.45, 0.75, 1.0))
		return false

	# Cooldown dynamique scalé sur le Royaume + Niveau + Vélocité !
	var cd_effectif : float = stats.get_cooldown_sort(skill)
	joueur.consommer_qi(cout_qi)
	_cooldowns_fin_ms[slot] = Time.get_ticks_msec() + int(cd_effectif * 1000.0)
	EventBus.skill_cast.emit(slot, skill.nom, cd_effectif)

	match slot:
		1: _executer_lame_de_qi(skill)
		2: _executer_barriere_de_qi(skill)
		3: _executer_foudre_du_ciel(skill)
		4:
			if stats.royaume_actuel >= 10:
				_executer_rature_narrative(skill)
			else:
				_executer_coupure_causale(skill)
	return true

func _executer_lame_de_qi(skill: SkillData) -> void:
	if joueur.has_method("orienter_legerement_vers_ennemi_proche"):
		joueur.orienter_legerement_vers_ennemi_proche()

	var pivot := joueur.get_node("PivotAttaque") as Node3D
	var dir : Vector3 = -pivot.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD

	var taille : float = stats.get_facteur_taille()
	var est_crit : bool = randf() <= stats.get_chance_critique()
	var degats : float = stats.get_degats_sort(skill) * (stats.get_multiplicateur_critique() if est_crit else 1.0)
	var info := DamageInfo.creer(
		degats,
		stats.get_degats_poise_sort(skill),
		joueur,
		joueur.global_position,
		false,
		stats.get_puissance_destruction(skill.bonus_destruction),
		skill.element,
		false,
		est_crit,
		stats.royaume_actuel
	)

	var proj := ProjectileQi.new()
	var racine := get_tree().current_scene
	if racine == null:
		return
	racine.add_child(proj)
	proj.initialiser(
		joueur,
		joueur.global_position + Vector3(0.0, 1.0, 0.0) + dir * (0.9 + taille * 0.25),
		dir,
		skill.vitesse_projectile * (1.0 + (stats.royaume_actuel - 1) * 0.08),
		skill.portee * (0.75 + taille * 0.35),
		info,
		skill.couleur_vfx,
		SkillData.Element.VENT,
		taille
	)

func _executer_barriere_de_qi(skill: SkillData) -> void:
	_id_barriere += 1
	var id_local : int = _id_barriere
	barriere_active = true

	var taille_b : float = clampf(1.0 + (stats.get_facteur_taille() - 1.0) * 0.25, 1.0, 1.9)
	var visuel := joueur.get_node_or_null("BarriereQi") as MeshInstance3D
	if visuel:
		visuel.visible = true
		visuel.scale = Vector3(0.3, 0.3, 0.3)
		var tw := create_tween()
		tw.tween_property(visuel, "scale", Vector3(taille_b, taille_b, taille_b), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var duree_eff : float = skill.duree * (1.0 + (stats.royaume_actuel - 1) * 0.08)
	EventBus.skill_feedback.emit("Barrière de Qi active (%.1fs)" % duree_eff, skill.couleur_vfx)

	await get_tree().create_timer(duree_eff).timeout
	if _id_barriere == id_local:
		desactiver_barriere()

func desactiver_barriere() -> void:
	_id_barriere += 1
	barriere_active = false
	if is_instance_valid(joueur):
		var visuel := joueur.get_node_or_null("BarriereQi") as MeshInstance3D
		if visuel:
			visuel.visible = false

func _executer_foudre_du_ciel(skill: SkillData) -> void:
	var taille : float = stats.get_facteur_taille()
	var rayon_effectif : float = skill.rayon_zone * taille
	_spawn_onde_vfx(joueur.global_position, rayon_effectif, skill.couleur_vfx, 0.35)
	if joueur.has_method("secouer_camera"):
		joueur.secouer_camera(0.22, 0.22)

	var cibles : Array = []
	cibles.append_array(get_tree().get_nodes_in_group("ennemis"))
	cibles.append_array(get_tree().get_nodes_in_group("destructibles"))

	var maintenant := Time.get_ticks_msec()
	for cible in cibles:
		if not is_instance_valid(cible) or not (cible is Node3D):
			continue
		var cible_3d := cible as Node3D
		if not cible_3d.is_in_group("terrain_destructible"):
			var d : Vector3 = cible_3d.global_position - joueur.global_position
			d.y = 0.0
			if d.length() > rayon_effectif:
				continue

		var mult_synergie : float = 1.0
		var mult_poise : float = 1.0
		if cible_3d.has_meta("marque_element") and int(cible_3d.get_meta("marque_expire_ms", 0)) >= maintenant:
			if int(cible_3d.get_meta("marque_element")) == SkillData.Element.VENT:
				mult_synergie = 1.85
				mult_poise = 2.0
				cible_3d.remove_meta("marque_element")
				EventBus.elemental_synergy_triggered.emit("ORAGE DÉCHIRANT (Vent + Éclair x1.85 !)", cible_3d)

		var est_crit : bool = (mult_synergie > 1.0) or (randf() <= stats.get_chance_critique())
		var degats : float = stats.get_degats_sort(skill) * mult_synergie * (stats.get_multiplicateur_critique() if est_crit else 1.0)
		var info := DamageInfo.creer(
			degats,
			stats.get_degats_poise_sort(skill) * mult_poise,
			joueur,
			joueur.global_position,
			false,
			stats.get_puissance_destruction(skill.bonus_destruction),
			skill.element,
			false,
			est_crit,
			stats.royaume_actuel
		)
		if cible_3d.has_method("recevoir_degats_info"):
			cible_3d.recevoir_degats_info(info)

func _executer_coupure_causale(skill: SkillData) -> void:
	var taille : float = stats.get_facteur_taille()
	var portee_eff : float = skill.portee * (0.7 + taille * 0.25)
	EventBus.skill_feedback.emit("COUPURE CAUSALE — Portée %.0fm !" % portee_eff, Color(0.9, 0.35, 1.0))
	if joueur.has_method("secouer_camera"):
		joueur.secouer_camera(0.32, 0.3)

	var cibles : Array = []
	cibles.append_array(get_tree().get_nodes_in_group("ennemis"))
	cibles.append_array(get_tree().get_nodes_in_group("destructibles"))

	for cible in cibles:
		if not is_instance_valid(cible) or not (cible is Node3D):
			continue
		var cible_3d := cible as Node3D
		if not cible_3d.is_in_group("terrain_destructible") and joueur.global_position.distance_to(cible_3d.global_position) > portee_eff:
			continue

		if not cible_3d.is_in_group("terrain_destructible"):
			_spawn_entaille_causale(cible_3d.global_position, Color(0.9, 0.25, 1.0, 1.0), taille * 0.6)
		var degats : float = stats.get_degats_sort(skill) * stats.get_multiplicateur_critique()
		var info := DamageInfo.creer(
			degats,
			stats.get_degats_poise_sort(skill) * 2.0,
			joueur,
			joueur.global_position,
			false,
			10,
			SkillData.Element.CAUSAL,
			true,
			true,
			stats.royaume_actuel
		)
		if cible_3d.has_method("recevoir_degats_info"):
			cible_3d.recevoir_degats_info(info)

func _executer_rature_narrative(skill: SkillData) -> void:
	var taille : float = stats.get_facteur_taille()
	var portee_eff : float = skill.portee * (0.8 + taille * 0.25)
	var texte_meta := "~~[LES LOIS DE CETTE SCÈNE ONT ÉTÉ RATURÉES]~~  —  DÉCRET DE L'AUTEUR"
	EventBus.narrative_decree_triggered.emit(texte_meta, 3.0)

	if joueur.has_method("secouer_camera"):
		joueur.secouer_camera(0.45, 0.55)

	Engine.time_scale = 0.25
	_spawn_onde_vfx(joueur.global_position, 14.0 * (0.6 + taille * 0.25), Color(1.0, 0.85, 0.2, 1.0), 0.75)

	var cibles : Array = []
	cibles.append_array(get_tree().get_nodes_in_group("ennemis"))
	cibles.append_array(get_tree().get_nodes_in_group("destructibles"))

	for cible in cibles:
		if not is_instance_valid(cible) or not (cible is Node3D):
			continue
		var cible_3d := cible as Node3D
		if not cible_3d.is_in_group("terrain_destructible") and joueur.global_position.distance_to(cible_3d.global_position) > portee_eff:
			continue
		if not cible_3d.is_in_group("terrain_destructible"):
			_spawn_entaille_causale(cible_3d.global_position, Color(1.0, 0.88, 0.25, 1.0), taille * 0.75)
		var degats : float = stats.get_degats_sort(skill) * stats.get_multiplicateur_critique() * 2.5
		var info := DamageInfo.creer(
			degats,
			stats.get_degats_poise_sort(skill) * 4.0,
			joueur,
			joueur.global_position,
			false,
			10,
			SkillData.Element.NARRATIF,
			true,
			true,
			stats.royaume_actuel
		)
		if cible_3d.has_method("recevoir_degats_info"):
			cible_3d.recevoir_degats_info(info)

	await get_tree().create_timer(0.45, true, false, true).timeout
	Engine.time_scale = 1.0

func _spawn_onde_vfx(pos: Vector3, rayon: float, couleur: Color, duree: float) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return
	var onde := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.22
	onde.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(couleur.r, couleur.g, couleur.b, 0.8)
	mat.emission_enabled = true
	mat.emission = couleur
	mat.emission_energy_multiplier = 3.5
	onde.material_override = mat

	racine.add_child(onde)
	onde.global_position = Vector3(pos.x, pos.y + 0.15, pos.z)
	onde.scale = Vector3(0.3, 1.0, 0.3)

	var tw := onde.create_tween().set_parallel(true)
	tw.tween_property(onde, "scale", Vector3(rayon, 1.0, rayon), duree).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duree)
	tw.chain().tween_callback(onde.queue_free)

func _spawn_entaille_causale(pos: Vector3, couleur: Color = Color(0.9, 0.25, 1.0, 1.0), echelle: float = 1.0) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return
	var lame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18 * echelle, 4.2 * echelle, 0.18 * echelle)
	lame.mesh = box

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	mat.emission_energy_multiplier = 5.0
	lame.material_override = mat

	racine.add_child(lame)
	lame.global_position = pos + Vector3(0.0, 1.2, 0.0)
	lame.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(0.0, TAU), randf_range(-0.6, 0.6))

	var tw := lame.create_tween().set_parallel(true)
	tw.tween_property(lame, "scale", Vector3(2.2, 1.4, 2.2), 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(lame.queue_free)
