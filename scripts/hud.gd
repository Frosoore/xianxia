extends Control

@onready var label_royaume: Label = %LabelRoyaume
@onready var barre_qi: ProgressBar = %BarreQi
@onready var barre_endurance: ProgressBar = %BarreEndurance

const NOMS_ROYAUMES: Dictionary = {
	1: "Royaume 1 : Raffinement Corporel",
	2: "Royaume 2 : Condensation du Qi",
	3: "Royaume 3 : Établissement de la Fondation",
	4: "Royaume 4 : Noyau d'Or",
	5: "Royaume 5 : Âme Naissante",
	6: "Royaume 6 : Transformation de la Divinité",
	7: "Royaume 7 : Raffinement du Vide",
	8: "Royaume 8 : Intégration du Dao",
	9: "Royaume 9 : Grande Ascension",
	10: "Royaume 10 : Immortel Véritable"
}

func mettre_a_jour_royaume(niveau: int) -> void:
	if not is_node_ready():
		await ready
	if NOMS_ROYAUMES.has(niveau):
		label_royaume.text = NOMS_ROYAUMES[niveau]
	else:
		label_royaume.text = "Royaume " + str(niveau)

func mettre_a_jour_qi(actuel: float, maximum: float) -> void:
	if not is_node_ready():
		await ready
	barre_qi.max_value = maximum
	barre_qi.value = actuel

func mettre_a_jour_endurance(actuel: float, maximum: float) -> void:
	if not is_node_ready():
		await ready
	barre_endurance.max_value = maximum
	barre_endurance.value = actuel
