extends CharacterBody3D

@export_group("Statistiques Mannequin")
@export var pv_max : float = 200.0
@export var poise_max : float = 100.0
@export var delai_regen_poise : float = 2.5   # Secondes sans coup avant que la Poise remonte
@export var vitesse_regen_poise : float = 35.0
@export var duree_brisure_garde : float = 1.8 # Temps d'étourdissement quand la Poise tombe à 0

@onready var label_etat: Label3D = $Label3D
@onready var corps_mesh: MeshInstance3D = $CorpsMesh

var pv_actuels : float = 200.0
var poise_actuelle : float = 100.0
var est_brise : bool = false # État de Stagger (Poise à 0)
var temps_depuis_dernier_coup : float = 0.0
var gravite : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var materiau_corps : StandardMaterial3D

func _ready() -> void:
	pv_actuels = pv_max
	poise_actuelle = poise_max
	
	# Récupère le matériau pour pouvoir le faire flasher lors d'un impact
	if corps_mesh.material_override is StandardMaterial3D:
		materiau_corps = corps_mesh.material_override
	
	mettre_a_jour_affichage()

func _physics_process(delta: float) -> void:
	# 1. Gravité
	if not is_on_floor():
		velocity.y -= gravite * delta

	# 2. Friction au sol (arrête progressivement le recul après un coup)
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	# 3. Régénération de la Poise hors combat
	temps_depuis_dernier_coup += delta
	if not est_brise and temps_depuis_dernier_coup >= delai_regen_poise and poise_actuelle < poise_max:
		poise_actuelle = min(poise_max, poise_actuelle + vitesse_regen_poise * delta)
		mettre_a_jour_affichage()

	move_and_slide()

# Fonction appelée directement par la HitboxAttaque du Joueur !
func recevoir_degats(degats_pv: float, degats_poise: float, position_attaquant: Vector3) -> void:
	temps_depuis_dernier_coup = 0.0
	
	# Si sa garde est déjà brisée, il subit 50% de dégâts supplémentaires (critique de posture)
	var multiplicateur_critique : float = 1.5 if est_brise else 1.0
	pv_actuels -= degats_pv * multiplicateur_critique
	
	# Calcul de la direction de projection (de l'attaquant vers le mannequin)
	var dir_recul : Vector3 = (global_position - position_attaquant).normalized()
	dir_recul.y = 0.0

	if not est_brise:
		poise_actuelle = max(0.0, poise_actuelle - degats_poise)
		# Petit recul léger tant que la garde tient
		velocity += dir_recul * 3.5
		
		if poise_actuelle <= 0.0:
			declencher_brisure_garde(dir_recul)
		else:
			flash_impact(Color(1.0, 1.0, 1.0)) # Flash blanc
	else:
		# Déjà brisé : recul plus net
		velocity += dir_recul * 6.0
		flash_impact(Color(1.0, 0.85, 0.0)) # Flash doré (coup critique sur garde brisée)

	# Réinitialisation automatique si les PV tombent à 0 (c'est un mannequin de test)
	if pv_actuels <= 0.0:
		print("Mannequin vaincu ! Réinitialisation des PV et de la Poise.")
		pv_actuels = pv_max
		poise_actuelle = poise_max
		est_brise = false

	mettre_a_jour_affichage()

func declencher_brisure_garde(dir_recul: Vector3) -> void:
	est_brise = true
	velocity += dir_recul * 12.0 # Forte projection en arrière !
	print("BRISURE DE GARDE (POISE BROKEN) !")
	
	if materiau_corps:
		materiau_corps.albedo_color = Color(0.95, 0.75, 0.1) # Devient jaune vif
		
	mettre_a_jour_affichage()
	
	await get_tree().create_timer(duree_brisure_garde).timeout
	
	est_brise = false
	poise_actuelle = poise_max
	if materiau_corps:
		materiau_corps.albedo_color = Color(0.75, 0.22, 0.17) # Retour au rouge
	mettre_a_jour_affichage()

func flash_impact(couleur_flash: Color) -> void:
	if not materiau_corps:
		return
	var couleur_origine : Color = Color(0.95, 0.75, 0.1) if est_brise else Color(0.75, 0.22, 0.17)
	materiau_corps.albedo_color = couleur_flash
	await get_tree().create_timer(0.08).timeout
	if materiau_corps:
		materiau_corps.albedo_color = couleur_origine

func mettre_a_jour_affichage() -> void:
	if est_brise:
		label_etat.text = "PV: %.0f | [GARDE BRISÉE !]" % pv_actuels
		label_etat.modulate = Color(1.0, 0.85, 0.0)
	else:
		label_etat.text = "PV: %.0f | Poise: %.0f" % [pv_actuels, poise_actuelle]
		label_etat.modulate = Color(1.0, 1.0, 1.0)
