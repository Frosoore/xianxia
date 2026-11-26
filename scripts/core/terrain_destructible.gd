class_name TerrainDestructible
extends StaticBody3D
## Permet aux attaques et sorts de haut Royaume (R5+) de fracturer et creuser des cratères dynamiques dans le sol
## sans supprimer la collision de la map (évite de tomber dans le vide tout en rendant la dévastation palpable).

@export_range(1, 10) var royaume_requis_cratere : int = 5
@export var max_crateres_actifs : int = 18
@export var cooldown_cratere : float = 0.25

var _crateres : Array[Node3D] = []
var _dernier_cratere_ms : int = 0
var _couleur_sol : Color = Color(0.22, 0.28, 0.25, 1.0)

func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("terrain_destructible")
	for enfant in get_children():
		if enfant is MeshInstance3D:
			var m := enfant as MeshInstance3D
			if m.material_override is StandardMaterial3D:
				_couleur_sol = (m.material_override as StandardMaterial3D).albedo_color
			break

func recevoir_degats(degats_pv: float, degats_poise: float, position_attaquant: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, position_attaquant, false, 1))

func recevoir_degats_info(info: DamageInfo) -> void:
	if info.puissance_destruction < royaume_requis_cratere:
		return

	var maintenant := Time.get_ticks_msec()
	if maintenant - _dernier_cratere_ms < int(cooldown_cratere * 1000.0):
		return
	_dernier_cratere_ms = maintenant

	var pos_impact := info.position_origine
	if is_instance_valid(info.attaquant) and info.attaquant.is_in_group("joueur") and info.element == SkillData.Element.NEUTRE:
		var pivot := info.attaquant.get_node_or_null("PivotAttaque") as Node3D
		if pivot:
			var devant : Vector3 = -pivot.global_transform.basis.z
			devant.y = 0.0
			if devant.length_squared() > 0.001:
				pos_impact = info.attaquant.global_position + devant.normalized() * 2.2

	pos_impact.y = global_position.y + 0.26
	_creuser_cratere(pos_impact, info.puissance_destruction, info.element)

func _creuser_cratere(pos: Vector3, puissance: int, element: SkillData.Element) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return

	var rayon : float = lerpf(1.6, 6.2, clampf((puissance - royaume_requis_cratere) / 5.0, 0.0, 1.0))

	var cratere := Node3D.new()
	racine.add_child(cratere)
	cratere.global_position = pos

	# Fond sombre fracturé du cratère
	var fond := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon
	cyl.bottom_radius = rayon * 1.12
	cyl.height = 0.06
	fond.mesh = cyl

	var mat_fond := StandardMaterial3D.new()
	mat_fond.albedo_color = Color(0.05, 0.05, 0.07, 1.0)
	if element == SkillData.Element.NARRATIF or element == SkillData.Element.CAUSAL:
		mat_fond.emission_enabled = true
		mat_fond.emission = Color(0.65, 0.25, 0.9, 1.0) if element == SkillData.Element.CAUSAL else Color(1.0, 0.82, 0.2, 1.0)
		mat_fond.emission_energy_multiplier = 1.4
	elif element == SkillData.Element.ECLAIR:
		mat_fond.emission_enabled = true
		mat_fond.emission = Color(0.55, 0.45, 1.0, 1.0)
		mat_fond.emission_energy_multiplier = 1.2
	fond.material_override = mat_fond
	cratere.add_child(fond)

	# Couronne de roches soulevées autour du cratère
	var nb_roches := 8
	for i in range(nb_roches):
		var angle : float = (TAU / float(nb_roches)) * i + randf_range(-0.2, 0.2)
		var roche := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.35, 0.75) * (rayon / 2.2)
		bm.size = Vector3(s, s * 0.6, s * 0.85)
		roche.mesh = bm
		var mat_r := StandardMaterial3D.new()
		mat_r.albedo_color = _couleur_sol.darkened(randf_range(0.15, 0.35))
		roche.material_override = mat_r
		roche.position = Vector3(cos(angle) * rayon * 0.95, s * 0.22, sin(angle) * rayon * 0.95)
		roche.rotation = Vector3(randf_range(-0.4, 0.4), angle, randf_range(-0.4, 0.4))
		cratere.add_child(roche)

	# Gerbe de débris physiques projetés en l'air
	for i in range(6):
		var debris := RigidBody3D.new()
		debris.collision_layer = 0
		debris.collision_mask = 1
		var m_d := MeshInstance3D.new()
		var b_d := BoxMesh.new()
		var td := randf_range(0.25, 0.55)
		b_d.size = Vector3(td, td, td)
		m_d.mesh = b_d
		var mat_d := StandardMaterial3D.new()
		mat_d.albedo_color = _couleur_sol.darkened(0.25)
		m_d.material_override = mat_d
		debris.add_child(m_d)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(td, td, td)
		cs.shape = bs
		debris.add_child(cs)
		racine.add_child(debris)
		debris.global_position = pos + Vector3(randf_range(-rayon * 0.5, rayon * 0.5), 0.35, randf_range(-rayon * 0.5, rayon * 0.5))
		debris.apply_central_impulse(Vector3(randf_range(-6.0, 6.0), randf_range(5.0, 11.0), randf_range(-6.0, 6.0)))
		var tw := debris.create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(m_d, "scale", Vector3(0.05, 0.05, 0.05), 0.45)
		tw.tween_callback(debris.queue_free)

	_crateres.append(cratere)
	if _crateres.size() > max_crateres_actifs:
		var ancien := _crateres.pop_front() as Node3D
		if is_instance_valid(ancien):
			ancien.queue_free()

	EventBus.destructible_broken.emit(self, pos, puissance)
