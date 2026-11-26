class_name EntiteHorsRecit
extends EnnemiBase
## Prototype d'entité endgame (SCP-CN × H.P. Lovecraft) :
## Capable de modeler la réalité et la couche narrative en plein combat (rature de gravité, corruption du HUD, onde axiomatique).

@export_group("Pouvoirs Méta-Narratifs")
@export var intervalle_edit_narratif : float = 6.5
@export var rayon_rature_axiome : float = 9.0

@onready var anneau_cosmique: MeshInstance3D = $AnneauCosmique

var _timer_edit : float = 3.5
var _index_edit : int = 0
var _temps_anim : float = 0.0

func _physics_process(delta: float) -> void:
	_temps_anim += delta
	if is_instance_valid(anneau_cosmique):
		anneau_cosmique.rotation.y += delta * 1.8
		anneau_cosmique.rotation.x = sin(_temps_anim * 1.4) * 0.45

	super._physics_process(delta)

	if etat == Etat.POURSUITE and is_instance_valid(_joueur):
		_timer_edit -= delta
		if _timer_edit <= 0.0:
			_timer_edit = intervalle_edit_narratif
			_executer_edit_narratif()

func _executer_edit_narratif() -> void:
	_index_edit = (_index_edit + 1) % 3
	match _index_edit:
		0:
			_rature_de_gravite()
		1:
			_rature_axiome()
		2:
			_salve_eldritch()

func _rature_de_gravite() -> void:
	EventBus.reality_distortion_triggered.emit(
		"~~[ENTITÉ HORS-RÉCIT] : La gravité de ce paragraphe est révoquée.~~",
		"R0y@um€ ?? : [LOI DE GRAVITÉ EXPURGÉE]",
		3.5
	)
	if is_instance_valid(_joueur) and _joueur is CharacterBody3D:
		var jb := _joueur as CharacterBody3D
		jb.velocity.y = 10.5
		if jb.has_method("secouer_camera"):
			jb.secouer_camera(0.3, 0.35)

func _rature_axiome() -> void:
	_id_action += 1
	var id_local : int = _id_action
	etat = Etat.PREPARATION
	_mettre_a_jour_label("~~RATURE D'AXIOME~~")

	EventBus.reality_distortion_triggered.emit(
		"~~[OBSERVATEUR] : L'axiome de votre défense a été effacé — Esquissez un Dash iFrame !~~",
		"[DONNÉE EXPURGÉE — COUCHE NARRATIVE ALTÉRÉE]",
		3.2
	)

	var racine := get_tree().current_scene
	var tel : MeshInstance3D = null
	if racine:
		tel = _creer_disque_encre(global_position, rayon_rature_axiome, Color(0.08, 0.02, 0.14, 0.65), Color(1.0, 0.8, 0.2, 1.0))
		racine.add_child(tel)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(tel):
		tel.queue_free()
	if not is_inside_tree() or _id_action != id_local or etat != Etat.PREPARATION:
		return

	etat = Etat.ATTAQUE
	if racine:
		var onde := _creer_disque_encre(global_position, rayon_rature_axiome, Color(1.0, 0.82, 0.2, 0.85), Color(1.0, 0.85, 0.25, 1.0))
		racine.add_child(onde)
		onde.scale = Vector3(0.2, 1.0, 0.2)
		var tw := onde.create_tween().set_parallel(true)
		tw.tween_property(onde, "scale", Vector3(1.15, 1.0, 1.15), 0.35)
		tw.tween_property(onde.material_override, "albedo_color:a", 0.0, 0.35)
		tw.chain().tween_callback(onde.queue_free)

	if is_instance_valid(_joueur):
		var dist_h : float = _distance_horizontale(global_position, _joueur.global_position)
		var diff_y : float = absf(_joueur.global_position.y - global_position.y)
		if dist_h <= rayon_rature_axiome and diff_y < 3.5:
			var info := DamageInfo.creer(
				degats_pv * 1.5,
				degats_poise * 1.5,
				self,
				global_position,
				false,
				10,
				SkillData.Element.NARRATIF,
				true, # Imblocable : nécessite Dash iFrames ou altitude (Vol sur Épée) !
				true
			)
			if _joueur.has_method("recevoir_degats_info"):
				_joueur.recevoir_degats_info(info)

	await get_tree().create_timer(0.35).timeout
	if is_inside_tree() and _id_action == id_local and etat == Etat.ATTAQUE:
		etat = Etat.POURSUITE
		_temps_avant_prochaine_attaque = cooldown_attaque
		_mettre_a_jour_label()

func _salve_eldritch() -> void:
	if not is_instance_valid(_joueur):
		return
	var racine := get_tree().current_scene
	if racine == null:
		return

	EventBus.reality_distortion_triggered.emit(
		"[CONVERGENCE ELDRITCH] — 3 Lignes de Destin tranchées !",
		"[TEXTE CORROMPU — PAGE DÉCHIRÉE]",
		2.2
	)
	var dir_base : Vector3 = _dir_horizontale(global_position, _joueur.global_position)
	if dir_base == Vector3.ZERO:
		dir_base = Vector3.FORWARD

	for angle_deg in [-20.0, 0.0, 20.0]:
		var dir : Vector3 = dir_base.rotated(Vector3.UP, deg_to_rad(angle_deg))
		var info := DamageInfo.creer(
			degats_pv,
			degats_poise,
			self,
			global_position,
			false,
			10,
			SkillData.Element.CAUSAL,
			false
		)
		var proj := ProjectileQi.new()
		racine.add_child(proj)
		proj.initialiser(
			self,
			global_position + Vector3(0.0, 1.5, 0.0) + dir * 1.2,
			dir,
			22.0,
			22.0,
			info,
			Color(1.0, 0.8, 0.2, 1.0),
			SkillData.Element.NARRATIF
		)

func _creer_disque_encre(pos: Vector3, rayon: float, couleur: Color, emission: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon
	cyl.bottom_radius = rayon
	cyl.height = 0.14
	inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 3.0
	inst.material_override = mat
	inst.global_position = Vector3(pos.x, pos.y + 0.1, pos.z)
	return inst
