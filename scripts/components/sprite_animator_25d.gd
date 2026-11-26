class_name SpriteAnimator25D
extends Node
## Anime les sprites Pixel Art HD-2D (Sprite3D) avec respiration, rebond de course, squash & stretch,
## inclinaison dynamique, lévitation, impacts flash et afterimages de Dash.

@export var amplitude_respiration : float = 0.032
@export var amplitude_marche_y : float = 0.13
@export var inclinaison_marche_deg : float = 7.5
@export var couleur_afterimage : Color = Color(0.35, 0.92, 1.0, 0.55)
@export var est_flottant_par_defaut : bool = false

var sprite : Sprite3D = null
var _pos_base : Vector3 = Vector3.ZERO
var _scale_base : Vector3 = Vector3.ONE
var _temps : float = 0.0
var _timer_afterimage : float = 0.0
var _timer_coup : float = 0.0
var _timer_impact : float = 0.0
var _en_l_air_precedent : bool = false
var _squash_atterrissage : float = 0.0
var _modulate_normal : Color = Color.WHITE
var _id_flash : int = 0

func initialiser(p_sprite: Sprite3D) -> void:
	sprite = p_sprite
	if is_instance_valid(sprite):
		_pos_base = sprite.position
		_scale_base = sprite.scale
		_modulate_normal = sprite.modulate

func definir_teinte_etat(couleur: Color) -> void:
	_modulate_normal = couleur
	if is_instance_valid(sprite):
		sprite.modulate = couleur

func jouer_coup(est_finisher: bool = false, est_counter: bool = false) -> void:
	_timer_coup = 0.22 if est_finisher else 0.14
	if is_instance_valid(sprite):
		var boost := 1.24 if est_finisher else 1.14
		sprite.scale = Vector3(_scale_base.x * boost, _scale_base.y * 0.88, _scale_base.z)
		if est_counter or est_finisher:
			_flash_couleur(Color(1.2, 1.15, 0.7, 1.0), 0.12)

func jouer_parry() -> void:
	if is_instance_valid(sprite):
		sprite.scale = Vector3(_scale_base.x * 1.15, _scale_base.y * 1.12, _scale_base.z)
		_flash_couleur(Color(1.4, 1.4, 1.4, 1.0), 0.14)

func jouer_impact(couleur: Color = Color(1.6, 1.6, 1.6, 1.0)) -> void:
	_timer_impact = 0.14
	if is_instance_valid(sprite):
		sprite.scale = Vector3(_scale_base.x * 1.18, _scale_base.y * 0.84, _scale_base.z)
		_flash_couleur(couleur, 0.1)

func _flash_couleur(couleur: Color, duree: float) -> void:
	if not is_instance_valid(sprite):
		return
	_id_flash += 1
	var id_local : int = _id_flash
	sprite.modulate = couleur
	await get_tree().create_timer(duree).timeout
	if is_instance_valid(sprite) and _id_flash == id_local:
		sprite.modulate = _modulate_normal

func mettre_a_jour(
	delta: float,
	vitesse_actuelle: Vector3,
	au_sol: bool,
	en_dash: bool = false,
	en_garde: bool = false,
	en_meditation: bool = false,
	en_vol: bool = false,
	est_brise: bool = false
) -> void:
	if not is_instance_valid(sprite):
		return

	_temps += delta
	_timer_coup = maxf(0.0, _timer_coup - delta)
	_timer_impact = maxf(0.0, _timer_impact - delta)
	_squash_atterrissage = maxf(0.0, _squash_atterrissage - delta * 4.5)

	if au_sol and _en_l_air_precedent and not en_vol:
		_squash_atterrissage = 1.0
	_en_l_air_precedent = not au_sol

	var vitesse_h := Vector2(vitesse_actuelle.x, vitesse_actuelle.z).length()
	var dir_x := -1.0 if sprite.flip_h else 1.0

	var cible_pos := _pos_base
	var cible_scale := _scale_base
	var cible_rot_z := 0.0

	if est_brise:
		# Tremblement & recul en état brisé
		cible_pos.x += sin(_temps * 48.0) * 0.08
		cible_rot_z = deg_to_rad(14.0 * dir_x)
		cible_scale = Vector3(_scale_base.x * 1.06, _scale_base.y * 0.9, _scale_base.z)
	elif en_dash:
		cible_rot_z = deg_to_rad(-18.0 * dir_x)
		cible_scale = Vector3(_scale_base.x * 1.18, _scale_base.y * 0.88, _scale_base.z)
		_timer_afterimage -= delta
		if _timer_afterimage <= 0.0:
			_timer_afterimage = 0.045
			_spawn_afterimage()
	elif en_meditation:
		cible_pos.y += 0.32 + sin(_temps * 3.0) * 0.1
		var resp_m := sin(_temps * 2.5) * 0.025
		cible_scale = Vector3(_scale_base.x * (1.0 - resp_m), _scale_base.y * (1.0 + resp_m), _scale_base.z)
	elif en_vol:
		cible_pos.y += 0.18 + sin(_temps * 5.0) * 0.08
		var incl_vol := clampf(-vitesse_actuelle.x * 0.02, -0.28, 0.28)
		cible_rot_z = incl_vol
		if vitesse_h > 10.0:
			_timer_afterimage -= delta
			if _timer_afterimage <= 0.0:
				_timer_afterimage = 0.085
				_spawn_afterimage()
	elif est_flottant_par_defaut:
		cible_pos.y += sin(_temps * 2.8) * 0.22
		cible_rot_z = sin(_temps * 1.6) * 0.05
	elif not au_sol:
		var stretch := clampf(vitesse_actuelle.y * 0.02, -0.1, 0.14)
		cible_scale = Vector3(_scale_base.x * (1.0 - stretch * 0.6), _scale_base.y * (1.0 + stretch), _scale_base.z)
	elif en_garde:
		cible_scale = Vector3(_scale_base.x * 1.08, _scale_base.y * 0.91, _scale_base.z)
		cible_pos.y -= 0.05
	elif vitesse_h > 0.4:
		var freq := clampf(vitesse_h * 2.2, 8.0, 18.0)
		var rebond := absf(sin(_temps * freq)) * amplitude_marche_y
		cible_pos.y += rebond
		cible_rot_z = deg_to_rad(-inclinaison_marche_deg * dir_x) + sin(_temps * freq) * 0.05
		cible_scale = Vector3(_scale_base.x * (1.0 - rebond * 0.15), _scale_base.y * (1.0 + rebond * 0.18), _scale_base.z)
	else:
		# Respiration Idle
		var resp := sin(_temps * 3.2) * amplitude_respiration
		cible_scale = Vector3(_scale_base.x * (1.0 - resp * 0.5), _scale_base.y * (1.0 + resp), _scale_base.z)

	if _squash_atterrissage > 0.01:
		cible_scale.x *= 1.0 + _squash_atterrissage * 0.16
		cible_scale.y *= 1.0 - _squash_atterrissage * 0.16

	if _timer_coup > 0.0:
		cible_rot_z = deg_to_rad(-16.0 * dir_x)
		cible_pos.x += 0.14 * dir_x

	var taux := clampf(delta * 18.0, 0.0, 1.0)
	sprite.position = sprite.position.lerp(cible_pos, taux)
	sprite.scale = sprite.scale.lerp(cible_scale, taux)
	sprite.rotation.z = lerpf(sprite.rotation.z, cible_rot_z, taux)

	# Aligne l'axe Y du Sprite3D sur la caméra active pour ne jamais voir un sprite 2D sur la tranche
	var cam := get_viewport().get_camera_3d()
	if is_instance_valid(cam):
		sprite.global_rotation.y = cam.global_rotation.y

func _spawn_afterimage() -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	var racine := get_tree().current_scene
	if racine == null:
		return

	var fantome := Sprite3D.new()
	fantome.texture = sprite.texture
	fantome.pixel_size = sprite.pixel_size
	fantome.texture_filter = sprite.texture_filter
	fantome.flip_h = sprite.flip_h
	fantome.centered = sprite.centered
	fantome.offset = sprite.offset
	fantome.billboard = sprite.billboard
	fantome.shaded = false
	fantome.modulate = couleur_afterimage

	racine.add_child(fantome)
	fantome.global_transform = sprite.global_transform

	var tw := fantome.create_tween()
	tw.tween_property(fantome, "modulate:a", 0.0, 0.24)
	tw.tween_callback(fantome.queue_free)
