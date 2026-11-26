class_name FloorRegistry
extends RefCounted
## Registre des 100 Étages Dimensionnels : chaque étage est un monde entier à thème unique.

static func get_floor_data(numero: int) -> FloorData:
	var n : int = clampi(numero, 1, 100)
	var data := FloorData.new()
	data.numero_etage = n
	data.royaume_recommande = clampi(1 + int((n - 1) / 10), 1, 10)
	data.niveau_recommande = maxi(1, int(pow(float(n), 1.35) * 1.15))
	data.taille_dimension = 240.0

	match n:
		1:
			data.nom = "Les Prairies de Jade Brumeux"
			data.sous_titre = "Premier Ciel — Vallée des Portails Rouges"
			data.biome = FloorData.Biome.PRAIRIE_JADE
			data.densite_monstres = "Modérée"
			data.scene_dediee = "res://scenes/floors/etage_01.tscn"
		2:
			data.nom = "La Forêt des Bambous Pourpres"
			data.sous_titre = "Dimension d'Essaim — Sanctuaire des Bêtes"
			data.biome = FloorData.Biome.FORET_BAMBOUS
			data.densite_monstres = "Essaim (Très Élevée)"
			data.couleur_ciel_haut = Color(0.28, 0.14, 0.24, 1.0)
			data.couleur_ciel_horizon = Color(0.68, 0.36, 0.42, 1.0)
			data.couleur_brume = Color(0.55, 0.28, 0.35, 1.0)
			data.couleur_sol = Color(0.24, 0.19, 0.20, 1.0)
		3:
			data.nom = "La Steppe Silencieuse du Vent Blanc"
			data.sous_titre = "Dimension Contemplative — Quasi Déserte"
			data.biome = FloorData.Biome.STEPPE_SILENCIEUSE
			data.densite_monstres = "Quasi Aucun (Méditation & Mystères)"
			data.couleur_ciel_haut = Color(0.42, 0.56, 0.68, 1.0)
			data.couleur_ciel_horizon = Color(0.84, 0.88, 0.90, 1.0)
			data.couleur_brume = Color(0.76, 0.82, 0.86, 1.0)
			data.couleur_sol = Color(0.46, 0.48, 0.44, 1.0)
		4:
			data.nom = "Les Dunes de Cendre Aride"
			data.sous_titre = "Dimension Désertique — Mer de Sable Brûlant"
			data.biome = FloorData.Biome.DESERT_ARIDE
			data.densite_monstres = "Élevée"
			data.couleur_ciel_haut = Color(0.58, 0.34, 0.16, 1.0)
			data.couleur_ciel_horizon = Color(0.92, 0.72, 0.42, 1.0)
			data.couleur_brume = Color(0.82, 0.62, 0.38, 1.0)
			data.couleur_sol = Color(0.68, 0.54, 0.32, 1.0)
		5:
			data.nom = "Les Pics de Neige Éternelle"
			data.sous_titre = "Dimension Glaciaire — Crêtes du Givre Spirituel"
			data.biome = FloorData.Biome.NEIGE_ETERNELLE
			data.densite_monstres = "Modérée"
			data.couleur_ciel_haut = Color(0.18, 0.28, 0.48, 1.0)
			data.couleur_ciel_horizon = Color(0.76, 0.88, 0.96, 1.0)
			data.couleur_brume = Color(0.72, 0.85, 0.95, 1.0)
			data.couleur_sol = Color(0.82, 0.88, 0.94, 1.0)
		100:
			data.nom = "L'Abîme Hors-Récit"
			data.sous_titre = "Centième Ciel — Mer des Pages Déchirées"
			data.biome = FloorData.Biome.ABIME_HORS_RECIT
			data.densite_monstres = "Entités Méta-Narratives"
			data.couleur_ciel_haut = Color(0.03, 0.02, 0.06, 1.0)
			data.couleur_ciel_horizon = Color(0.22, 0.08, 0.32, 1.0)
			data.couleur_brume = Color(0.12, 0.05, 0.20, 1.0)
			data.couleur_sol = Color(0.08, 0.06, 0.12, 1.0)
		_:
			var biomes := [
				FloorData.Biome.PRAIRIE_JADE,
				FloorData.Biome.FORET_BAMBOUS,
				FloorData.Biome.STEPPE_SILENCIEUSE,
				FloorData.Biome.DESERT_ARIDE,
				FloorData.Biome.NEIGE_ETERNELLE,
				FloorData.Biome.VOLCAN_CELESTE,
				FloorData.Biome.MER_NUAGES,
				FloorData.Biome.RUINES_NOCTURNES,
				FloorData.Biome.CITADELLE_DAO
			]
			var noms_biomes := [
				"Plaines de Jade", "Bosquets Spirituels", "Steppe Silencieuse",
				"Désert Aride", "Cimes Enneigées", "Caldeira Céleste",
				"Mer de Nuages", "Ruines Lunaires", "Citadelle du Dao"
			]
			var idx : int = (n - 1) % biomes.size()
			data.biome = biomes[idx]
			data.nom = "%s — Ciel %d" % [noms_biomes[idx], n]
			data.sous_titre = "Dimension du Royaume %d" % data.royaume_recommande
			data.densite_monstres = "Quasi Aucun" if (n % 7 == 0) else ("Essaim" if (n % 5 == 0) else "Élevée")
	return data
