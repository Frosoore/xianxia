extends Node3D
## Constructeur de l'Étage 1 : Les Prairies de Jade Brumeux — Dimension étendue 600m × 600m.
## 7 régions distinctes, Route Impériale, Fleuve de Jade (3 ponts), forêts, ruines, Autel, Citadelle Nord et Portail Étage 2.

const SCENE_DISCIPLE : PackedScene = preload("res://scenes/enemies/disciple_melee.tscn")
const SCENE_DISTANCE : PackedScene = preload("res://scenes/enemies/cultivateur_distance.tscn")
const SCENE_BRUTE : PackedScene = preload("res://scenes/enemies/brute_poise.tscn")
const SCENE_BOSS : PackedScene = preload("res://scenes/enemies/boss_gardien.tscn")

const TAILLE_MONDE : float = 600.0
const DEMI_MONDE : float = 300.0
const Z_RIVIERE : float = 40.0

const POS_BOSS : Vector3 = Vector3(0.0, 0.55, -235.0)
const POS_AUTEL : Vector3 = Vector3(155.0, 0.25, -55.0)
const POS_PORTAIL : Vector3 = Vector3(0.0, 0.25, -268.0)

@onready var conteneur_decors: Node3D = $DecorsGeneres
@onready var conteneur_ennemis: Node3D = $EnnemisGeneres

var _boss_etage : Node = null
var _boss_vivant : bool = true

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101

	_construire_route_imperiale()
	_construire_fleuve_et_ponts()
	_construire_avant_poste()
	_construire_hameau_route()
	_construire_foret_bambous(rng)
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

func _construire_route_imperiale() -> void:
	# Grande chaussée de pierre guidant le joueur du Village Sud (+260) jusqu'à la Citadelle Nord (-215)
	var mat_route := StandardMaterial3D.new()
	mat_route.albedo_color = Color(0.42, 0.44, 0.40)
	mat_route.roughness = 0.88

	var segments := [
		[Vector3(0.0, 0.26, 156.0), Vector3(11.0, 0.08, 206.0)],
		[Vector3(0.0, 0.26, -98.0), Vector3(11.0, 0.08, 246.0)],
		[Vector3(78.0, 0.26, -55.0), Vector3(145.0, 0.08, 7.5)] # Embranchement vers l'Autel à l'Est
	]
	for seg in segments:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = seg[1] as Vector3
		mi.mesh = bm
		mi.position = seg[0] as Vector3
		mi.material_override = mat_route
		conteneur_decors.add_child(mi)

func _construire_fleuve_et_ponts() -> void:
	# Large Fleuve de Jade traversant les 600m d'Ouest en Est
	var riviere := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TAILLE_MONDE - 4.0, 0.18, 28.0)
	riviere.mesh = bm
	riviere.position = Vector3(0.0, 0.28, Z_RIVIERE)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.14, 0.56, 0.54, 0.80)
	mat.roughness = 0.15
	mat.metallic = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.35, 0.36)
	mat.emission_energy_multiplier = 0.45
	riviere.material_override = mat
	conteneur_decors.add_child(riviere)

	# 3 grands ponts destructibles (Centre, Ouest, Est)
	conteneur_decors.add_child(XianxiaProps.creer_pont_pierre(Vector3(0.0, 0.25, Z_RIVIERE), 34.0, 13.0))
	conteneur_decors.add_child(XianxiaProps.creer_pont_pierre(Vector3(-145.0, 0.25, Z_RIVIERE), 32.0, 9.0))
	conteneur_decors.add_child(XianxiaProps.creer_pont_pierre(Vector3(145.0, 0.25, Z_RIVIERE), 32.0, 9.0))

	for x in [-7.5, 7.5]:
		for z in [Z_RIVIERE - 18.0, Z_RIVIERE + 18.0]:
			conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(x, 0.25, z), true))

func _construire_avant_poste() -> void:
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, 228.0), 0.0, 3))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-24.0, 0.25, 246.0), 0.25, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-34.0, 0.25, 226.0), -0.2, 4))

	for z in [242.0, 212.0, 182.0, 152.0]:
		var lum : bool = z >= 212.0
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-9.0, 0.25, z), lum))
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(9.0, 0.25, z), lum))

	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(-13.0, 0.25, 228.0), 0.3, 2))
	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(13.0, 0.25, 228.0), -0.3, 2))
	conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(-42.0, 0.25, 244.0), 1.5, 2))
	conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(38.0, 0.25, 242.0), 1.4, 2))

func _construire_hameau_route() -> void:
	# Relais / ruines à mi-chemin au Sud du fleuve (z = +135)
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, 130.0), 0.0, 3))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(24.0, 0.25, 136.0), -0.35, 4))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(16.0, 0.25, 136.0), true))
	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(-18.0, 0.25, 134.0), 0.4, 2))
	conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(-24.0, 0.25, 126.0), -0.2, 2))

	# Avant-poste au Nord du fleuve (z = -55, carrefour vers l'Autel Est)
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -55.0), 0.0, 3))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(10.0, 0.25, -50.0), true))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(10.0, 0.25, -60.0), false))

func _construire_foret_bambous(rng: RandomNumberGenerator) -> void:
	# 2 Pavillons perdus dans la grande forêt de bambous à l'Ouest
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-125.0, 0.25, 125.0), 0.5, 4))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-116.0, 0.25, 125.0), true))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-190.0, 0.25, -18.0), -0.4, 4))

	# ~90 bosquets de bambous géants (tranchables dès R1 !)
	for i in range(90):
		var px : float = rng.randf_range(-268.0, -35.0)
		var pz : float = rng.randf_range(-45.0, 215.0)
		if absf(pz - Z_RIVIERE) < 19.0:
			continue
		if Vector2(px + 125.0, pz - 125.0).length() < 12.0 or Vector2(px + 190.0, pz + 18.0).length() < 12.0:
			continue
		conteneur_decors.add_child(XianxiaProps.creer_bambou(Vector3(px, 0.25, pz), rng.randf_range(6.5, 11.0)))

	for i in range(16):
		var rx : float = rng.randf_range(-260.0, -45.0)
		var rz : float = rng.randf_range(-40.0, 200.0)
		if absf(rz - Z_RIVIERE) < 20.0:
			continue
		var s : float = rng.randf_range(2.8, 5.8)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(rx, 0.25, rz), Vector3(s, s * 0.85, s), 3))

func _construire_plaine_steles_et_autel(rng: RandomNumberGenerator) -> void:
	# Grand sanctuaire de l'Autel de Percée à l'Est (+155, -55)
	for i in range(8):
		var angle : float = (TAU / 8.0) * i
		var pos_s := POS_AUTEL + Vector3(cos(angle) * 13.0, 0.0, sin(angle) * 13.0)
		conteneur_decors.add_child(XianxiaProps.creer_stele(pos_s, -angle + PI * 0.5, 2))
	conteneur_decors.add_child(XianxiaProps.creer_paifang(POS_AUTEL + Vector3(-24.0, 0.0, 0.0), PI * 0.5, 3))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(POS_AUTEL + Vector3(26.0, 0.0, -18.0), -0.5, 4))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(POS_AUTEL + Vector3(-16.0, 0.0, 8.0), true))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(POS_AUTEL + Vector3(-16.0, 0.0, -8.0), false))

	# Plaine Est parsemée de stèles, pins et gros rochers
	for i in range(42):
		var px : float = rng.randf_range(38.0, 265.0)
		var pz : float = rng.randf_range(-215.0, 210.0)
		if absf(pz - Z_RIVIERE) < 19.0 or absf(pz + 55.0) < 10.0:
			continue
		if Vector2(px - POS_AUTEL.x, pz - POS_AUTEL.z).length() < 26.0:
			continue
		if i % 4 == 0:
			var s : float = rng.randf_range(3.0, 6.2)
			conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(px, 0.25, pz), Vector3(s, s * 0.9, s), 3))
		elif i % 4 == 1:
			conteneur_decors.add_child(XianxiaProps.creer_stele(Vector3(px, 0.25, pz), rng.randf() * TAU, 2))
		else:
			conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(px, 0.25, pz), rng.randf_range(1.1, 1.9), 2))

func _construire_plateau_pins(rng: RandomNumberGenerator) -> void:
	# Grande forêt de pins anciens au Nord-Ouest
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-155.0, 0.25, -165.0), 0.35, 4))
	conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-145.0, 0.25, -165.0), true))

	for i in range(58):
		var px : float = rng.randf_range(-268.0, -45.0)
		var pz : float = rng.randf_range(-255.0, -58.0)
		if Vector2(px + 155.0, pz + 165.0).length() < 14.0:
			continue
		conteneur_decors.add_child(XianxiaProps.creer_pin(Vector3(px, 0.25, pz), rng.randf_range(1.2, 2.2), 2))

	for i in range(14):
		var rx : float = rng.randf_range(-255.0, -55.0)
		var rz : float = rng.randf_range(-245.0, -65.0)
		var s : float = rng.randf_range(4.0, 8.5)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(rx, 0.25, rz), Vector3(s, s * 0.85, s * 0.9), 4))

func _construire_citadelle_nord() -> void:
	# Avenue cérémonielle monumentale menant au Seigneur de l'Étage 1
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -135.0), 0.0, 3))
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -172.0), 0.0, 4))
	conteneur_decors.add_child(XianxiaProps.creer_paifang(Vector3(0.0, 0.25, -205.0), 0.0, 4))

	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-34.0, 0.25, -225.0), 0.35, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(34.0, 0.25, -225.0), -0.35, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(-28.0, 0.25, -165.0), 0.2, 4))
	conteneur_decors.add_child(XianxiaProps.creer_pagode(Vector3(28.0, 0.25, -165.0), -0.2, 4))

	for z in [-125.0, -152.0, -188.0, -212.0]:
		var lum : bool = z <= -188.0
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(-10.0, 0.25, z), lum))
		conteneur_decors.add_child(XianxiaProps.creer_lanterne(Vector3(10.0, 0.25, z), lum))

	# Grande esplanade circulaire de la Citadelle (destructible R5)
	var dalle := DecorDestructible.new()
	dalle.name = "EsplanadeCitadelle"
	dalle.nom_decor = "Esplanade du Premier Ciel"
	dalle.royaume_requis = 5
	dalle.coups_pour_briser = 4
	dalle.position = Vector3(0.0, 0.25, -235.0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 23.0
	cm.bottom_radius = 24.5
	cm.height = 0.5
	mi.mesh = cm
	mi.position = Vector3(0.0, 0.25, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.40, 0.36)
	mi.material_override = mat
	dalle.add_child(mi)
	var cs := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 23.5
	csh.height = 0.5
	cs.shape = csh
	cs.position = Vector3(0.0, 0.25, 0.0)
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
	# Chaîne de montagnes géantes encadrant les 600m (destructibles R5+)
	var bord : float = DEMI_MONDE - 14.0
	var nb_par_cote : int = 16
	for i in range(nb_par_cote):
		var t : float = lerpf(-275.0, 275.0, float(i) / float(nb_par_cote - 1))
		var h1 : float = rng.randf_range(22.0, 42.0)
		var h2 : float = rng.randf_range(22.0, 42.0)
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(t, 0.25, -bord), Vector3(36.0, h1, 18.0), 5, Color(0.18, 0.26, 0.25)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(t, 0.25, bord), Vector3(36.0, h2, 18.0), 5, Color(0.18, 0.26, 0.25)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(-bord, 0.25, t), Vector3(18.0, h1, 36.0), 5, Color(0.18, 0.26, 0.25)))
		conteneur_decors.add_child(XianxiaProps.creer_rocher(Vector3(bord, 0.25, t), Vector3(18.0, h2, 36.0), 5, Color(0.18, 0.26, 0.25)))

func _construire_bordures_invisibles() -> void:
	var bord := StaticBody3D.new()
	bord.name = "LimitesDimension"
	var lim : float = DEMI_MONDE - 4.0
	var configs := [
		[Vector3(0.0, 20.0, -lim), Vector3(TAILLE_MONDE, 45.0, 2.0)],
		[Vector3(0.0, 20.0, lim), Vector3(TAILLE_MONDE, 45.0, 2.0)],
		[Vector3(-lim, 20.0, 0.0), Vector3(2.0, 45.0, TAILLE_MONDE)],
		[Vector3(lim, 20.0, 0.0), Vector3(2.0, 45.0, TAILLE_MONDE)]
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
	# 1. Route Impériale Sud & Hameau (Disciples R1 pour l'échauffement et l'XP)
	for pos in [
		Vector3(-9.0, 0.3, 190.0), Vector3(10.0, 0.3, 175.0),
		Vector3(-12.0, 0.3, 120.0), Vector3(14.0, 0.3, 112.0),
		Vector3(-7.0, 0.3, 78.0), Vector3(8.0, 0.3, 66.0)
	]:
		_spawn_ennemi(SCENE_DISCIPLE, pos)

	# 2. Forêt des Bambous Murmurants (Ouest)
	for pos in [
		Vector3(-78.0, 0.3, 145.0), Vector3(-102.0, 0.3, 130.0),
		Vector3(-135.0, 0.3, 110.0), Vector3(-165.0, 0.3, 138.0),
		Vector3(-95.0, 0.3, 85.0), Vector3(-155.0, 0.3, -10.0),
		Vector3(-200.0, 0.3, -25.0)
	]:
		_spawn_ennemi(SCENE_DISCIPLE, pos)
	for pos in [Vector3(-118.0, 0.3, 120.0), Vector3(-180.0, 0.3, -12.0), Vector3(-140.0, 0.3, 8.0)]:
		_spawn_ennemi(SCENE_DISTANCE, pos)
	_spawn_ennemi(SCENE_BRUTE, Vector3(-195.0, 0.3, -28.0))

	# 3. Plaine des Stèles & Sanctuaire de l'Autel (Est)
	for pos in [Vector3(65.0, 0.3, 95.0), Vector3(110.0, 0.3, 82.0), Vector3(80.0, 0.3, -25.0)]:
		_spawn_ennemi(SCENE_DISCIPLE, pos)
	for pos in [
		Vector3(115.0, 0.3, -45.0), Vector3(135.0, 0.3, -68.0),
		Vector3(172.0, 0.3, -42.0), Vector3(195.0, 0.3, -110.0)
	]:
		_spawn_ennemi(SCENE_DISTANCE, pos)
	_spawn_ennemi(SCENE_BRUTE, Vector3(140.0, 0.3, -55.0))
	_spawn_ennemi(SCENE_BRUTE, Vector3(185.0, 0.3, -125.0))

	# 4. Hauts-Plateaux des Pins Anciens (Nord-Ouest — Zone de chasse/farm)
	for pos in [
		Vector3(-85.0, 0.3, -95.0), Vector3(-135.0, 0.3, -125.0),
		Vector3(-175.0, 0.3, -155.0), Vector3(-210.0, 0.3, -185.0)
	]:
		_spawn_ennemi(SCENE_DISTANCE, pos)
	for pos in [
		Vector3(-110.0, 0.3, -115.0), Vector3(-150.0, 0.3, -150.0),
		Vector3(-185.0, 0.3, -195.0), Vector3(-125.0, 0.3, -205.0)
	]:
		_spawn_ennemi(SCENE_BRUTE, pos)

	# 5. Avenue de la Citadelle Nord (Avant-garde)
	_spawn_ennemi(SCENE_DISTANCE, Vector3(-16.0, 0.3, -115.0))
	_spawn_ennemi(SCENE_DISTANCE, Vector3(16.0, 0.3, -115.0))
	_spawn_ennemi(SCENE_BRUTE, Vector3(0.0, 0.3, -155.0))

	# 6. SEIGNEUR DE L'ÉTAGE 1 (Boss de l'Étage)
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
