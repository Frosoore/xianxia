class_name ProjectileQi
extends Area3D
## Projectile de Qi (ex: Lame de Qi) avec visuel émissif, portée max, marque élémentaire et destruction d'obstacles.

var direction : Vector3 = Vector3.FORWARD
var vitesse : float = 22.0
var portee_max : float = 14.0
var info_degats : DamageInfo = null
var lanceur : Node3D = null
var couleur : Color = Color(0.25, 0.9, 1.0, 1.0)
var marque_elementaire : SkillData.Element = SkillData.Element.VENT
var facteur_echelle : float = 1.0

var _distance_parcourue : float = 0.0
var _cibles_touchees : Array = []

func initialiser(
	p_lanceur: Node3D,
	p_pos_depart: Vector3,
	p_direction: Vector3,
	p_vitesse: float,
	p_portee: float,
	p_info: DamageInfo,
	p_couleur: Color,
	p_marque: SkillData.Element = SkillData.Element.VENT,
	p_echelle: float = 1.0
) -> void:
	lanceur = p_lanceur
	direction = p_direction.normalized()
	vitesse = p_vitesse
	portee_max = p_portee
	info_degats = p_info
	couleur = p_couleur
	marque_elementaire = p_marque
	facteur_echelle = clampf(p_echelle, 0.5, 5.0)
	global_position = p_pos_depart
	scale = Vector3(facteur_echelle, maxf(1.0, facteur_echelle * 0.7), facteur_echelle)
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _ready() -> void:
	monitoring = true
	monitorable = false

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.7, 1.2)
	col.shape = box
	add_child(col)

	# Arc tranchant de Qi lumineux
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 0.14, 0.65)
	mesh_inst.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(couleur.r, couleur.g, couleur.b, 0.9)
	mat.emission_enabled = true
	mat.emission = couleur
	mat.emission_energy_multiplier = 3.5
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var light := OmniLight3D.new()
	light.light_color = couleur
	light.light_energy = 2.5
	light.omni_range = 4.0
	add_child(light)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var deplacement := direction * vitesse * delta
	global_position += deplacement
	_distance_parcourue += deplacement.length()
	if _distance_parcourue >= portee_max:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == lanceur or body in _cibles_touchees:
		return
	_cibles_touchees.append(body)

	# Marque élémentaire temporaire sur les ennemis pour permettre les synergies (ex: Vent + Éclair)
	if body.is_in_group("ennemis"):
		body.set_meta("marque_element", marque_elementaire)
		body.set_meta("marque_expire_ms", Time.get_ticks_msec() + 5000)

	if info_degats != null:
		info_degats.position_origine = global_position
		if body.has_method("recevoir_degats_info"):
			body.recevoir_degats_info(info_degats)
		elif body.has_method("recevoir_degats"):
			body.recevoir_degats(info_degats.degats_pv, info_degats.degats_poise, global_position)

	# S'arrête uniquement sur un mur solide non-destructible ; traverse les ennemis et objets brisés
	if body is StaticBody3D and not body.is_in_group("destructibles"):
		queue_free()
