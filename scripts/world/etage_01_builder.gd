extends Node3D
## Constructeur de l'Étage 1 : Les Prairies de Jade Brumeux (Dimension gigantesque 240m x 240m).
## 5 régions distinctes, décors 3D Xianxia 100 % destructibles, Rivière de Jade, Boss de l'Étage et Portail vers l'Étage 2.

const SCENE_DISCIPLE : PackedScene = preload("res://scenes/enemies/disciple_melee.tscn")
const SCENE_DISTANCE : PackedScene = preload("res://scenes/enemies/cultivateur_distance.tscn")
const SCENE_BRUTE : PackedScene = preload("res://scenes/enemies/brute_poise.tscn")
const SCENE_BOSS : PackedScene = preload("res://scenes/enemies/boss_gardien.tscn")

const POS_BOSS : Vector3 = Vector3(0.0, 0.55, -88.0)
const POS_AUTEL : Vector3 = Vector3(62.0, 0.25, -24.0)
const POS_PORTAIL : Vector3 = Vector3(0.0, 0.25, -108.0)

@onready var conteneur_decors: Node3D = $DecorsGeneres
@onready var conteneur_ennemis: Node3D = $EnnemisGeneres

var _boss_etage : Node = null
var _boss_vivant : bool = true

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101

	_construire_riviere_et_ponts()
	_construire_avant_poste()
	_construire_bosquet_bambous(rng)
	_construire_plaine_steles_et_autel(rng)
	_construire_plateau_pins(rng)
	_construire_citadelle_nord()
	_construire_falaises_perimetre(rng)
	_construire_bordures_invisibles()
	_peupler_ennemis()

	EventBus.entity_died.connect(_on_entity_died)
	_notifier_entree_etage.call_deferred()

func _notifier_entree_etage() -> void:
	var data := FloorRegistry.get_floor_data(1)
	EventBus.floor_entered.emit(data.numero_etage, data.nom, data.sous_titre)
	EventBus.floor_navigation_updated.emit(POS_BOSS, _boss_vivant, POS_AUTEL, POS_PORTAIL)

func _on_entity_died(cible: Node, _tueur: Node) -> void:
	if cible == _boss_etage and _boss_vivant:
		_boss_vivant = false
		EventBus.floor_boss_defeated.emit(1)
		EventBus.floor_navigation_updated.emit(POS_BOSS, false, POS_AUTEL, POS_PORTAIL)

func _construire_riviere_et_ponts() -> void:
	# Rivière de Jade traversant toute la dimension d'Ouest en Est à z = +20
	var riviere := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(238.0, 0.16, 16.0)
	riviere.mesh = bm
	riviere.position = Vector3(0.0, 0.28, 20.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.14, 0.56, 0.54, 0.78)
	mat.roughness = 0.15
	mat.metallic = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.35, 0.36)
	mat.emission_energy_multiplier = 0.45
	riviere.material_override = mat
	conteneur_decors.add_child(riviere)

	# Pont principal des Nuages (centre) + pont ouest
	conteneur_decors.add_child(XianxiaProps.creer_pont_pierre(Vector3(0.0, 0.25, 20.0), 22.0, 11.0))
	conteneur_decors.add_child(XianxiaProps.creer_pont_pierre(Vector3(-56.0, 0.25, 20.0), 20.0, 7.5))

	# Lanternes aux entrées du Pont principal
	for x in [-6.5, 6.5]:
		for z in [8.5, 31.5]:
			conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(x, 0.25, z), true))

func _construire_avant_poste() -> void:
	# Grand Portail Paifang d'accueil face au spawn
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, 78.0), 0.0, 3))
	# Pavillon / Pagode d'accueil à l'Ouest du spawn
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-20.0, 0.25, 92.0), 0.25, 4))
	# Allée de lanternes menant vers le Nord
	for z in [88.0, 68.0, 52.0]:
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-8.5, 0.25, z), z > 60.0))
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(8.5, 0.25, z), z > 60.0))
	# Stèles & rochers d'ambiance autour de l'avant-poste
	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(-12.0, 0.25, 78.0), 0.3, 2))
	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(12.0, 0.25, 78.0), -0.3, 2))
	conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(-30.0, 0.25, 84.0), 1.35, 2))
	conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(28.0, 0.25, 86.0), 1.25, 2))

func _construire_bosquet_bambous(rng: RandomNumberGenerator) -> void:
	# Pavillon oublié au cœur de la forêt de bambous
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-64.0, 0.25, 48.0), 0.6, 4))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-56.0, 0.25, 46.0), true))

	# 36 bosquets de bambous géants (tous tranchables dès R1 !)
	for i in range(36):
		var px : float = rng.randf_range(-98.0, -22.0)
		var pz : float = rng.randf_range(-10.0, 66.0)
		# Garde la rivière et le pavillon dégagés
		if absf(pz - 20.0) < 11.0:
			continue
		if Vector2(px + 64.0, pz - 48.0).length() < 9.0:
			continue
		conteneur_decors.add_child(XianxiaProps.creer_bambou(Vector3(px, 0.25, pz), rng.randf_range(6.0, 9.5)))

	for i in range(8):
		var rx : float = rng.randf_range(-92.0, -26.0)
		var rz : float = rng.randf_range(-5.0, 62.0)
		if absf(rz - 20.0) < 12.0:
			continue
		var s : float = rng.randf_range(2.0, 4.2)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(rx, 0.25, rz), Vector3(s, s * 0.85, s), 3))

func _construire_plaine_steles_et_autel(rng: RandomNumberGenerator) -> void:
	# Cercle de 6 stèles autour de l'Autel de Percée à (62, 0.25, -24)
	for i in range(6):
		var angle : float = (TAU / 6.0) * i
		var pos_s := POS_AUTEL + Vector3(cos(angle) * 9.5, 0.0, sin(angle) * 9.5)
		conteneur_decors.add_child(XianxiaProps.creer_stele(pos_s, -angle + PI * 0.5, 2))
	conteneur_decors.add_child(XianxiaProps.creer_paifang(POS_AUTEL + Vector3(-16.0, 0.0, 0.0), PI * 0.5, 3))

	# Pins et rochers clairsemés sur la plaine Est
	for i in range(18):
		var px : float = rng.randf_range(24.0, 96.0)
		var pz : float = rng.randf_range(-72.0, 62.0)
		if absf(pz - 20.0) < 11.0 or Vector2(px - POS_AUTEL.x, pz - POS_AUTEL.z).length() < 15.0:
			continue
		if i % 3 == 0:
			var s : float = rng.randf_range(2.4, 4.5)
			conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(px, 0.25, pz), Vector3(s, s, s * 0.9), 3))
		else:
			conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(px, 0.25, pz), rng.randf_range(0.95, 1.55), 2))

func _construire_plateau_pins(rng: RandomNumberGenerator) -> void:
	# Grande forêt de pins anciens au Nord-Ouest
	for i in range(24):
		var px : float = rng.randf_range(-96.0, -24.0)
		var pz : float = rng.randf_range(-88.0, -22.0)
		conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(px, 0.25, pz), rng.randf_range(1.1, 1.85), 2))
	for i in range(6):
		var rx : float = rng.randf_range(-90.0, -28.0)
		var rz : float = rng.randf_range(-82.0, -28.0)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(rx, 0.25, rz), Vector3(4.5, 3.8, 4.0), 3))

func _construire_citadelle_nord() -> void:
	# Double Paifang monumental menant au Sanctuaire du Seigneur de l'Étage 1
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -52.0), 0.0, 3))
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -66.0), 0.0, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-24.0, 0.25, -82.0), 0.3, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(24.0, 0.25, -82.0), -0.3, 4))

	for z in [-44.0, -58.0, -72.0]:
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-9.0, 0.25, z), true))
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(9.0, 0.25, z), true))

	# Esplanade circulaire de la Citadelle (destructible R5)
	var dalle := DecorDestructible.new()
	dalle.name = "EsplanadeCitadelle"
	dalle.nom_decor = "Esplanade du Premier Ciel"
	dalle.royaume_requis = 5
	dalle.coups_pour_briser = 4
	dalle.position = Vector3(0.0, 0.25, -88.0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 15.5
	cm.bottom_radius = 16.5
	cm.height = 0.45
	mi.mesh = cm
	mi.position = Vector3(0.0, 0.22, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.40, 0.36)
	mi.material_override = mat
	dalle.add_child(mi)
	var cs := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 16.0
	csh.height = 0.45
	cs.shape = csh
	cs.position = Vector3(0.0, 0.22, 0.0)
	dalle.add_child(cs)
	conteneur_decors.add_child(dalle)

	# Portail Dimensionnel vers l'Étage 2 derrière le Boss
	var portail := PortailEtage.new()
	portail.name = "PortailEtage2"
	portail.etage_actuel = 1
	portail.etage_destination = 2
	portail.position = POS_PORTAIL
	conteneur_decors.add_child(portail)

func _construire_falaises_perimetre(rng: RandomNumberGenerator) -> void:
	# Chaîne de montagnes / falaises géantes encadrant les 240m de la dimension (destructibles R5+)
	var demi : float = 114.0
	for i in range(9):
		var t : float = lerpf(-104.0, 104.0, float(i) / 8.0)
		var h1 : float = rng.randf_range(10.0, 19.0)
		var h2 : float = rng.randf_range(10.0, 19.0)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(t, 0.25, -demi), Vector3(20.0, h1, 10.0), 5, Color(0.20, 0.28, 0.27)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(t, 0.25, demi), Vector3(20.0, h2, 10.0), 5, Color(0.20, 0.28, 0.27)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(-demi, 0.25, t), Vector3(10.0, h1, 20.0), 5, Color(0.20, 0.28, 0.27)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(demi, 0.25, t), Vector3(10.0, h2, 20.0), 5, Color(0.20, 0.28, 0.27)))

func _construire_bordures_invisibles() -> void:
	var bord := StaticBody3D.new()
	bord.name = "LimitesDimension"
	var configs := [
		[Vector3(0.0, 12.0, -119.0), Vector3(240.0, 26.0, 2.0)],
		[Vector3(0.0, 12.0, 119.0), Vector3(240.0, 26.0, 2.0)],
		[Vector3(-119.0, 12.0, 0.0), Vector3(2.0, 26.0, 240.0)],
		[Vector3(119.0, 12.0, 0.0), Vector3(2.0, 26.0, 240.0)]
	]
	for cfg in configs:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = cfg[1] as Vector3
		cs.shape = bs
		cs.position = cfg[0] as Vector3
		bord.add_child(cs)
	add_child(bord)

func _spawn_ennemi(scene: PackedScene, pos: Vector3) -> Node3D:
	var inst := scene.instantiate() as Node3D
	inst.position = pos
	conteneur_ennemis.add_child(inst)
	return inst

func _peupler_ennemis() -> void:
	# 1. Sentier Sud -> Pont des Nuages (Disciples R1 pour démarrer et monter de niveau)
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(-6.0, 0.3, 56.0))
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(7.0, 0.3, 46.0))
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(0.0, 0.3, 2.0))

	# 2. Bosquet des Bambous Murmurants (Ouest)
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(-42.0, 0.3, 42.0))
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(-52.0, 0.3, 52.0))
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(-72.0, 0.3, 38.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(-58.0, 0.3, 44.0))

	# 3. Plaine des Stèles & Gardiens de l'Autel de Percée (Est)
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(32.0, 0.3, 2.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(46.0, 0.3, -18.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(68.0, 0.3, -12.0))
	_spawn_ennemi(SCENE_BRUTE, Vector3(54.0, 0.3, -30.0))

	# 4. Hauts-Plateaux des Pins (Nord-Ouest — zone de farm XP/Cultivation)
	_spawn_ennemi(SCENE_DISCIPLE, Vector3(-36.0, 0.3, -36.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(-56.0, 0.3, -48.0))
	_spawn_ennemi(SCENE_BRUTE, Vector3(-46.0, 0.3, -64.0))
	_spawn_ennemi(SCENE_BRUTE, Vector3(-68.0, 0.3, -68.0))

	# 5. Avant-garde de la Citadelle Nord
	_spawn_ennemi(SCENE_DISTANCE, Vector3(-12.0, 0.3, -44.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(12.0, 0.3, -44.0))

	# 6. SEIGNEUR DE L'ÉTAGE 1 (configuré AVANT add_child pour initialiser PV & Poise dans _ready)
	var boss := SCENE_BOSS.instantiate() as BossGardien
	boss.position = POS_BOSS
	boss.nom_ennemi = "Seigneur de la Brume d'Émeraude"
	boss.titre_ennemi = "Gardien du Premier Ciel (Étage 1)"
	boss.royaume_ennemi = 2
	boss.pv_max = 18000.0
	boss.poise_max = 1500.0
	boss.degats_pv = 240.0
	boss.degats_poise = 280.0
	boss.recompense_xp = 2200.0
	boss.recompense_cultivation = 1200.0
	conteneur_ennemis.add_child(boss)
	_boss_etage = boss
