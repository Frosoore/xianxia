class_name ObjetDestructible
extends StaticBody3D
## Objet destructible lié à l'échelle de puissance du Royaume (GDD §2 & §3).
## Se fissure puis éclate en débris physiques RigidBody3D. Respawn automatique en bac à sable.

@export_group("Destructibilité")
@export var nom_objet : String = "Rocher Spirituel"
@export_range(1, 10) var royaume_requis : int = 1
@export var coups_pour_briser : int = 2
@export var couleur_objet : Color = Color(0.55, 0.42, 0.30, 1.0)
@export var taille_objet : Vector3 = Vector3(1.5, 1.5, 1.5)
@export var respawn_bac_a_sable : bool = true
@export var delai_respawn : float = 7.0

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D
@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var label_info: Label3D = $Label3D

var _coups_restants : int = 2
var _detruit : bool = false
var _materiau : StandardMaterial3D = null
var _pos_mesh_origine : Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("destructibles")
	_coups_restants = maxi(1, coups_pour_briser)

	var box_mesh := BoxMesh.new()
	box_mesh.size = taille_objet
	mesh_inst.mesh = box_mesh
	mesh_inst.position = Vector3(0.0, taille_objet.y * 0.5, 0.0)
	_pos_mesh_origine = mesh_inst.position

	_materiau = StandardMaterial3D.new()
	_materiau.albedo_color = couleur_objet
	_materiau.roughness = 0.75
	mesh_inst.material_override = _materiau

	var box_shape := BoxShape3D.new()
	box_shape.size = taille_objet
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, taille_objet.y * 0.5, 0.0)

	label_info.position = Vector3(0.0, taille_objet.y + 0.55, 0.0)
	_mettre_a_jour_label()

func recevoir_degats(degats_pv: float, degats_poise: float, position_attaquant: Vector3) -> void:
	recevoir_degats_info(DamageInfo.creer(degats_pv, degats_poise, null, position_attaquant, false, 1))

func recevoir_degats_info(info: DamageInfo) -> void:
	if _detruit:
		return

	if info.puissance_destruction < royaume_requis:
		_animer_rebond_insuffisant()
		label_info.text = "%s\n[Royaume %d requis !]" % [nom_objet, royaume_requis]
		label_info.modulate = Color(1.0, 0.38, 0.38)
		print("[DESTRUCTION] %s résiste ! Puissance %d < Royaume %d requis." % [
			nom_objet, info.puissance_destruction, royaume_requis
		])
		return

	# Power Fantasy : si le cultivateur surpasse nettement le palier (+2 Royaumes), destruction instantanée !
	var impact_coups := coups_pour_briser if info.puissance_destruction >= royaume_requis + 2 else 1
	_coups_restants = maxi(0, _coups_restants - impact_coups)

	NumberFormatter.spawn_floating_damage(self, global_position, info.degats_pv, info.est_critique, info.est_counter, false)

	if _coups_restants <= 0:
		_briser(info)
	else:
		_fissurer()

func _animer_rebond_insuffisant() -> void:
	var tw := create_tween()
	tw.tween_property(mesh_inst, "position:x", _pos_mesh_origine.x + 0.08, 0.04)
	tw.tween_property(mesh_inst, "position:x", _pos_mesh_origine.x - 0.08, 0.04)
	tw.tween_property(mesh_inst, "position:x", _pos_mesh_origine.x, 0.04)

func _fissurer() -> void:
	if _materiau:
		_materiau.albedo_color = couleur_objet.darkened(0.32)
	var tw := create_tween()
	tw.tween_property(mesh_inst, "scale", Vector3(1.08, 0.9, 1.08), 0.06)
	tw.tween_property(mesh_inst, "scale", Vector3.ONE, 0.08)
	_mettre_a_jour_label()

func _briser(info: DamageInfo) -> void:
	_detruit = true
	mesh_inst.visible = false
	col_shape.set_deferred("disabled", true)
	label_info.visible = false

	EventBus.destructible_broken.emit(self, global_position, royaume_requis)
	print("[DESTRUCTION] %s pulvérisé !" % nom_objet)

	# Gain d'XP bonus à la destruction
	if is_instance_valid(info.attaquant) and info.attaquant.has_node("StatsComponent"):
		var stats := info.attaquant.get_node("StatsComponent") as StatsComponent
		if stats:
			stats.gagner_xp(35.0 * royaume_requis)

	_generer_debris(info.position_origine)

	if respawn_bac_a_sable:
		await get_tree().create_timer(delai_respawn).timeout
		if not is_inside_tree():
			return
		_reinitialiser()

func _generer_debris(pos_impact: Vector3) -> void:
	var racine := get_tree().current_scene
	if racine == null:
		return

	var dir_base := global_position - pos_impact
	dir_base.y = 0.0
	dir_base = dir_base.normalized() if dir_base.length_squared() > 0.001 else Vector3.FORWARD

	for i in range(7):
		var debris := RigidBody3D.new()
		debris.collision_layer = 0
		debris.collision_mask = 1
		debris.mass = 1.0

		var taille_frag := taille_objet * randf_range(0.22, 0.38)
		var m_inst := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = taille_frag
		m_inst.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = couleur_objet.darkened(randf_range(0.0, 0.25))
		m_inst.material_override = mat
		debris.add_child(m_inst)

		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille_frag
		cs.shape = bs
		debris.add_child(cs)

		racine.add_child(debris)
		debris.global_position = global_position + Vector3(
			randf_range(-taille_objet.x * 0.35, taille_objet.x * 0.35),
			randf_range(0.25, taille_objet.y * 0.85),
			randf_range(-taille_objet.z * 0.35, taille_objet.z * 0.35)
		)

		var impulsion := (dir_base * randf_range(5.0, 12.0)) + Vector3(randf_range(-4.0, 4.0), randf_range(3.5, 8.5), randf_range(-4.0, 4.0))
		debris.apply_central_impulse(impulsion)
		debris.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

		var tw := debris.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(m_inst, "scale", Vector3(0.05, 0.05, 0.05), 0.6)
		tw.tween_callback(debris.queue_free)

func _reinitialiser() -> void:
	_detruit = false
	_coups_restants = maxi(1, coups_pour_briser)
	if _materiau:
		_materiau.albedo_color = couleur_objet
	mesh_inst.scale = Vector3.ONE
	mesh_inst.visible = true
	col_shape.set_deferred("disabled", false)
	label_info.visible = true
	_mettre_a_jour_label()

func _mettre_a_jour_label() -> void:
	if _coups_restants < coups_pour_briser:
		label_info.text = "%s (R%d)\nFissuré (%d/%d)" % [nom_objet, royaume_requis, _coups_restants, coups_pour_briser]
		label_info.modulate = Color(1.0, 0.85, 0.35)
	else:
		label_info.text = "%s\nDestructible R%d+" % [nom_objet, royaume_requis]
		label_info.modulate = Color(0.9, 0.95, 1.0)
