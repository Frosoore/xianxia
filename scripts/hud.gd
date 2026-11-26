extends CanvasLayer

@onready var label_royaume: Label = %LabelRoyaume
@onready var label_niveau_puissance: Label = %LabelNiveauPuissance
@onready var barre_pv: ProgressBar = %BarrePV
@onready var barre_poise: ProgressBar = %BarrePoise
@onready var barre_qi: ProgressBar = %BarreQi
@onready var barre_endurance: ProgressBar = %BarreEndurance
@onready var label_cultivation: Label = %LabelCultivation
@onready var barre_cultivation: ProgressBar = %BarreCultivation
@onready var label_banniere: Label = %LabelBanniere

@onready var panneau_boss: PanelContainer = %PanneauBoss
@onready var label_nom_boss: Label = %LabelNomBoss
@onready var barre_pv_boss: ProgressBar = %BarrePVBoss
@onready var barre_poise_boss: ProgressBar = %BarrePoiseBoss

@onready var slot_panels: Dictionary = {
	1: %Slot1, 2: %Slot2, 3: %Slot3, 4: %Slot4
}
@onready var slot_labels: Dictionary = {
	1: %LabelSlot1, 2: %LabelSlot2, 3: %LabelSlot3, 4: %LabelSlot4
}
@onready var slot_vol: PanelContainer = %SlotVol
@onready var label_slot_vol: Label = %LabelSlotVol

var _dans_autel : bool = false
var _en_meditation : bool = false
var _id_banniere : int = 0
var _id_distorsion : int = 0
var _royaume_actuel : int = 1
var _nom_royaume_reel : String = "Royaume 1 : Raffinement Corporel"
var _niveau_perso : int = 1
var _puissance_globale : float = 0.0
var _vol_actif : bool = false
var _cooldowns_fin_ms : Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var _nom_boss_actuel : String = ""

func _ready() -> void:
	EventBus.player_realm_changed.connect(mettre_a_jour_royaume)
	EventBus.player_level_changed.connect(mettre_a_jour_niveau)
	EventBus.player_power_changed.connect(mettre_a_jour_puissance)
	EventBus.player_pv_changed.connect(mettre_a_jour_pv)
	EventBus.player_poise_changed.connect(mettre_a_jour_poise)
	EventBus.player_qi_changed.connect(mettre_a_jour_qi)
	EventBus.player_endurance_changed.connect(mettre_a_jour_endurance)
	EventBus.player_cultivation_changed.connect(mettre_a_jour_cultivation)

	EventBus.meditation_toggled.connect(_on_meditation_toggled)
	EventBus.cultivation_bonus_zone_changed.connect(_on_bonus_zone_changed)
	EventBus.breakthrough_started.connect(_on_breakthrough_started)
	EventBus.tribulation_lightning_incoming.connect(_on_tribulation_lightning)
	EventBus.tribulation_mastery_updated.connect(_on_tribulation_mastery)
	EventBus.breakthrough_completed.connect(_on_breakthrough_completed)
	EventBus.breakthrough_failed.connect(_on_breakthrough_failed)

	EventBus.skill_cast.connect(_on_skill_cast)
	EventBus.skill_feedback.connect(_on_skill_feedback)
	EventBus.elemental_synergy_triggered.connect(_on_elemental_synergy)
	EventBus.sword_flight_toggled.connect(_on_sword_flight_toggled)
	EventBus.narrative_decree_triggered.connect(_on_narrative_decree)

	EventBus.boss_encounter_started.connect(_on_boss_started)
	EventBus.boss_status_updated.connect(_on_boss_updated)
	EventBus.boss_encounter_ended.connect(_on_boss_ended)
	EventBus.reality_distortion_triggered.connect(_on_reality_distortion)

func _process(_delta: float) -> void:
	_rafraichir_barre_sorts()

func mettre_a_jour_royaume(niveau: int, nom_affiche: String) -> void:
	_royaume_actuel = niveau
	_nom_royaume_reel = nom_affiche
	label_royaume.text = nom_affiche
	label_royaume.modulate = Color(1.0, 1.0, 1.0)
	_rafraichir_barre_sorts()

func mettre_a_jour_niveau(niveau_perso: int, _xp_actuelle: float, _xp_requise: float, _points_libres: int) -> void:
	_niveau_perso = niveau_perso
	_rafraichir_niveau_puissance()

func mettre_a_jour_puissance(puissance_globale: float) -> void:
	_puissance_globale = puissance_globale
	_rafraichir_niveau_puissance()

func _rafraichir_niveau_puissance() -> void:
	label_niveau_puissance.text = "Niv. %d  |  Puissance : %s" % [_niveau_perso, NumberFormatter.format(_puissance_globale)]

func mettre_a_jour_pv(actuels: float, maximum: float) -> void:
	barre_pv.max_value = maxf(1.0, maximum)
	barre_pv.value = actuels

func mettre_a_jour_poise(actuelle: float, maximum: float, est_brise: bool) -> void:
	barre_poise.max_value = maxf(1.0, maximum)
	barre_poise.value = actuelle
	barre_poise.modulate = Color(1.0, 0.35, 0.35) if est_brise else Color(1.0, 1.0, 1.0)

func mettre_a_jour_qi(actuel: float, maximum: float) -> void:
	barre_qi.max_value = maxf(1.0, maximum)
	barre_qi.value = actuel

func mettre_a_jour_endurance(actuel: float, maximum: float) -> void:
	barre_endurance.max_value = maxf(1.0, maximum)
	barre_endurance.value = actuel

func mettre_a_jour_cultivation(actuelle: float, requise: float) -> void:
	if requise <= 0.0:
		barre_cultivation.max_value = 1.0
		barre_cultivation.value = 1.0
		barre_cultivation.modulate = Color(1.0, 0.85, 0.25)
		label_cultivation.text = "Cultivation : Sommet Hors-Récit"
		label_cultivation.modulate = Color(1.0, 0.9, 0.35)
		return

	barre_cultivation.max_value = requise
	barre_cultivation.value = actuelle
	if actuelle >= requise:
		barre_cultivation.modulate = Color(1.0, 0.85, 0.25)
		label_cultivation.text = "CULTIVATION PLEINE — [F] Tenter la Percée"
		label_cultivation.modulate = Color(1.0, 0.9, 0.25)
	else:
		barre_cultivation.modulate = Color(1.0, 1.0, 1.0)
		label_cultivation.text = "Cultivation : %s / %s" % [NumberFormatter.format(actuelle), NumberFormatter.format(requise)]
		label_cultivation.modulate = Color(0.9, 0.85, 1.0)

func _rafraichir_barre_sorts() -> void:
	var maintenant := Time.get_ticks_msec()
	var defs : Dictionary = {
		1: {"nom": "[1] Lame Qi", "req": 1},
		2: {"nom": "[2] Barrière", "req": 2},
		3: {"nom": "[3] Foudre", "req": 2},
		4: {"nom": "[4] Rature" if _royaume_actuel >= 10 else "[4] Causal", "req": 10 if _royaume_actuel >= 10 else 8}
	}

	for slot in range(1, 5):
		var panel := slot_panels[slot] as PanelContainer
		var lbl := slot_labels[slot] as Label
		var req : int = defs[slot]["req"]
		var nom : String = defs[slot]["nom"]
		var reste := maxf(0.0, (int(_cooldowns_fin_ms[slot]) - maintenant) / 1000.0)

		if _royaume_actuel < req:
			lbl.text = "%s\n(R%d)" % [nom, req]
			panel.modulate = Color(0.45, 0.45, 0.5, 0.65)
		elif reste > 0.0:
			lbl.text = "%s\n%.1fs" % [nom, reste]
			panel.modulate = Color(0.65, 0.65, 0.75, 0.85)
		else:
			lbl.text = nom
			panel.modulate = Color(1.0, 0.9, 0.35, 1.0) if (slot == 4 and _royaume_actuel >= 10) else Color(1.0, 1.0, 1.0, 1.0)

	if _royaume_actuel < 4:
		label_slot_vol.text = "[V] Vol Épée\n(R4)"
		slot_vol.modulate = Color(0.45, 0.45, 0.5, 0.65)
	elif _vol_actif:
		label_slot_vol.text = "[V] VOL ACTIF"
		slot_vol.modulate = Color(0.4, 1.0, 0.9, 1.0)
	else:
		label_slot_vol.text = "[V] Vol Épée"
		slot_vol.modulate = Color(1.0, 1.0, 1.0, 1.0)

# --- BARRE DE BOSS & DISTORSION MÉTA-NARRATIVE ---
func _on_boss_started(nom_boss: String, titre: String, pv: float, pv_max: float, poise: float, poise_max: float) -> void:
	_nom_boss_actuel = "%s — %s" % [nom_boss, titre] if titre != "" else nom_boss
	panneau_boss.visible = true
	_on_boss_updated(pv, pv_max, poise, poise_max, false)

func _on_boss_updated(pv: float, pv_max: float, poise: float, poise_max: float, est_brise: bool) -> void:
	label_nom_boss.text = "%s  (%s / %s)" % [
		_nom_boss_actuel,
		NumberFormatter.format(pv),
		NumberFormatter.format(pv_max)
	]
	barre_pv_boss.max_value = maxf(1.0, pv_max)
	barre_pv_boss.value = pv
	barre_poise_boss.max_value = maxf(1.0, poise_max)
	barre_poise_boss.value = poise
	barre_poise_boss.modulate = Color(1.0, 0.3, 0.3) if est_brise else Color(1.0, 1.0, 1.0)

func _on_boss_ended() -> void:
	panneau_boss.visible = false

func _on_reality_distortion(message_meta: String, texte_hud_corrompu: String, duree: float) -> void:
	_id_distorsion += 1
	var id_local : int = _id_distorsion
	_afficher_banniere(message_meta, Color(0.95, 0.35, 1.0), duree)
	label_royaume.text = texte_hud_corrompu
	label_royaume.modulate = Color(1.0, 0.25, 0.75)

	await get_tree().create_timer(duree, true, false, true).timeout
	if _id_distorsion == id_local:
		label_royaume.text = _nom_royaume_reel
		label_royaume.modulate = Color(1.0, 1.0, 1.0)

func _afficher_banniere(texte: String, couleur: Color, duree: float = 0.0) -> void:
	_id_banniere += 1
	var id_local := _id_banniere
	label_banniere.text = texte
	label_banniere.modulate = couleur
	label_banniere.visible = true

	if duree > 0.0:
		await get_tree().create_timer(duree, true, false, true).timeout
		if _id_banniere == id_local and not _en_meditation:
			label_banniere.visible = false

func _on_skill_cast(slot: int, _nom_sort: String, cooldown: float) -> void:
	_cooldowns_fin_ms[slot] = Time.get_ticks_msec() + int(cooldown * 1000.0)
	_rafraichir_barre_sorts()

func _on_skill_feedback(message: String, couleur: Color) -> void:
	_afficher_banniere(message, couleur, 2.2)

func _on_elemental_synergy(nom_synergie: String, _cible: Node) -> void:
	_afficher_banniere("SYNERGIE : %s" % nom_synergie, Color(0.55, 0.85, 1.0), 2.5)

func _on_sword_flight_toggled(actif: bool) -> void:
	_vol_actif = actif
	_rafraichir_barre_sorts()
	if actif:
		_afficher_banniere("VOL SUR ÉPÉE — [Espace] Monter | [Shift/Ctrl] Descendre", Color(0.35, 0.95, 1.0), 2.5)

func _on_narrative_decree(texte_meta: String, duree: float) -> void:
	_afficher_banniere(texte_meta, Color(1.0, 0.85, 0.2), duree)

func _on_meditation_toggled(en_meditation: bool) -> void:
	_en_meditation = en_meditation
	if en_meditation:
		var suffixe := " (Bonus Autel x2)" if _dans_autel else ""
		_afficher_banniere("Méditation en cours%s..." % suffixe, Color(0.45, 0.92, 1.0))
	else:
		_id_banniere += 1
		label_banniere.visible = false

func _on_bonus_zone_changed(dans_autel: bool) -> void:
	_dans_autel = dans_autel
	if _en_meditation:
		_on_meditation_toggled(true)

func _on_breakthrough_started(royaume_cible: int, nb_eclairs: int) -> void:
	_afficher_banniere("TRIBULATION CÉLESTE — Royaume %d (%d Éclairs) | Parez & Esquivez !" % [royaume_cible, nb_eclairs], Color(0.85, 0.55, 1.0))

func _on_tribulation_lightning(index_eclair: int, total_eclairs: int, maitrise_skill: float, bonus_luck: float) -> void:
	var taux_estime := clampf(maitrise_skill * 0.80 + bonus_luck, 0.05, 0.99) * 100.0
	_afficher_banniere("ÉCLAIR %d / %d  |  Skill : %.0f%%  +  Luck : +%.0f%%  (≈ %.0f%%)" % [
		index_eclair, total_eclairs, maitrise_skill * 100.0, bonus_luck * 100.0, taux_estime
	], Color(1.0, 0.4, 0.65))

func _on_tribulation_mastery(maitrise_skill: float, bonus_luck: float) -> void:
	var taux_estime := clampf(maitrise_skill * 0.80 + bonus_luck, 0.05, 0.99) * 100.0
	label_banniere.text = "TRIBULATION  |  Skill : %.0f%%  +  Luck : +%.0f%%  →  Chances ≈ %.0f%%" % [
		maitrise_skill * 100.0, bonus_luck * 100.0, taux_estime
	]

func _on_breakthrough_completed(nouveau_royaume: int, chance_finale: float) -> void:
	_afficher_banniere("PERCÉE RÉUSSIE ! Royaume %d atteint (Verdict : %.0f%%) !" % [nouveau_royaume, chance_finale * 100.0], Color(1.0, 0.88, 0.25), 4.0)

func _on_breakthrough_failed(_royaume_cible: int, raison: String) -> void:
	_afficher_banniere("ÉCHEC : %s" % raison, Color(1.0, 0.35, 0.35), 4.5)
