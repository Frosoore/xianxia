class_name CultivationComponent
extends Node
## Gère la méditation active (progression longue style MMORPG), les prérequis Niveau/Stats et le déclenchement des Percées.

@export_group("Méditation & Cultivation")
@export var vitesse_cultivation_base : float = 14.0 # Volontairement exigeant pour valoriser la progression long terme
@export var multiplicateur_regen_qi_meditation : float = 4.0
@export var multiplicateur_autel : float = 2.0
@export var xp_meditation_par_seconde : float = 8.0

var stats : StatsComponent = null
var cultivation_actuelle : float = 0.0
var est_en_meditation : bool = false
var est_en_tribulation : bool = false
var dans_zone_autel : bool = false

func initialiser(p_stats: StatsComponent) -> void:
	stats = p_stats
	emettre_etat()

func get_cultivation_requise() -> float:
	if stats == null:
		return 400.0
	return stats.get_qi_cultivation_requis()

func emettre_etat() -> void:
	EventBus.player_cultivation_changed.emit(cultivation_actuelle, get_cultivation_requise())

func set_dans_zone_autel(actif: bool) -> void:
	if dans_zone_autel == actif:
		return
	dans_zone_autel = actif
	EventBus.cultivation_bonus_zone_changed.emit(dans_zone_autel)

func demarrer_meditation() -> bool:
	if est_en_meditation or est_en_tribulation:
		return false
	est_en_meditation = true
	EventBus.meditation_toggled.emit(true)
	print("[CULTIVATION] Méditation démarrée%s." % (" (Bonus Autel x2)" if dans_zone_autel else ""))
	return true

func arreter_meditation() -> void:
	if not est_en_meditation:
		return
	est_en_meditation = false
	EventBus.meditation_toggled.emit(false)

func tick_meditation(delta: float) -> void:
	if not est_en_meditation or stats == null:
		return

	# Méditer rapporte aussi un flux continu d'XP (progression MMORPG)
	var facteur_autel := multiplicateur_autel if dans_zone_autel else 1.0
	stats.gagner_xp(xp_meditation_par_seconde * stats.royaume_actuel * facteur_autel * delta)

	var requise := get_cultivation_requise()
	if requise <= 0.0 or stats.royaume_actuel >= 10:
		return
	if cultivation_actuelle >= requise:
		return

	# Progression longue qui scale avec l'Esprit et l'Autel
	var facteur_esprit := 1.0 + stats.points_esprit * 0.015
	var facteur_royaume := pow(1.85, stats.royaume_actuel - 1)
	var gain := vitesse_cultivation_base * facteur_royaume * facteur_esprit * facteur_autel * delta
	cultivation_actuelle = minf(requise, cultivation_actuelle + gain)
	emettre_etat()

	if cultivation_actuelle >= requise:
		var check := stats.verifier_prerequis_percee()
		if check.ok:
			print("[CULTIVATION] Seuil atteint ! Appuyez sur [F] pour affronter la Tribulation du Royaume %d." % (stats.royaume_actuel + 1))
		else:
			print("[CULTIVATION] Cultivation à 100%%, mais prérequis manquant : %s" % check.raison)

func preparer_percee_debug() -> void:
	if stats == null or stats.royaume_actuel >= 10:
		print("[CULTIVATION] Déjà au Royaume maximal (10).")
		return
	var cible := stats.get_realm_data(stats.royaume_actuel + 1)
	stats.definir_niveau_minimum(cible.niveau_requis)
	cultivation_actuelle = get_cultivation_requise()
	emettre_etat()
	print("[BAC À SABLE] Cultivation à 100%% + Niveau %d prêt ! Appuyez sur [F] pour lancer la Percée." % stats.niveau_actuel)

func peut_percer() -> bool:
	if stats == null or est_en_tribulation or stats.royaume_actuel >= 10:
		return false
	var requise := get_cultivation_requise()
	if requise <= 0.0 or cultivation_actuelle < requise:
		return false
	return bool(stats.verifier_prerequis_percee().ok)

func tenter_percee() -> bool:
	if stats == null or est_en_tribulation:
		return false
	if stats.royaume_actuel >= 10:
		print("[CULTIVATION] Sommet déjà atteint : Immortel Véritable.")
		return false

	var requise := get_cultivation_requise()
	if cultivation_actuelle < requise:
		var msg := "Cultivation insuffisante (%s / %s). Méditez [C] ou [T] en bac à sable." % [
			NumberFormatter.format(cultivation_actuelle), NumberFormatter.format(requise)
		]
		print("[PERCÉE BLOQUÉE] %s" % msg)
		EventBus.breakthrough_failed.emit(stats.royaume_actuel + 1, msg)
		return false

	var check := stats.verifier_prerequis_percee()
	if not check.ok:
		print("[PERCÉE BLOQUÉE] %s" % check.raison)
		EventBus.breakthrough_failed.emit(stats.royaume_actuel + 1, check.raison)
		return false

	arreter_meditation()
	est_en_tribulation = true
	var royaume_cible := stats.royaume_actuel + 1
	var nb_eclairs := stats.get_nb_eclairs_tribulation_prochain_royaume()
	print(">>> PERCÉE LANCÉE vers Royaume %d (%d Éclairs | Bonus Luck: +%.0f%%) !" % [
		royaume_cible, nb_eclairs, stats.calculer_bonus_luck_percee() * 100.0
	])
	EventBus.breakthrough_started.emit(royaume_cible, nb_eclairs)
	return true

func finaliser_percee_reussie() -> void:
	est_en_tribulation = false
	cultivation_actuelle = 0.0
	emettre_etat()

func finaliser_percee_echouee(penalite_cultivation: bool = true) -> void:
	est_en_tribulation = false
	if penalite_cultivation:
		cultivation_actuelle *= 0.70
	emettre_etat()

func sur_changement_royaume_manuel() -> void:
	var requise := get_cultivation_requise()
	if requise <= 0.0:
		cultivation_actuelle = 0.0
	else:
		cultivation_actuelle = minf(cultivation_actuelle, requise)
	emettre_etat()
