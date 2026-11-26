class_name StatsComponent
extends Node
## Calcul dynamique des statistiques MMORPG / Power Fantasy (échelle exponentielle façon Dokkan Battle).
## Poise, Dégâts, PV, Qi, Taille des techniques et Cooldowns scalent avec le Royaume ET le Niveau.

signal stats_recalculees()

@export_group("Royaume & Niveau")
@export_range(1, 10) var royaume_actuel : int = 1
@export_range(1, 9999) var niveau_actuel : int = 1
@export var xp_actuelle : float = 0.0
@export var points_stats_libres : int = 0
@export var points_par_niveau : int = 5

@export_group("Points de Statistiques")
@export_range(0, 99999) var points_velocite : int = 0
@export_range(0, 99999) var points_esprit : int = 0
@export_range(0, 99999) var points_epee : int = 0
@export_range(0, 99999) var points_corps : int = 0
@export_range(0, 99999) var points_chance : int = 0

@export_group("Bases de Combat")
@export var degats_attaque_base : float = 24.0
@export var degats_poise_base : float = 25.0
@export var cout_dash_base : float = 15.0
@export var cooldown_dash_min : float = 0.05

var bonus_passifs : Dictionary = {}
var _realms_cache : Dictionary = {}
var _realm_data_actuel : RealmData = null

func _ready() -> void:
	_charger_realms()
	set_royaume(royaume_actuel, false)

func _charger_realms() -> void:
	_realms_cache.clear()
	for i in range(1, 11):
		var chemin := "res://resources/realms/royaume_%02d.tres" % i
		if ResourceLoader.exists(chemin):
			var res := load(chemin)
			if res is RealmData:
				_realms_cache[i] = res

func get_realm_data(niveau: int = -1) -> RealmData:
	var n := clampi(royaume_actuel if niveau < 0 else niveau, 1, 10)
	if _realms_cache.has(n):
		return _realms_cache[n]
	var fallback := RealmData.new()
	fallback.niveau = n
	fallback.nom = "Royaume %d" % n
	fallback.multiplicateur_degats = pow(8.0, n - 1)
	fallback.poise_max_base = 50.0 * pow(8.0, n - 1)
	fallback.puissance_destruction = n
	fallback.peut_voler_sur_epee = n >= 4
	return fallback

func set_royaume(nouveau_royaume: int, notifier: bool = true) -> void:
	if _realms_cache.is_empty():
		_charger_realms()
	royaume_actuel = clampi(nouveau_royaume, 1, 10)
	_realm_data_actuel = get_realm_data(royaume_actuel)
	if notifier:
		_notifier_changement()

func _notifier_changement() -> void:
	stats_recalculees.emit()
	EventBus.player_stats_recalculated.emit()
	EventBus.player_level_changed.emit(niveau_actuel, xp_actuelle, get_xp_requise_niveau(), points_stats_libres)
	EventBus.player_power_changed.emit(get_puissance_globale())

func get_xp_requise_niveau(niv: int = -1) -> float:
	var n := niveau_actuel if niv < 0 else niv
	return 100.0 * pow(float(n), 1.45)

func gagner_xp(quantite: float, auto_repartir_bac_a_sable: bool = true) -> int:
	if quantite <= 0.0:
		return 0
	xp_actuelle += quantite
	var niveaux_gagnes := 0
	while xp_actuelle >= get_xp_requise_niveau():
		xp_actuelle -= get_xp_requise_niveau()
		niveau_actuel += 1
		niveaux_gagnes += 1
		if auto_repartir_bac_a_sable:
			_repartir_points_equilibres(points_par_niveau)
		else:
			points_stats_libres += points_par_niveau
	if niveaux_gagnes > 0:
		print("[NIVEAU +%d] Niveau %d atteint ! Puissance : %s | Taille : x%.2f | CD : x%.2f" % [
			niveaux_gagnes, niveau_actuel, NumberFormatter.format(get_puissance_globale()),
			get_facteur_taille(), get_facteur_cooldown()
		])
		_notifier_changement()
	else:
		EventBus.player_level_changed.emit(niveau_actuel, xp_actuelle, get_xp_requise_niveau(), points_stats_libres)
	return niveaux_gagnes

func ajouter_niveaux_debug(nb: int) -> void:
	if nb <= 0:
		return
	niveau_actuel += nb
	_repartir_points_equilibres(nb * points_par_niveau)
	_notifier_changement()
	print("[BAC À SABLE] +%d Niveaux → Niv. %d | Puissance: %s | Taille: x%.2f | CD: x%.2f" % [
		nb, niveau_actuel, NumberFormatter.format(get_puissance_globale()),
		get_facteur_taille(), get_facteur_cooldown()
	])

func definir_niveau_minimum(niv_cible: int) -> void:
	if niveau_actuel < niv_cible:
		ajouter_niveaux_debug(niv_cible - niveau_actuel)

func _repartir_points_equilibres(total: int) -> void:
	var par_stat := total / 5
	var reste := total % 5
	points_velocite += par_stat
	points_esprit += par_stat
	points_epee += par_stat
	points_corps += par_stat
	points_chance += par_stat
	if reste > 0:
		points_epee += reste

func ajouter_bonus_passif(cle: String, valeur: float) -> void:
	bonus_passifs[cle] = float(bonus_passifs.get(cle, 0.0)) + valeur
	_notifier_changement()

func _get_passif(cle: String) -> float:
	return float(bonus_passifs.get(cle, 0.0))

func _realm() -> RealmData:
	if _realm_data_actuel == null:
		_realm_data_actuel = get_realm_data(royaume_actuel)
	return _realm_data_actuel

func get_facteur_niveau() -> float:
	return 1.0 + (niveau_actuel - 1) * 0.045

# --- SCALING TAILLE & COOLDOWNS (ROYAUME + NIVEAU) ---
func get_facteur_taille() -> float:
	# R1 Niv.1 -> 1.0x | R4 Niv.50 -> ~1.9x | R7 Niv.220 -> ~3.1x | R10 Niv.600 -> ~4.5x
	var apport_royaume := (royaume_actuel - 1) * 0.26
	var apport_niveau := minf(1.25, (niveau_actuel - 1) * 0.0022)
	return clampf(1.0 + apport_royaume + apport_niveau + _get_passif("taille_mult"), 1.0, 4.6)

func get_facteur_cooldown() -> float:
	# Réduit les cooldowns avec le Royaume, le Niveau et la Vélocité (plancher 0.18x)
	var red_royaume := (royaume_actuel - 1) * 0.065
	var red_niveau := minf(0.24, (niveau_actuel - 1) * 0.00045)
	var red_vel := minf(0.18, points_velocite * 0.0015)
	return clampf(1.0 - red_royaume - red_niveau - red_vel - _get_passif("reduction_cd"), 0.18, 1.0)

func get_cooldown_sort(skill: SkillData) -> float:
	return maxf(0.25, skill.cooldown * get_facteur_cooldown())

func get_duree_attaque(duree_base: float) -> float:
	# Attaques légèrement plus nerveuses à haut Royaume & Niveau (jusqu'à -42%)
	var facteur := lerpf(1.0, 0.58, clampf(1.0 - get_facteur_cooldown(), 0.0, 1.0))
	return maxf(0.12, duree_base * facteur)

# --- ACCESSEURS DYNAMIQUES (Échelle Exponentielle Dokkan Battle) ---
func get_nom_royaume_affiche() -> String:
	return _realm().get_nom_affiche()

func get_titre_cosmologique() -> String:
	return _realm().titre_cosmologique

func get_pv_max() -> float:
	var mult_corps := 1.0 + points_corps * 0.025
	return (_realm().pv_max_base * get_facteur_niveau() * mult_corps) + _get_passif("pv_max")

func get_qi_max() -> float:
	var mult_esprit := 1.0 + points_esprit * 0.025
	return (_realm().qi_max_base * get_facteur_niveau() * mult_esprit) + _get_passif("qi_max")

func get_regen_qi() -> float:
	var mult_esprit := 1.0 + points_esprit * 0.02
	return (_realm().regen_qi_base * get_facteur_niveau() * mult_esprit) + _get_passif("regen_qi")

func get_endurance_max() -> float:
	return _realm().endurance_max_base + points_velocite * 4.0 + _get_passif("endurance_max")

func get_regen_endurance() -> float:
	return _realm().regen_endurance_base + points_velocite * 0.45 + _get_passif("regen_endurance")

func get_poise_max() -> float:
	# Poise exponentielle liée au Royaume × Niveau × Corps !
	var mult_corps := 1.0 + points_corps * 0.02
	return (_realm().poise_max_base * get_facteur_niveau() * mult_corps) + _get_passif("poise_max")

func get_regen_poise(vitesse_base: float = 25.0) -> float:
	# Régénère un pourcentage cohérent de la Poise max (toujours ~40% de la Poise/s)
	return maxf(vitesse_base, get_poise_max() * 0.42)

func get_chance_critique() -> float:
	return clampf(0.08 + points_chance * 0.004 + _get_passif("crit_chance"), 0.05, 0.65)

func get_multiplicateur_critique() -> float:
	return 1.75 + points_epee * 0.005 + _get_passif("crit_mult")

func get_degats_attaque(multiplicateur_coup: float = 1.0) -> float:
	var mult_epee := 1.0 + points_epee * 0.03 + _get_passif("degats_mult")
	return degats_attaque_base * _realm().multiplicateur_degats * get_facteur_niveau() * mult_epee * multiplicateur_coup

func get_degats_sort(skill: SkillData) -> float:
	var mult_esprit := 1.0 + points_esprit * 0.035 + _get_passif("degats_mult")
	return skill.degats_pv_base * _realm().multiplicateur_degats * get_facteur_niveau() * mult_esprit

func get_degats_poise(multiplicateur_coup: float = 1.0) -> float:
	# Les dégâts de Poise scalent aussi exponentiellement avec le Royaume × Niveau !
	var mult_epee := 1.0 + points_epee * 0.02
	return degats_poise_base * _realm().multiplicateur_degats * get_facteur_niveau() * mult_epee * multiplicateur_coup

func get_degats_poise_sort(skill: SkillData) -> float:
	var mult_esprit := 1.0 + points_esprit * 0.02
	return skill.degats_poise_base * _realm().multiplicateur_degats * get_facteur_niveau() * mult_esprit

func get_cout_dash() -> float:
	var facteur := maxf(0.0, _realm().facteur_cout_dash - points_velocite * 0.006 - _get_passif("reduction_cout_dash"))
	return cout_dash_base * facteur

func get_cooldown_dash() -> float:
	var red_niveau := minf(0.25, (niveau_actuel - 1) * 0.0005)
	var red_vel := minf(0.55, points_velocite * 0.006 + _get_passif("reduction_cd_dash"))
	var reduction := clampf(red_niveau + red_vel, 0.0, 0.78)
	return maxf(cooldown_dash_min, _realm().cooldown_dash * (1.0 - reduction))

func get_puissance_destruction(bonus_sort: int = 0) -> int:
	return clampi(_realm().puissance_destruction + bonus_sort, 1, 10)

func peut_voler_sur_epee() -> bool:
	return _realm().peut_voler_sur_epee

func get_qi_cultivation_requis() -> float:
	return _realm().qi_cultivation_requis

func get_puissance_globale() -> float:
	return get_pv_max() * 0.6 + get_qi_max() * 0.6 + get_degats_attaque(1.0) * 4.0 + get_poise_max() * 1.5

func verifier_prerequis_percee() -> Dictionary:
	if royaume_actuel >= 10:
		return {"ok": false, "raison": "Royaume maximal (Immortel Véritable) déjà atteint."}
	var cible := get_realm_data(royaume_actuel + 1)
	if niveau_actuel < cible.niveau_requis:
		return {
			"ok": false,
			"raison": "Niveau %d requis pour %s (actuel : Niv. %d)." % [cible.niveau_requis, cible.nom, niveau_actuel]
		}
	var puissance := get_puissance_globale()
	if puissance < cible.puissance_requise:
		return {
			"ok": false,
			"raison": "Puissance %s requise (actuelle : %s)." % [
				NumberFormatter.format(cible.puissance_requise),
				NumberFormatter.format(puissance)
			]
		}
	return {"ok": true, "raison": ""}

func calculer_bonus_luck_percee() -> float:
	var apport_chance := minf(0.18, points_chance * 0.0015)
	return 0.04 + apport_chance

func get_nb_eclairs_tribulation_prochain_royaume() -> int:
	if royaume_actuel >= 10:
		return 0
	return get_realm_data(royaume_actuel + 1).nb_eclairs_tribulation

func get_difficulte_tribulation_prochain_royaume() -> float:
	if royaume_actuel >= 10:
		return 1.0
	return get_realm_data(royaume_actuel + 1).difficulte_tribulation
