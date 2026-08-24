extends Node

func _ready() -> void:
	print("=== RUNNING FULL BILINGUAL LOCALIZATION TEST SUITE ===")
	
	# 1. Verify LocalizationManager Autoload
	assert(LocalizationManager != null, "LocalizationManager singleton must exist")
	LocalizationManager.set_language("en")
	assert(LocalizationManager.current_lang == "en", "Default language should be 'en'")
	assert(LocalizationManager.get_toggle_button_text() == "[ EN ] | FR", "EN button text should be '[ EN ] | FR'")
	print("✔ LocalizationManager singleton and English default verified")
	
	# 2. Test English String Lookups
	assert(LocalizationManager.get_text("UI_WAVE") == "WAVE", "EN UI_WAVE failed")
	assert(LocalizationManager.get_text("UI_START_MISSION") == "COMMENCE MISSION", "EN UI_START_MISSION failed")
	assert(LocalizationManager.get_text("TURRET_PULSE_NAME") == "Pulse Turret", "EN Pulse Turret failed")
	assert(LocalizationManager.get_card_name("chain_overload", "") == "Chain Overload", "EN Card name failed")
	assert(LocalizationManager.get_perk_name("kinetic_damage", "") == "Kinetic Amplifier", "EN Perk name failed")
	assert(LocalizationManager.get_text("REACTION_SUPERCONDUCT") == "SUPERCONDUCT!", "EN Reaction failed")
	print("✔ English dictionary lookups verified")
	
	# 3. Test Language Switching to French (FR)
	LocalizationManager.set_language("fr")
	assert(LocalizationManager.current_lang == "fr", "Current lang should be 'fr'")
	assert(LocalizationManager.get_toggle_button_text() == "EN | [ FR ]", "FR button text should be 'EN | [ FR ]'")
	assert(LocalizationManager.get_text("UI_WAVE") == "VAGUE", "FR UI_WAVE failed")
	assert(LocalizationManager.get_text("UI_START_MISSION") == "LANCER LA MISSION", "FR UI_START_MISSION failed")
	assert(LocalizationManager.get_text("TURRET_PULSE_NAME") == "Tourelle à Impulsion", "FR Pulse Turret failed")
	assert(LocalizationManager.get_card_name("chain_overload", "") == "Surcharge en Chaîne", "FR Card name failed")
	assert(LocalizationManager.get_perk_name("kinetic_damage", "") == "Amplificateur Cinétique", "FR Perk name failed")
	assert(LocalizationManager.get_text("REACTION_SUPERCONDUCT") == "SUPRACONDUCTION !", "FR Reaction failed")
	print("✔ French language switching and lookups verified")
	
	# 4. Test Persistence in SaveManager
	SaveManager.language = "fr"
	SaveManager.save_game()
	SaveManager.language = "en"
	SaveManager.load_game()
	assert(SaveManager.language == "fr", "SaveManager should load 'fr'")
	assert(LocalizationManager.current_lang == "fr", "LocalizationManager should be updated to 'fr' on load")
	print("✔ SaveManager language persistence verified")
	
	# 5. Test MainMenu Dynamic UI Updates
	var main_menu_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn")
	assert(main_menu_scene != null, "MainMenu.tscn must load")
	var main_menu: MainMenu = main_menu_scene.instantiate() as MainMenu
	add_child(main_menu)
	
	assert(main_menu.start_btn.text == "LANCER LA MISSION", "MainMenu start button should be French")
	assert(main_menu.lang_btn.text == "EN | [ FR ]", "MainMenu lang button should show FR active")
	
	# Toggle back to EN
	LocalizationManager.toggle_language()
	assert(main_menu.start_btn.text == "COMMENCE MISSION", "MainMenu start button should update to English")
	assert(main_menu.lang_btn.text == "[ EN ] | FR", "MainMenu lang button should show EN active")
	print("✔ MainMenu dynamic localization reactive updates verified")
	
	# 6. Test SettingsModal Dynamic UI Updates
	var settings_scene: PackedScene = load("res://scenes/ui/SettingsModal.tscn")
	assert(settings_scene != null, "SettingsModal.tscn must load")
	var settings: SettingsModal = settings_scene.instantiate() as SettingsModal
	add_child(settings)
	settings.open()
	
	assert(settings.close_btn.text == "CLOSE", "SettingsModal close button should be English")
	LocalizationManager.set_language("fr")
	assert(settings.close_btn.text == "FERMER", "SettingsModal close button should be French")
	print("✔ SettingsModal dynamic localization reactive updates verified")
	
	# 7. Test Arena Dynamic UI Updates
	var arena_scene: PackedScene = load("res://scenes/combat/Arena.tscn")
	assert(arena_scene != null, "Arena.tscn must load")
	var arena: Arena = arena_scene.instantiate() as Arena
	add_child(arena)
	
	assert(arena.skill_tree_open_btn.text == "MATRICE MÉTA", "Arena skill tree button should be French")
	assert(arena.lang_btn.text == "EN | [ FR ]", "Arena lang button should show FR active")
	
	LocalizationManager.set_language("en")
	assert(arena.skill_tree_open_btn.text == "META MATRIX", "Arena skill tree button should be English")
	assert(arena.lang_btn.text == "[ EN ] | FR", "Arena lang button should show EN active")
	print("✔ Arena HUD dynamic localization reactive updates verified")
	
	# 8. Test CardDraftModal Dynamic UI Updates
	var draft_modal: CardDraftModal = arena.get_node("CanvasLayer/CardDraftModal") as CardDraftModal
	assert(draft_modal != null, "CardDraftModal must exist in Arena")
	draft_modal.open_draft([
		CardDraftModal.CARD_POOL[0],
		CardDraftModal.CARD_POOL[1],
		CardDraftModal.CARD_POOL[2]
	])
	
	var title_lbl: Label = draft_modal.card1_node.get_node("Margin/VBox/TitleLabel") as Label
	assert(title_lbl.text == "Chain Overload", "Card 1 title should be 'Chain Overload'")
	
	LocalizationManager.set_language("fr")
	assert(title_lbl.text == "Surcharge en Chaîne", "Card 1 title should dynamically translate to 'Surcharge en Chaîne'")
	print("✔ CardDraftModal dynamic localization reactive updates verified")
	
	# 9. Test SkillTree Dynamic UI Updates
	var skill_tree: SkillTree = arena.get_node("CanvasLayer/SkillTree") as SkillTree
	assert(skill_tree != null, "SkillTree must exist in Arena")
	skill_tree.open()
	var node_kinetic: SkillTreeNode = skill_tree._node_instances.get("kinetic_damage", null) as SkillTreeNode
	assert(node_kinetic != null, "Kinetic node must exist in SkillTree")
	assert(node_kinetic.title_label.text == "Amplificateur Cinétique", "Perk title should be in French")
	
	LocalizationManager.set_language("en")
	assert(node_kinetic.title_label.text == "Kinetic Amplifier", "Perk title should dynamically translate to English")
	print("✔ SkillTree dynamic localization reactive updates verified")
	
	print("=== ALL BILINGUAL LOCALIZATION TESTS PASSED ===")
	get_tree().quit()
