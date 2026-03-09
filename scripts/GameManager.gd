# GameManager.gd
# Prototype Typing Game — Godot 4 (GDScript)
# Attacher ce script au nœud racine de la scène principale `Main` (Node2D).
# Structure de nœuds attendue (chemins utilisés par le script) :
# Main (Node2D)
#  ├─ SuccessTimer (Timer)  -- one_shot = true, wait_time = 0.5
#  ├─ FailTimer (Timer)     -- one_shot = true, wait_time = 1.0
#  └─ HUD (CanvasLayer)
#      └─ HUDRoot (Control)
#          ├─ ScoreLabel (Label)
#          ├─ LivesContainer (HBoxContainer)
#          ├─ WordDisplay (HBoxContainer)  -- contiendra un Label par lettre
#          └─ Keyboard (GridContainer)     -- GridContainer vide, rempli par le script
#
# Ce script gère :
# - l'affichage "machine à écrire" (WordDisplay)
# - la création d'un clavier AZERTY virtuel dans Keyboard
# - la vérification des touches cliquées, progression sur le mot
# - la gestion des vies (LivesContainer)
# - success (0.5s vert) et erreur (1s rouge) en bloquant les inputs pendant la durée

extends Node2D

@export var words: Array = ["bonjour", "salut", "maison", "voiture", "ordinateur", "pomme", "chat", "chien", "avion", "porte"]
@export var starting_lives: int = 3

# Layout AZERTY (simplifié en 3 lignes) — caractères en minuscules
@export var azerty_rows: Array = [["a","z","e","r","t","y","u","i","o","p"],
                                 ["q","s","d","f","g","h","j","k","l","m"],
                                 ["w","x","c","v","b","n"]]

# Nœuds (doivent exister dans la scène)
@onready var score_label: Label = $HUD/HUDRoot/ScoreLabel
@onready var lives_container: HBoxContainer = $HUD/HUDRoot/LivesContainer
@onready var word_display: HBoxContainer = $HUD/HUDRoot/WordDisplay
@onready var keyboard: GridContainer = $HUD/HUDRoot/Keyboard
@onready var success_timer: Timer = $SuccessTimer
@onready var fail_timer: Timer = $FailTimer

# État
var current_word: String = ""
var progress: int = 0
var lives: int
var input_locked: bool = false
var score: int = 0

func _ready() -> void:
	# Initialisation
	lives = starting_lives
	randomize()
	# Créer le clavier virtuel et l'UI des vies
	_create_keyboard()
	_create_lives_ui()
	# Connecter timers
	success_timer.connect("timeout", Callable(self, "_on_success_timeout"))
	fail_timer.connect("timeout", Callable(self, "_on_fail_timeout"))
	# Commencer le premier mot
	next_word()
	_update_score_label()

# --- UI builders ---
func _create_keyboard() -> void:
	# Vider si des enfants existent
	while keyboard.get_child_count() > 0:
		keyboard.get_child(0).queue_free()

	# Configurer GridContainer : on peut garder les colonnes par défaut, mais sur mobile
	# vous pouvez régler keyboard.columns dans l'éditeur si souhaité.

	for row in azerty_rows:
		for letter in row:
			var btn := Button.new()
			btn.text = letter.upper()
			btn.name = "Key_%s" % letter
			btn.toggle_mode = false
			btn.focus_mode = Control.FocusMode.NONE
			# Connexion avec argument : la lettre
			btn.pressed.connect(Callable(self, "_on_virtual_key_pressed")).call_deferred("connect", "pressed", self, "_on_virtual_key_pressed", [letter])
			# Note: on utilise call_deferred(connect) pour éviter erreurs pendant la construction
			keyboard.add_child(btn)

	# Ajouter un bouton "Espace" et "Back" optionnels sous la grille si voulu
	var space_btn := Button.new()
	space_btn.text = "ESPACE"
	space_btn.name = "Key_space"
	space_btn.focus_mode = Control.FocusMode.NONE
	space_btn.pressed.connect(Callable(self, "_on_virtual_key_pressed"))
	space_btn.pressed.call_deferred("connect", "pressed", self, "_on_virtual_key_pressed", [" "])
	keyboard.add_child(space_btn)

func _create_lives_ui() -> void:
	# Vider
	while lives_container.get_child_count() > 0:
		lives_container.get_child(0).queue_free()
	# Créer icônes de vies (Labels avec coeur)
	for i in range(starting_lives):
		var l := Label.new()
		l.name = "Life_%d" % i
		l.text = "♥" if i < lives else "♡"
		l.add_theme_color_override("font_color", Color(1,0.2,0.2))
		lives_container.add_child(l)

# --- Core gameplay ---
func _display_new_word(word: String) -> void:
	# Vider l'affichage du mot
	while word_display.get_child_count() > 0:
		word_display.get_child(0).queue_free()

	progress = 0
	current_word = word
	# Créer un Label par lettre
	for ch in current_word:
		var lbl := Label.new()
		lbl.text = ch
		lbl.name = "L_%s" % ch
		lbl.modulate = Color(0.6, 0.6, 0.6) # gris pour lettre non encore tapée
		lbl.add_theme_font_size_override("font_size", 36)
		word_display.add_child(lbl)

func _on_virtual_key_pressed(letter: String) -> void:
	# Handler pour les boutons du clavier
	if input_locked:
		return
	if current_word == "":
		return

	letter = str(letter).to_lower()
	# Comparaison caractère par caractère
	if progress < current_word.length() and letter == current_word[progress]:
		# Bonne lettre
		var good_lbl := word_display.get_child(progress)
		good_lbl.modulate = Color(1,1,1) # blanc/éclairci pour la lettre correcte
		progress += 1
		# Si mot complété
		if progress >= current_word.length():
			score += 1
			_update_score_label()
			_set_word_color(Color(0,1,0)) # vert
			input_locked = true
			success_timer.start(0.5)
	else:
		# Mauvaise lettre
		lives -= 1
		_update_lives_ui()
		_set_word_color(Color(1,0,0))
		input_locked = true
		if lives <= 0:
			# Game over immédiatement (on peut attendre la fin du timer visuel si on préfère)
			fail_timer.start(1.0)
			# _game_over() sera appelé après le timer afin d'afficher l'animation rouge
		else:
			fail_timer.start(1.0)

func _set_word_color(color: Color) -> void:
	for i in range(word_display.get_child_count()):
		word_display.get_child(i).modulate = color

func _on_success_timeout() -> void:
	# Mot réussi — passer au mot suivant
	input_locked = false
	next_word()

func _on_fail_timeout() -> void:
	# Après erreur visuelle (1s rouge) — soit game over soit réinitialiser le mot
	if lives <= 0:
		_game_over()
		return
	# Sinon on réinitialise le mot courant (lettres repassent grisées)
	progress = 0
	_set_word_color(Color(0.6, 0.6, 0.6))
	input_locked = false

func _update_lives_ui() -> void:
	for i in range(lives_container.get_child_count()):
		var l := lives_container.get_child(i) as Label
		if i < lives:
			l.text = "♥"
		else:
			l.text = "♡"

func _update_score_label() -> void:
	score_label.text = "Score: %d" % score

func next_word() -> void:
	if words.empty():
		push_warning("Liste de mots vide.")
		return
	# Choisir un mot aléatoire différent du précédent si possible
	var prev := current_word
	var attempts := 0
	while attempts < 10:
		var candidate := words[randi() % words.size()].to_lower()
		if candidate != prev:
			_display_new_word(candidate)
			return
		attempts += 1
	# Si on n'a pas trouvé autre chose, utiliser le dernier tirage
	_display_new_word(words[randi() % words.size()].to_lower())

func _game_over() -> void:
	input_locked = true
	success_timer.stop()
	fail_timer.stop()
	# Simple état Game Over : afficher un message dans ScoreLabel
	score_label.text = "Game Over! Score: %d" % score
	# Ici vous pouvez afficher un écran Game Over, bouton restart, etc.

# --- Utilitaires éventuels ---
func reset_game() -> void:
	# Réinitialise le jeu (vies, score, mot)
	score = 0
	lives = starting_lives
	_update_score_label()
	_update_lives_ui()
	input_locked = false
	next_word()

