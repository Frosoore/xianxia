extends Node
## Bus d'évènements global (Autoload : EventBus)
## Centralise les signaux système pour découpler le joueur, le HUD, les ennemis et les percées.

# --- ÉTATS & RESSOURCES DU JOUEUR ---
signal player_pv_changed(actuels: float, maximum: float)
signal player_poise_changed(actuelle: float, maximum: float, est_brise: bool)
signal player_qi_changed(actuel: float, maximum: float)
signal player_endurance_changed(actuelle: float, maximum: float)
signal player_realm_changed(niveau: int, nom_affiche: String)
signal player_level_changed(niveau_perso: int, xp_actuelle: float, xp_requise: float, points_libres: int)
signal player_power_changed(puissance_globale: float)
signal player_cultivation_changed(actuelle: float, requise: float)
signal player_stats_recalculated()

# --- COMBAT & ENTITÉS ---
signal entity_damaged(cible: Node, info: DamageInfo)
signal entity_guard_broken(cible: Node)
signal entity_died(cible: Node, tueur: Node)
signal parry_succeeded(defenseur: Node, attaquant: Node)
signal dash_evade_succeeded(esquiveur: Node, source: Node)
signal counter_executed(attaquant: Node, cible: Node)

# --- CULTIVATION & PERCÉES (Phase 3) ---
signal meditation_toggled(en_meditation: bool)
signal cultivation_bonus_zone_changed(dans_autel: bool)
signal breakthrough_started(royaume_cible: int, nb_eclairs: int)
signal tribulation_lightning_incoming(index_eclair: int, total_eclairs: int, maitrise_skill: float, bonus_luck: float)
signal tribulation_mastery_updated(maitrise_skill: float, bonus_luck: float)
signal breakthrough_completed(nouveau_royaume: int, chance_finale: float)
signal breakthrough_failed(royaume_cible: int, raison: String)

# --- MONDE & DESTRUCTION (Phase 3) ---
signal destructible_broken(objet: Node, position_monde: Vector3, niveau_requis: int)

# --- SORTS, SYNERGIES & VOL SUR ÉPÉE (Lot 4) ---
signal skill_cast(slot: int, nom_sort: String, cooldown: float)
signal skill_feedback(message: String, couleur: Color)
signal elemental_synergy_triggered(nom_synergie: String, cible: Node)
signal sword_flight_toggled(actif: bool)
signal camera_lock_toggled(actif: bool)
signal narrative_decree_triggered(texte_meta: String, duree: float)

# --- BOSS & DISTORSION MÉTA-NARRATIVE (Lot 5) ---
signal boss_encounter_started(nom_boss: String, titre: String, pv: float, pv_max: float, poise: float, poise_max: float)
signal boss_status_updated(pv: float, pv_max: float, poise: float, poise_max: float, est_brise: bool)
signal boss_encounter_ended()
signal reality_distortion_triggered(message_meta: String, texte_hud_corrompu: String, duree: float)

# --- TOUR DES 100 ÉTAGES DIMENSIONNELS ---
signal floor_entered(numero_etage: int, nom_etage: String, sous_titre: String)
signal floor_boss_defeated(numero_etage: int)
signal floor_navigation_updated(pos_boss: Vector3, boss_vivant: bool, pos_autel: Vector3, pos_portail: Vector3)
