class_name DamageInfo
extends RefCounted
## Structure unifiée pour transmettre un impact entre joueur, ennemis, sorts et décors destructibles.

var degats_pv : float = 0.0
var degats_poise : float = 0.0
var attaquant : Node3D = null
var position_origine : Vector3 = Vector3.ZERO
var est_counter : bool = false
var est_critique : bool = false
var est_imblocable : bool = false
var royaume_attaquant : int = 1
var puissance_destruction : int = 1
var element : SkillData.Element = SkillData.Element.NEUTRE

static func creer(
	p_degats_pv: float,
	p_degats_poise: float,
	p_attaquant: Node3D = null,
	p_position_origine: Vector3 = Vector3.ZERO,
	p_est_counter: bool = false,
	p_puissance_destruction: int = 1,
	p_element: SkillData.Element = SkillData.Element.NEUTRE,
	p_est_imblocable: bool = false,
	p_est_critique: bool = false,
	p_royaume_attaquant: int = -1
) -> DamageInfo:
	var info := DamageInfo.new()
	info.degats_pv = p_degats_pv
	info.degats_poise = p_degats_poise
	info.attaquant = p_attaquant
	info.position_origine = p_position_origine if p_position_origine != Vector3.ZERO else (
		p_attaquant.global_position if is_instance_valid(p_attaquant) else Vector3.ZERO
	)
	info.est_counter = p_est_counter
	info.est_critique = p_est_critique
	info.puissance_destruction = p_puissance_destruction
	info.royaume_attaquant = p_royaume_attaquant if p_royaume_attaquant > 0 else p_puissance_destruction
	info.element = p_element
	info.est_imblocable = p_est_imblocable
	return info

## Calcule le multiplicateur de Suppression de Royaume sur la Poise :
## - 2+ Royaumes d'écart en dessous -> 0.0 (impossible d'égratigner la poise)
## - 1 Royaume en dessous -> 0.20 (résistance très forte)
## - Royaume égal -> 1.0
## - +1 Royaume au-dessus -> 2.0 ; +2 Royaumes au-dessus -> 5.0 (écrasement)
static func calculer_facteur_suppression_poise(royaume_att: int, royaume_def: int) -> float:
	var ecart : int = royaume_att - royaume_def
	if ecart <= -2:
		return 0.0
	elif ecart == -1:
		return 0.20
	elif ecart == 0:
		return 1.0
	elif ecart == 1:
		return 2.0
	return 5.0
