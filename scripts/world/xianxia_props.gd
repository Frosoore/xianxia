class_name XianxiaProps
extends RefCounted
## Bibliothèque de construction de décors 3D Xianxia stylisés, tous 100 % destructibles (DecorDestructible).
## Permet d'habiller des étages gigantesques (240x240m+) avec Paifang, Pagodes, Bambous, Pins, Lanternes, Ponts et Falaises.

static func _mat(couleur: Color, roughness: float = 0.78, emission_col: Color = Color.BLACK, emission_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = roughness
	if emission_e > 0.0:
		m.emission_enabled = true
		m.emission = emission_col
		m.emission_energy_multiplier = emission_e
	return m

static func _ajouter_boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: StandardMaterial3D, avec_collision: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	if avec_collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		cs.position = pos
		parent.add_child(cs)

static func _ajouter_cylindre(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: StandardMaterial3D, avec_collision: bool = true, segs: int = 10) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	if avec_collision:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = maxf(r_top, r_bot)
		shape.height = h
		cs.shape = shape
		cs.position = pos
		parent.add_child(cs)

static func _creer_decor(nom: String, pos: Vector3, rot_y: float, royaume_req: int, coups: int) -> DecorDestructible:
	var d := DecorDestructible.new()
	d.name = nom.replace(" ", "_")
	d.nom_decor = nom
	d.royaume_requis = royaume_req
	d.coups_pour_briser = coups
	d.position = pos
	d.rotation.y = rot_y
	return d

## Portail traditionnel chinois (Paifang laqué rouge, jade & or)
static func creer_paifang(pos: Vector3, rot_y: float = 0.0, royaume_req: int = 3) -> DecorDestructible:
	var d := _creer_decor("Portail Paifang", pos, rot_y, royaume_req, 3)
	var mat_rouge := _mat(Color(0.62, 0.12, 0.12), 0.6)
	var mat_toit := _mat(Color(0.14, 0.34, 0.28), 0.55)
	var mat_or := _mat(Color(0.92, 0.74, 0.22), 0.35, Color(0.85, 0.65, 0.15), 0.35)
	var mat_pierre := _mat(Color(0.48, 0.50, 0.48), 0.85)

	# Socles & 2 colonnes principales + 2 latérales
	for x in [-4.5, 4.5]:
		_ajouter_boite(d, Vector3(1.1, 0.7, 1.1), Vector3(x, 0.35, 0.0), mat_pierre)
		_ajouter_cylindre(d, 0.36, 0.4, 7.6, Vector3(x, 4.2, 0.0), mat_rouge)
	for x in [-7.2, 7.2]:
		_ajouter_boite(d, Vector3(0.9, 0.5, 0.9), Vector3(x, 0.25, 0.0), mat_pierre)
		_ajouter_cylindre(d, 0.28, 0.32, 5.4, Vector3(x, 3.0, 0.0), mat_rouge)

	# Poutres transversales & plaque dorée
	_ajouter_boite(d, Vector3(15.6, 0.55, 0.65), Vector3(0.0, 5.7, 0.0), mat_rouge, false)
	_ajouter_boite(d, Vector3(10.2, 0.75, 0.8), Vector3(0.0, 7.6, 0.0), mat_rouge, false)
	_ajouter_boite(d, Vector3(3.4, 1.15, 0.35), Vector3(0.0, 6.7, 0.0), mat_or, false)

	# Toits en tuiles de jade (principal + latéraux)
	_ajouter_boite(d, Vector3(11.8, 0.55, 2.2), Vector3(0.0, 8.35, 0.0), mat_toit, false)
	_ajouter_boite(d, Vector3(9.0, 0.45, 1.4), Vector3(0.0, 8.8, 0.0), mat_toit, false)
	_ajouter_boite(d, Vector3(4.2, 0.4, 1.7), Vector3(-6.2, 6.1, 0.0), mat_toit, false)
	_ajouter_boite(d, Vector3(4.2, 0.4, 1.7), Vector3(6.2, 6.1, 0.0), mat_toit, false)
	return d

## Pavillon / Pagode Xianxia à 2 étages
static func creer_pagode(pos: Vector3, rot_y: float = 0.0, royaume_req: int = 4) -> DecorDestructible:
	var d := _creer_decor("Pavillon de Jade", pos, rot_y, royaume_req, 4)
	var mat_pierre := _mat(Color(0.52, 0.54, 0.50), 0.85)
	var mat_bois := _mat(Color(0.55, 0.14, 0.12), 0.65)
	var mat_mur := _mat(Color(0.86, 0.82, 0.74), 0.8)
	var mat_toit := _mat(Color(0.13, 0.36, 0.30), 0.5)
	var mat_or := _mat(Color(0.95, 0.78, 0.25), 0.3, Color(0.95, 0.75, 0.2), 0.4)

	# Base en pierre
	_ajouter_boite(d, Vector3(8.6, 0.9, 8.6), Vector3(0.0, 0.45, 0.0), mat_pierre)
	# Rez-de-chaussée (colonnes + cœur)
	_ajouter_boite(d, Vector3(5.6, 4.0, 5.6), Vector3(0.0, 2.9, 0.0), mat_mur)
	for x in [-3.4, 3.4]:
		for z in [-3.4, 3.4]:
			_ajouter_cylindre(d, 0.25, 0.28, 4.2, Vector3(x, 3.0, z), mat_bois, false)
	# Toit niveau 1
	_ajouter_boite(d, Vector3(10.0, 0.55, 10.0), Vector3(0.0, 5.2, 0.0), mat_toit, false)
	_ajouter_boite(d, Vector3(8.2, 0.5, 8.2), Vector3(0.0, 5.7, 0.0), mat_toit, false)
	# Étage 2
	_ajouter_boite(d, Vector3(4.2, 3.0, 4.2), Vector3(0.0, 7.4, 0.0), mat_mur, false)
	# Toit niveau 2 + flèche dorée
	_ajouter_boite(d, Vector3(7.4, 0.5, 7.4), Vector3(0.0, 9.1, 0.0), mat_toit, false)
	_ajouter_cylindre(d, 0.15, 2.8, 1.8, Vector3(0.0, 10.2, 0.0), mat_toit, false, 6)
	_ajouter_cylindre(d, 0.08, 0.2, 1.2, Vector3(0.0, 11.6, 0.0), mat_or, false, 8)
	return d

## Pin de montagne Xianxia stylisé (destructible dès R2)
static func creer_pin(pos: Vector3, echelle: float = 1.0, royaume_req: int = 2) -> DecorDestructible:
	var d := _creer_decor("Pin Ancien", pos, randf() * TAU, royaume_req, 2)
	var mat_tronc := _mat(Color(0.36, 0.24, 0.16), 0.9)
	var mat_feuille := _mat(Color(0.14, 0.38, 0.24), 0.8)
	var mat_feuille_claire := _mat(Color(0.18, 0.48, 0.30), 0.8)

	_ajouter_cylindre(d, 0.25 * echelle, 0.42 * echelle, 4.8 * echelle, Vector3(0.0, 2.4 * echelle, 0.0), mat_tronc)
	_ajouter_cylindre(d, 0.2 * echelle, 2.6 * echelle, 2.2 * echelle, Vector3(0.0, 4.6 * echelle, 0.0), mat_feuille, false, 7)
	_ajouter_cylindre(d, 0.15 * echelle, 2.0 * echelle, 1.9 * echelle, Vector3(0.0, 6.2 * echelle, 0.0), mat_feuille_claire, false, 7)
	_ajouter_cylindre(d, 0.08 * echelle, 1.3 * echelle, 1.5 * echelle, Vector3(0.0, 7.5 * echelle, 0.0), mat_feuille, false, 7)
	return d

## Bosquet de 3 tiges de bambou géant (tranchable dès R1 !)
static func creer_bambou(pos: Vector3, hauteur: float = 7.0) -> DecorDestructible:
	var d := _creer_decor("Bambou de Jade", pos, randf() * TAU, 1, 1)
	var mat_tige := _mat(Color(0.28, 0.62, 0.30), 0.55)
	var mat_feuille := _mat(Color(0.22, 0.52, 0.26), 0.75)

	var offsets := [Vector2(0.0, 0.0), Vector2(0.55, 0.35), Vector2(-0.45, 0.5)]
	for i in range(offsets.size()):
		var o : Vector2 = offsets[i]
		var h : float = hauteur * (1.0 - i * 0.14)
		_ajouter_cylindre(d, 0.12, 0.15, h, Vector3(o.x, h * 0.5, o.y), mat_tige, i == 0, 6)
		_ajouter_boite(d, Vector3(1.2, 0.16, 0.8), Vector3(o.x + 0.3, h * 0.88, o.y), mat_feuille, false)
	return d

## Lanterne de pierre & jade lumineuse (destructible dès R1)
static func creer_lanterne(pos: Vector3, avec_lumiere: bool = true) -> DecorDestructible:
	var d := _creer_decor("Lanterne de Jade", pos, 0.0, 1, 1)
	var mat_pierre := _mat(Color(0.45, 0.48, 0.46), 0.85)
	var mat_coeur := _mat(Color(0.45, 1.0, 0.82), 0.2, Color(0.35, 1.0, 0.78), 3.2)

	_ajouter_cylindre(d, 0.22, 0.35, 1.8, Vector3(0.0, 0.9, 0.0), mat_pierre)
	_ajouter_boite(d, Vector3(0.55, 0.55, 0.55), Vector3(0.0, 2.05, 0.0), mat_coeur, false)
	_ajouter_cylindre(d, 0.08, 0.68, 0.45, Vector3(0.0, 2.55, 0.0), mat_pierre, false, 6)

	if avec_lumiere:
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 1.0, 0.82)
		light.light_energy = 2.2
		light.omni_range = 10.0
		light.position = Vector3(0.0, 2.1, 0.0)
		d.add_child(light)
	return d

## Rocher / Falaise de montagne Xianxia (destructible R3 ou R5)
static func creer_rocher(pos: Vector3, taille: Vector3, royaume_req: int = 3, couleur: Color = Color(0.32, 0.38, 0.36)) -> DecorDestructible:
	var nom := "Falaise de Jade" if taille.y >= 6.0 else "Rocher de Montagne"
	var d := _creer_decor(nom, pos, randf() * TAU, royaume_req, 3 if royaume_req >= 4 else 2)
	var mat_r := _mat(couleur, 0.9)
	_ajouter_boite(d, taille, Vector3(0.0, taille.y * 0.5, 0.0), mat_r)
	# Crête secondaire pour un relief plus organique
	_ajouter_boite(d, taille * Vector3(0.65, 0.7, 0.7), Vector3(taille.x * 0.22, taille.y * 0.35, taille.z * 0.18), _mat(couleur.darkened(0.12), 0.9), false)
	return d

## Stèle ancienne gravée (destructible R2)
static func creer_stele(pos: Vector3, rot_y: float = 0.0, royaume_req: int = 2) -> DecorDestructible:
	var d := _creer_decor("Stèle Ancienne", pos, rot_y, royaume_req, 2)
	var mat_pierre := _mat(Color(0.38, 0.44, 0.42), 0.82)
	var mat_rune := _mat(Color(0.3, 0.95, 0.85), 0.3, Color(0.25, 0.95, 0.85), 2.2)
	_ajouter_boite(d, Vector3(1.5, 0.45, 1.0), Vector3(0.0, 0.22, 0.0), mat_pierre)
	_ajouter_boite(d, Vector3(1.1, 2.8, 0.42), Vector3(0.0, 1.8, 0.0), mat_pierre)
	_ajouter_boite(d, Vector3(0.5, 1.8, 0.46), Vector3(0.0, 1.85, 0.0), mat_rune, false)
	return d

## Grand pont de pierre traversant la rivière de Jade (destructible R5 !)
static func creer_pont_pierre(pos: Vector3, longueur_z: float = 20.0, largeur_x: float = 10.0) -> DecorDestructible:
	var d := _creer_decor("Pont des Nuages", pos, 0.0, 5, 4)
	var mat_pont := _mat(Color(0.56, 0.58, 0.54), 0.82)
	var mat_garde := _mat(Color(0.62, 0.16, 0.14), 0.65)
	_ajouter_boite(d, Vector3(largeur_x, 0.6, longueur_z), Vector3(0.0, 0.3, 0.0), mat_pont)
	# Rambardes latérales
	for x in [-largeur_x * 0.46, largeur_x * 0.46]:
		_ajouter_boite(d, Vector3(0.45, 1.1, longueur_z), Vector3(x, 1.1, 0.0), mat_garde)
	return d
