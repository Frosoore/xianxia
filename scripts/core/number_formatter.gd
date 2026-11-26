class_name NumberFormatter
extends RefCounted
## Formate les grands nombres (style Dokkan Battle / MMORPG) et génère des chiffres de dégâts flottants 3D.

static func format(valeur: float) -> String:
	var abs_val := absf(valeur)
	var signe := "-" if valeur < 0.0 else ""
	if abs_val < 1_000.0:
		return "%s%.0f" % [signe, abs_val]
	elif abs_val < 1_000_000.0:
		return "%s%.2fK" % [signe, abs_val / 1_000.0]
	elif abs_val < 1_000_000_000.0:
		return "%s%.2fM" % [signe, abs_val / 1_000_000.0]
	elif abs_val < 1_000_000_000_000.0:
		return "%s%.2fB" % [signe, abs_val / 1_000_000_000.0]
	elif abs_val < 1_000_000_000_000_000.0:
		return "%s%.2fT" % [signe, abs_val / 1_000_000_000_000.0]
	elif abs_val < 1_000_000_000_000_000_000.0:
		return "%s%.2fQa" % [signe, abs_val / 1_000_000_000_000_000.0]
	return "%s%.2e" % [signe, abs_val]

static func spawn_floating_damage(
	hote: Node,
	pos_monde: Vector3,
	degats: float,
	est_crit: bool = false,
	est_counter: bool = false,
	est_brise: bool = false
) -> void:
	if not is_instance_valid(hote) or not hote.is_inside_tree():
		return
	var racine := hote.get_tree().current_scene
	if racine == null:
		return

	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.0085
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0.05, 0.02, 0.08, 0.95)

	var prefixe := ""
	if est_counter:
		prefixe = "COUNTER "
	elif est_crit:
		prefixe = "CRIT "
	elif est_brise:
		prefixe = "BRISÉ "

	var texte := "%s%s" % [prefixe, format(degats)]
	var couleur := Color(1.0, 1.0, 1.0)
	var taille_police := 44

	if degats >= 1_000_000_000.0:
		texte = "★ %s ★" % texte
		couleur = Color(1.0, 0.85, 0.2) # Or Divin / Hors-Récit
		taille_police = 84
	elif degats >= 100_000_000.0:
		couleur = Color(1.0, 0.25, 0.85) # Magenta Cosmique
		taille_police = 74
	elif degats >= 1_000_000.0:
		couleur = Color(1.0, 0.42, 0.15) # Orange Incandescent
		taille_police = 64
	elif degats >= 1_000.0:
		couleur = Color(1.0, 0.9, 0.3) # Jaune Puissant
		taille_police = 54
	elif est_crit or est_counter:
		couleur = Color(1.0, 0.88, 0.25)
		taille_police = 52

	lbl.text = texte
	lbl.font_size = taille_police
	lbl.modulate = couleur

	racine.add_child(lbl)
	var decalage := Vector3(randf_range(-0.45, 0.45), randf_range(1.9, 2.3), randf_range(-0.25, 0.25))
	lbl.global_position = pos_monde + decalage
	lbl.scale = Vector3(0.45, 0.45, 0.45)

	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3(1.25, 1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.35, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tw.chain().tween_callback(lbl.queue_free)
