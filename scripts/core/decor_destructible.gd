class_name DecorDestructible
extends StaticBody3D
## Rend N'IMPORTE QUEL décor 3D (pilier, arche, falaise, rampe, sanctuaire, mur...) entièrement destructible.
## S'adapte automatiquement aux MeshInstance3D et CollisionShape3D déjà présents sur le nœud.

@export_group("Décor Destructible")
@export var nom_decor : String = "Structure de Pierre"
@export_range(1, 10) var royaume_requis : int = 3
@export var coups_pour_briser : int = 2
@export var respawn_bac_a_sable : bool = true
@export var delai_respawn : float = 12.0

var _coups_restants : int = 2
var _detruit : bool = false
var _meshes : Array[MeshInstance3D] = []
var _cols : Array[CollisionShape3D] = []
var _materiaux : Array[StandardMaterial3D] = []
var _couleurs_origine : Array[Color] = []
var _taille_approx : Vector3 = Vector3(2.0, 2.0, 2.0)

func _ready() -> void:
	add_to_group("destructibles")
	_coups_restants = maxi(1, coups_pour_briser)

	var aabb_total := AABB()
	var aabb_init := false

	for enfant in get_children():
		if enfant is MeshInstance3D:
			var m := enfant as MeshInstance3D
			_meshes.append(m)
			if m.mesh:
				var aabb := m.mesh.get_aabb()
				if not aabb_init:
					aabb_total = aabb
					aabb_init = true
				else:
					aabb_total = aabb_total.merge(aabb)

			var mat : StandardMaterial3D = null
			if m.material_override is StandardMaterial3D:
				mat = (m.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.45, 0.48, 0.46, 1.0)
			m.material_override = mat
			_materiaux.append(mat)
			_couleurs_origine.append(mat.albedo_color)
		elif enfant is CollisionShape3D:
			_cols.append(enfant as CollisionShape3D)

	if aabb_init and aabb_total.size.length_squared() > 0.01:
		_taille_approx = aabb_total.size

func recevoir_degats(degats_pv: float, degats_poise: float, position_attaquant: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, position_attaquant, false, 1))

func recevoir_degats_info(info: DamageInfo) -> void:
	if _detruit:
		return

	if info.puissance_destruction < royaume_requis:
		_animer_secousse()
		_spawn_message_flottant("%s : R%d+ requis" % [nom_decor, royaume_requis], Color(0.95, 0.42, 0.38))
		return

	var impact_coups : int = coups_pour_briser if info.puissance_destruction >= royaume_requis + 2 else 1
	_coups_restants = maxi(0, _coups_restants - impact_coups)

	if _coups_restants <= 0:
		_detruire_decor(info)
	else:
		_fissurer_decor()
		_spawn_message_flottant("%s fissuré !" % nom_decor, Color(1.0, 0.85, 0.35))

func _animer_secousse() -> void:
	for m in _meshes:
		var pos_orig := m.position
		var tw := create_tween()
		tw.tween_property(m, "position:x", pos_orig.x + 0.08, 0.04)
		tw.tween_property(m, "position:x", pos_orig.x - 0.08, 0.04)
		tw.tween_property(m, "position:x", pos_orig.x, 0.04)

func _fissurer_decor() -> void:
	for i in range(_materiaux.size()):
		_materiaux[i].albedo_color = _couleurs_origine[i].darkened(0.35)
	_animer_secousse()

func _detruire_decor(info: DamageInfo) -> void:
	_detruit = true
	for m in _meshes:
		m.visible = false
	for c in _cols:
		c.set_deferred("disabled", true)

	EventBus.destructible_broken.emit(self, global_position, royaume_requis)
	_spawn_message_flottant("%s PULVÉRISÉ !" % nom_decor, Color(1.0, 0.88, 0.25))

	if is_instance_valid(info.attaquant) and info.attaquant.has_node("StatsComponent"):
		var s := info.attaquant.get_node("StatsComponent") as StatsComponent
		if s:
			s.gagner_xp(45.0 * royaume_requis)

	_generer_debris(info.position_origine)

	if respawn_bac_a_sable:
		await get_tree().create_timer(delai_respawn).timeout
		if not is_inside_tree():
			return
		_restaurer()

func _generer_debris(pos_impact: Vector3) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return

	var couleur_base : Color = _couleurs_origine[0] if not _couleurs_origine.is_empty() else Color(0.4, 0.45, 0.42, 1.0)
	var dir_base : Vector3 = global_position - pos_impact
	dir_base.y = 0.0
	dir_base = dir_base.normalized() if dir_base.length_squared() > 0.001 else Vector3.FORWARD

	var nb_debris : int = clampi(int(_taille_approx.length() * 1.4), 6, 12)
	var dim_frag : float = clampf(_taille_approx.length() * 0.14, 0.35, 1.35)

	for i in range(nb_debris):
		var debris := RigidBody3D.new()
		debris.collision_layer = 0
		debris.collision_mask = 1
		debris.mass = 1.5

		var taille_f := Vector3(
			dim_frag * randf_range(0.7, 1.3),
			dim_frag * randf_range(0.6, 1.2),
			dim_frag * randf_range(0.7, 1.3)
		)
		var m_inst := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = taille_f
		m_inst.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = couleur_base.darkened(randf_range(0.0, 0.3))
		m_inst.material_override = mat
		debris.add_child(m_inst)

		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille_f
		cs.shape = bs
		debris.add_child(cs)

		racine.add_child(debris)
		var rx := minf(_taille_approx.x * 0.4, 4.0)
		var ry := minf(_taille_approx.y * 0.45, 3.5)
		var rz := minf(_taille_approx.z * 0.4, 4.0)
		debris.global_position = global_position + Vector3(
			randf_range(-rx, rx),
			randf_range(-ry * 0.3, ry),
			randf_range(-rz, rz)
		)

		var impulsion : Vector3 = (dir_base * randf_range(6.0, 15.0)) + Vector3(
			randf_range(-5.0, 5.0),
			randf_range(4.0, 10.0),
			randf_range(-5.0, 5.0)
		)
		debris.apply_central_impulse(impulsion)
		debris.angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))

		var tw := debris.create_tween()
		tw.tween_interval(2.4)
		tw.tween_property(m_inst, "scale", Vector3(0.05, 0.05, 0.05), 0.6)
		tw.tween_callback(debris.queue_free)

func _restaurer() -> void:
	_detruit = false
	_coups_restants = maxi(1, coups_pour_briser)
	for i in range(_materiaux.size()):
		_materiaux[i].albedo_color = _couleurs_origine[i]
	for m in _meshes:
		m.visible = true
	for c in _cols:
		c.set_deferred("disabled", false)

func _spawn_message_flottant(texte: String, couleur: Color) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.008
	lbl.font_size = 42
	lbl.text = texte
	lbl.modulate = couleur
	racine.add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, minf(_taille_approx.y * 0.6 + 1.0, 4.5), 0.0)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.2, 0.95)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(lbl.queue_free)
