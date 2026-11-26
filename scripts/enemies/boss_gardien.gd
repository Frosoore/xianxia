class_name BossGardien
extends EnnemiBase
## Boss Gardien de la Vallée de la Brume d'Émeraude (Phase 2 à <50% PV + Onde d'Émeraude télégraphée).

@export_group("Patterns Boss")
@export var rayon_onde_boss : float = 6.0
@export var intervalle_onde_spec : float = 6.0

var _phase_2 : bool = false
var _timer_onde : float = 4.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if etat == Etat.POURSUITE and is_instance_valid(_joueur):
		_timer_onde -= delta
		if _timer_onde <= 0.0:
			_timer_onde = intervalle_onde_spec * (0.72 if _phase_2 else 1.0)
			_lancer_onde_emeraude()

func _sur_degats_subis(_info: DamageInfo) -> void:
	if not _phase_2 and pv_actuels > 0.0 and pv_actuels <= pv_max * 0.5:
		_phase_2 = true
		vitesse_deplacement *= 1.3
		cooldown_attaque *= 0.72
		couleur_normale = Color(0.08, 0.72, 0.52, 1.0)
		if _materiau and etat != Etat.STAGGER:
			_materiau.albedo_color = couleur_normale
			_materiau.emission_enabled = true
			_materiau.emission = Color(0.1, 0.85, 0.55, 1.0)
			_materiau.emission_energy_multiplier = 1.6
		EventBus.skill_feedback.emit("PHASE 2 : LE GARDIEN LIBÈRE SON DOMAINE D'ÉMERAUDE !", Color(0.25, 1.0, 0.65))
		print(">>> BOSS PHASE 2 : Gardien de la Brume d'Émeraude enragé !")

func _lancer_onde_emeraude() -> void:
	_id_action += 1
	var id_local : int = _id_action
	etat = Etat.PREPARATION
	_mettre_a_jour_label("ONDE D'ÉMERAUDE !")

	var racine := get_tree().current_scene
	var tel : MeshInstance3D = null
	if racine:
		tel = _creer_anneau_vfx(global_position, rayon_onde_boss, Color(0.15, 0.95, 0.6, 0.45))
		racine.add_child(tel)

	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(tel):
		tel.queue_free()
	if not is_inside_tree() or _id_action != id_local or etat != Etat.PREPARATION:
		return

	etat = Etat.ATTAQUE
	if racine:
		var onde := _creer_anneau_vfx(global_position, rayon_onde_boss, Color(0.2, 1.0, 0.7, 0.85))
		racine.add_child(onde)
		onde.scale = Vector3(0.25, 1.0, 0.25)
		var tw := onde.create_tween().set_parallel(true)
		tw.tween_property(onde, "scale", Vector3(1.15, 1.0, 1.15), 0.35)
		tw.tween_property(onde.material_override, "albedo_color:a", 0.0, 0.35)
		tw.chain().tween_callback(onde.queue_free)

	if is_instance_valid(_joueur):
		var dist : float = _distance_horizontale(global_position, _joueur.global_position)
		if dist <= rayon_onde_boss:
			var info := DamageInfo.creer(
				degats_pv * 1.4,
				degats_poise * 1.35,
				self,
				global_position,
				false,
				royaume_ennemi,
				SkillData.Element.VENT,
				false
			)
			if _joueur.has_method("recevoir_degats_info"):
				_joueur.recevoir_degats_info(info)

	await get_tree().create_timer(0.3).timeout
	if is_inside_tree() and _id_action == id_local and etat == Etat.ATTAQUE:
		etat = Etat.POURSUITE
		_temps_avant_prochaine_attaque = cooldown_attaque
		_mettre_a_jour_label()

func _creer_anneau_vfx(pos: Vector3, rayon: float, couleur: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon
	cyl.bottom_radius = rayon
	cyl.height = 0.12
	inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = Color(couleur.r, couleur.g, couleur.b, 1.0)
	mat.emission_energy_multiplier = 2.6
	inst.material_override = mat
	inst.global_position = Vector3(pos.x, pos.y + 0.1, pos.z)
	return inst
