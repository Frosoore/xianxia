class_name PortailEtage
extends Node3D
## Portail dimensionnel reliant un Étage au suivant (déverrouillé à la défaite du Seigneur de l'Étage).

@export var etage_actuel : int = 1
@export var etage_destination : int = 2
@export var deverrouille_par_defaut : bool = false

var _deverrouille : bool = false
var _joueur_dans_zone : bool = false
var _anneau : MeshInstance3D = null
var _coeur : MeshInstance3D = null
var _label : Label3D = null
var _lumiere : OmniLight3D = null

func _ready() -> void:
	_deverrouille = deverrouille_par_defaut
	_construire_visuel()
	EventBus.floor_boss_defeated.connect(_on_floor_boss_defeated)
	_actualiser_visuel()

func _construire_visuel() -> void:
	# Socle de pierre circulaire
	var socle := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 3.2
	sc.bottom_radius = 3.6
	sc.height = 0.4
	socle.mesh = sc
	socle.position = Vector3(0.0, 0.2, 0.0)
	var mat_s := StandardMaterial3D.new()
	mat_s.albedo_color = Color(0.24, 0.28, 0.30)
	socle.material_override = mat_s
	add_child(socle)

	# Anneau dimensionnel vertical
	_anneau = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.4
	tm.outer_radius = 2.9
	_anneau.mesh = tm
	_anneau.position = Vector3(0.0, 3.2, 0.0)
	_anneau.rotation.x = PI * 0.5
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.95, 0.78, 0.25)
	mat_a.emission_enabled = true
	mat_a.emission = Color(0.95, 0.78, 0.25)
	mat_a.emission_energy_multiplier = 2.4
	_anneau.material_override = mat_a
	add_child(_anneau)

	# Vortex central
	_coeur = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.35
	cm.bottom_radius = 2.35
	cm.height = 0.12
	_coeur.mesh = cm
	_coeur.position = Vector3(0.0, 3.2, 0.0)
	_coeur.rotation.x = PI * 0.5
	var mat_c := StandardMaterial3D.new()
	mat_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_c.albedo_color = Color(0.3, 0.9, 1.0, 0.55)
	mat_c.emission_enabled = true
	mat_c.emission = Color(0.3, 0.95, 1.0)
	mat_c.emission_energy_multiplier = 3.2
	_coeur.material_override = mat_c
	add_child(_coeur)

	_lumiere = OmniLight3D.new()
	_lumiere.position = Vector3(0.0, 3.2, 0.0)
	_lumiere.omni_range = 14.0
	add_child(_lumiere)

	# Zone d'interaction
	var zone := Area3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.8
	cyl.height = 4.5
	col.shape = cyl
	col.position = Vector3(0.0, 2.25, 0.0)
	zone.add_child(col)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.009
	_label.position = Vector3(0.0, 6.6, 0.0)
	add_child(_label)

func _process(delta: float) -> void:
	if is_instance_valid(_anneau):
		_anneau.rotation.z += delta * (1.8 if _deverrouille else 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if not _joueur_dans_zone:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _deverrouille:
			var next_data := FloorRegistry.get_floor_data(etage_destination)
			EventBus.skill_feedback.emit(
				"ASCENSION VERS %s (%s) — En construction !" % [next_data.get_titre_complet(), next_data.densite_monstres],
				Color(0.4, 1.0, 0.85)
			)
		else:
			EventBus.skill_feedback.emit("Portail scellé ! Vainquez le Seigneur de l'Étage %d." % etage_actuel, Color(1.0, 0.4, 0.4))

func _on_floor_boss_defeated(num_etage: int) -> void:
	if num_etage == etage_actuel and not _deverrouille:
		_deverrouille = true
		_actualiser_visuel()
		EventBus.skill_feedback.emit("LE PORTAIL VERS L'ÉTAGE %d S'EST OUVERT !" % etage_destination, Color(1.0, 0.88, 0.25))

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("joueur"):
		_joueur_dans_zone = true
		_actualiser_visuel()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("joueur"):
		_joueur_dans_zone = false
		_actualiser_visuel()

func _actualiser_visuel() -> void:
	var next_data := FloorRegistry.get_floor_data(etage_destination)
	if _deverrouille:
		_coeur.visible = true
		_lumiere.light_color = Color(0.35, 1.0, 0.85)
		_lumiere.light_energy = 5.0
		_label.text = "PORTAIL DIMENSIONNEL\n→ %s\n%s" % [
			next_data.get_titre_complet(),
			"[E] Franchir le Portail !" if _joueur_dans_zone else "(Déverrouillé)"
		]
		_label.modulate = Color(0.45, 1.0, 0.85)
	else:
		_coeur.visible = false
		_lumiere.light_color = Color(0.9, 0.25, 0.25)
		_lumiere.light_energy = 1.6
		_label.text = "PORTAIL VERS L'ÉTAGE %d (%s)\n[SCELLÉ — Vainquez le Seigneur de l'Étage 1]" % [
			etage_destination, next_data.nom
		]
		_label.modulate = Color(1.0, 0.55, 0.45)
