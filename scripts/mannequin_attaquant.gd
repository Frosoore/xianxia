extends CharacterBody3D

@export var intervalle_attaque : float = 2.2
@export var degats_coup : float = 25.0
@export var degats_poise_coup : float = 30.0
@export var poise_max : float = 100.0

@onready var corps_mesh: MeshInstance3D = $CorpsMesh
@onready var label_etat: Label3D = $Label3D
@onready var zone_attaque: Area3D = $ZoneAttaqueEnnemi
@onready var visuel_coup: MeshInstance3D = %VisuelCoupEnnemi

var poise_actuelle : float = 100.0
var est_brise : bool = false
var materiau : StandardMaterial3D
var joueur_cible : Node3D = null

func _ready() -> void:
	poise_actuelle = poise_max
	if corps_mesh.material_override is StandardMaterial3D:
		materiau = corps_mesh.material_override
	
	zone_attaque.body_entered.connect(_on_zone_attaque_body_entered)
	boucle_attaque()

func _physics_process(_delta: float) -> void:
	# Cherche le joueur dans la scène pour toujours se tourner vers lui
	if not joueur_cible:
		joueur_cible = get_tree().get_first_node_in_group("joueur")
		if not joueur_cible:
			# Secours : cherche par nom dans la scène parente
			joueur_cible = get_parent().get_node_or_null("Joueur")
			
	if joueur_cible and not est_brise:
		var cible_horizontale := Vector3(joueur_cible.global_position.x, global_position.y, joueur_cible.global_position.z)
		if global_position.distance_to(cible_horizontale) > 0.1:
			look_at(cible_horizontale, Vector3.UP)

func boucle_attaque() -> void:
	while true:
		await get_tree().create_timer(intervalle_attaque).timeout
		if est_brise:
			continue
			
		# 1. Télégraphe (avertissement visuel avant le coup)
		label_etat.text = "PRÉPARE UN COUP..."
		if materiau:
			materiau.albedo_color = Color(1.0, 0.2, 0.6) # Rose vif
		await get_tree().create_timer(0.45).timeout
		
		if est_brise:
			continue

		# 2. Exécution de l'attaque
		label_etat.text = "ATTAQUE !"
		zone_attaque.monitoring = true
		visuel_coup.visible = true
		
		await get_tree().create_timer(0.2).timeout
		
		zone_attaque.monitoring = false
		visuel_coup.visible = false
		if not est_brise:
			label_etat.text = "Poise: %.0f" % poise_actuelle
			if materiau:
				materiau.albedo_color = Color(0.55, 0.26, 0.67)

func _on_zone_attaque_body_entered(body: Node3D) -> void:
	if body != self and body.has_method("recevoir_degats"):
		body.recevoir_degats(degats_coup, degats_poise_coup, self)

# Appelé quand le joueur réussit un Parry Parfait (Sekiro)
func subir_degats_poise_parry(degats_poise: float) -> void:
	if est_brise:
		return
	poise_actuelle = max(0.0, poise_actuelle - degats_poise)
	label_etat.text = "PARÉ ! Poise: %.0f" % poise_actuelle
	if poise_actuelle <= 0.0:
		declencher_brisure()

# Appelé quand le joueur frappe le mannequin (y compris avec le Counter SWBF2)
func recevoir_degats_avances(degats_pv: float, degats_poise: float, _pos: Vector3, est_counter: bool) -> void:
	if est_counter:
		print("Le mannequin a pris un COUNTER SWBF2 imblocable ! (-%.0f PV, -%.0f Poise)" % [degats_pv, degats_poise])
	subir_degats_poise_parry(degats_poise)

func recevoir_degats(_degats_pv: float, degats_poise: float, _pos: Vector3) -> void:
	subir_degats_poise_parry(degats_poise)

func declencher_brisure() -> void:
	est_brise = true
	zone_attaque.monitoring = false
	visuel_coup.visible = false
	label_etat.text = "[GARDE BRISÉE !]"
	if materiau:
		materiau.albedo_color = Color(0.95, 0.75, 0.1)
	await get_tree().create_timer(2.0).timeout
	est_brise = false
	poise_actuelle = poise_max
	label_etat.text = "Poise: %.0f" % poise_actuelle
	if materiau:
		materiau.albedo_color = Color(0.55, 0.26, 0.67)
