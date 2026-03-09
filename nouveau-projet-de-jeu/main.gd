extends Control

# --- VARIABLES DE LOGIQUE ---
var lives: int = 3
var words: Array = ["BATAILLE", "CLAVIER", "MOBILE", "GODOT", "VITESSE", "PROJET"]
var current_word: String = ""
var current_letter_index: int = 0
var is_input_blocked: bool = false

# --- NOEUDS DE L'INTERFACE ---
@onready var lives_label: Label = %LivesLabel
@onready var word_display: RichTextLabel = %WordDisplay
@onready var keyboard_grid: GridContainer = %KeyboardGrid

# Accès au SubViewport et au Mesh (feuille) pour y coller la texture du viewport
@onready var subviewport: SubViewport = $SubViewport
@onready var page_mesh: MeshInstance3D = $Node3D/Paper

# Disposition du clavier AZERTY
var azerty_layout: Array = [
	"A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P",
	"Q", "S", "D", "F", "G", "H", "J", "K", "L", "M",
	"W", "X", "C", "V", "B", "N"
]

func _ready() -> void:
	generate_keyboard()
	update_lives_display()
	load_next_word()
	# Lier le SubViewport au Mesh (création d'un material qui utilise la texture du SubViewport)
	setup_viewport_texture()

# --- INITIALISATION ---

func generate_keyboard() -> void:
	# Crée les boutons du clavier dynamiquement
	for letter in azerty_layout:
		var btn = Button.new()
		btn.text = letter
		btn.custom_minimum_size = Vector2(40, 60) # Taille adaptée pour mobile (à ajuster)
		
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0) # Opacité à 0
		btn.pressed.connect(_on_key_pressed.bind(letter)) 
		
		keyboard_grid.add_child(btn)

func load_next_word() -> void:
	if words.is_empty():
		word_display.text = "[center][color=yellow]VICTOIRE ![/color][/center]"
		is_input_blocked = true
		return
		
	# On prend un mot au hasard et on l'enlève de la liste
	var random_index = randi() % words.size()
	current_word = words[random_index]
	words.remove_at(random_index)
	
	current_letter_index = 0
	update_word_display()

# --- LOGIQUE DE JEU ---

func _on_key_pressed(letter: String) -> void:
	# Si le jeu est en pause (mot rouge ou vert) ou Game Over, on ignore la frappe
	if is_input_blocked:
		return
		
	# Vérifie si la lettre tapée correspond à la lettre attendue
	if letter == current_word[current_letter_index]:
		handle_correct_letter()
	else:
		handle_wrong_letter()

func handle_correct_letter() -> void:
	current_letter_index += 1
	
	# Si on a tapé toutes les lettres du mot
	if current_letter_index >= current_word.length():
		word_display.text = "[center][color=green]" + current_word + "[/color][/center]"
		is_input_blocked = true
		
		# Pause de 0.5 seconde avant le mot suivant
		await get_tree().create_timer(0.5).timeout 
		
		is_input_blocked = false
		load_next_word()
	else:
		# Le mot n'est pas fini, on met juste à jour l'affichage
		update_word_display()

func handle_wrong_letter() -> void:
	lives -= 1
	update_lives_display()
	
	if lives <= 0:
		word_display.text = "[center][color=red]GAME OVER[/color][/center]"
		is_input_blocked = true
		return
		
	# Affichage de l'erreur
	word_display.text = "[center][color=red]" + current_word + "[/color][/center]"
	is_input_blocked = true
	
	# Pause de 1 seconde
	await get_tree().create_timer(1.0).timeout 
	
	# Si on n'est pas mort entre temps, on réinitialise le mot actuel
	if lives > 0:
		current_letter_index = 0
		update_word_display()
		is_input_blocked = false

# --- GESTION DE L'AFFICHAGE ---

func update_word_display() -> void:
	var display_text = "[center]"
	
	for i in range(current_word.length()):
		if i < current_letter_index:
			# Lettres déjà tapées correctement (en blanc)
			display_text += "[color=white]" + current_word[i] + "[/color]"
		else:
			# Lettres restantes (grisées)
			display_text += "[color=gray]" + current_word[i] + "[/color]"
			
	display_text += "[/center]"
	word_display.text = display_text

func update_lives_display() -> void:
	lives_label.text = "Vies : " + str(lives)

# --- FONCTIONS D'ASSISTANCE POUR LE VIEWPORT ---

func setup_viewport_texture() -> void:
	# Assigne la texture du SubViewport au MeshInstance3D via un material non-éclairé (pour garder les couleurs 2D identiques)
	if subviewport == null:
		print("[setup_viewport_texture] SubViewport introuvable")
		return
	if page_mesh == null:
		print("[setup_viewport_texture] MeshInstance3D introuvable")
		return

	var tex = subviewport.get_texture()
	if tex == null:
		# Forcer une mise à jour du SubViewport et retenter
		if subviewport.has_method("update"):
			subviewport.update()
		tex = subviewport.get_texture()

	if tex == null:
		print("[setup_viewport_texture] Aucune texture récupérée depuis le SubViewport (taille=", subviewport.size, ")")
		return

	var mat := StandardMaterial3D.new()
	mat.unshaded = true
	mat.albedo_texture = tex
	# On peut aussi utiliser emission_texture si besoin :
	# mat.emission_enabled = true
	# mat.emission_texture = tex

	# Appliquer au mesh (material_override remplace tout le matériau de l'instance)
	page_mesh.material_override = mat
