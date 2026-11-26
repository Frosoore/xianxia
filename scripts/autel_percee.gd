extends Node3D
## Autel de Percée : double la vitesse de méditation dans sa zone et guide le joueur pour lancer une Percée.

@onready var zone_autel: Area3D = $ZoneAutel
@onready var cristal_mesh: MeshInstance3D = $CristalMesh
@onready var label_autel: Label3D = $Label3D

var _joueur_present : bool = false
var _percee_prete : bool = false
var _temps : float = 0.0

func _ready() -> void:
	zone_autel.body_entered.connect(_on_body_entered)
	zone_autel.body_exited.connect(_on_body_exited)
	EventBus.player_cultivation_changed.connect(_on_cultivation_changed)
	_mettre_a_jour_label()

func _process(delta: float) -> void:
	_temps += delta
	cristal_mesh.rotation.y += delta * 1.1
	cristal_mesh.position.y = 1.45 + sin(_temps * 2.5) * 0.14

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("joueur"):
		_joueur_present = true
		var cult := body.get_node_or_null("CultivationComponent") as CultivationComponent
		if cult:
			cult.set_dans_zone_autel(true)
		_mettre_a_jour_label()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("joueur"):
		_joueur_present = false
		var cult := body.get_node_or_null("CultivationComponent") as CultivationComponent
		if cult:
			cult.set_dans_zone_autel(false)
		_mettre_a_jour_label()

func _on_cultivation_changed(actuelle: float, requise: float) -> void:
	_percee_prete = requise > 0.0 and actuelle >= requise
	_mettre_a_jour_label()

func _mettre_a_jour_label() -> void:
	if not is_node_ready():
		return
	if _percee_prete and _joueur_present:
		label_autel.text = "Autel de Percée\n[F] DÉCLENCHER LA PERCÉE !"
		label_autel.modulate = Color(1.0, 0.88, 0.25)
	elif _joueur_present:
		label_autel.text = "Autel de Percée (Bonus x2)\n[C] Méditer"
		label_autel.modulate = Color(0.45, 1.0, 0.8)
	else:
		label_autel.text = "Autel de Percée"
		label_autel.modulate = Color(0.85, 0.95, 1.0)
