extends Node

func _ready() -> void:
	print("=== RUNNING DEVELOPER BRANDING & CREDITS TEST SUITE ===")
	
	# Explicitly start with EN for standard string matching
	LocalizationManager.set_language("en")
	
	# 1. Test MainMenu Watermark & Credits Button
	var main_menu_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn")
	assert(main_menu_scene != null, "MainMenu.tscn must load")
	var main_menu: MainMenu = main_menu_scene.instantiate() as MainMenu
	add_child(main_menu)
	
	assert(main_menu.watermark_label != null, "DevWatermarkLabel must exist")
	assert("DAVID 'SYOJHIN' BARREIROS" in main_menu.watermark_label.text, "Watermark must contain David 'Syojhin' Barreiros")
	assert(main_menu.credits_btn != null, "CreditsButton must exist on MainMenu")
	assert(main_menu.credits_modal != null, "CreditsModal instance must exist on MainMenu")
	print("✔ MainMenu watermark and credits button verified")
	
	# 2. Test CreditsModal Display & Close
	main_menu._on_credits_pressed()
	assert(main_menu.credits_modal.visible, "CreditsModal should be open")
	
	var lead_name: Label = main_menu.credits_modal.get_node("CenterContainer/Panel/Margin/VBox/CreditsGrid/LeadNameLabel") as Label
	var engine_name: Label = main_menu.credits_modal.get_node("CenterContainer/Panel/Margin/VBox/CreditsGrid/EngineNameLabel") as Label
	var audio_name: Label = main_menu.credits_modal.get_node("CenterContainer/Panel/Margin/VBox/CreditsGrid/AudioNameLabel") as Label
	var visuals_name: Label = main_menu.credits_modal.get_node("CenterContainer/Panel/Margin/VBox/CreditsGrid/VisualsNameLabel") as Label
	var close_btn: Button = main_menu.credits_modal.get_node("CenterContainer/Panel/Margin/VBox/CloseButton") as Button
	
	assert("DAVID BARREIROS (SYOJHIN)" in lead_name.text.to_upper(), "Lead developer should be David Barreiros (Syojhin)")
	assert("GODOT ENGINE" in engine_name.text.to_upper(), "Core engine should mention Godot Engine")
	assert("SYNTHWAVE" in audio_name.text.to_upper(), "Audio should mention Synthwave")
	assert("VECTOR CRT" in visuals_name.text.to_upper(), "Visuals should mention Vector CRT Pipeline")
	assert(close_btn.text == "CLOSE TERMINAL", "EN Close button should be 'CLOSE TERMINAL'")
	
	main_menu.credits_modal.close()
	assert(not main_menu.credits_modal.visible, "CreditsModal should close")
	print("✔ CreditsModal contents and interaction verified")
	
	# 3. Test VictoryModal Architect Credits & Accent Line
	var victory_scene: PackedScene = load("res://scenes/ui/VictoryModal.tscn")
	assert(victory_scene != null, "VictoryModal.tscn must load")
	var victory: VictoryModal = victory_scene.instantiate() as VictoryModal
	add_child(victory)
	
	assert(victory.architect_credit != null, "ArchitectCredit label must exist")
	assert(victory.accent_line != null, "AccentLine node must exist")
	
	victory.open_victory()
	assert(victory.visible, "Victory modal should be visible")
	assert("DAVID BARREIROS (SYOJHIN)" in victory.architect_credit.text.to_upper(), "Victory architect credit must contain David Barreiros (Syojhin)")
	assert(victory._accent_tween != null and victory._accent_tween.is_valid(), "Accent line tween animation should be running")
	print("✔ VictoryModal architect credits and glowing accent line verified")
	
	# 4. Test French Localization of Credits & Watermark
	LocalizationManager.set_language("fr")
	assert("DAVID 'SYOJHIN' BARREIROS" in main_menu.watermark_label.text, "French watermark should contain David 'Syojhin' Barreiros")
	assert("DAVID BARREIROS (SYOJHIN)" in victory.architect_credit.text, "French victory credit should contain David Barreiros (Syojhin)")
	assert(close_btn.text == "FERMER LE TERMINAL", "French close button should be 'FERMER LE TERMINAL'")
	print("✔ Bilingual localization for credits verified")
	
	# Reset language to EN and save
	LocalizationManager.set_language("en")
	SaveManager.language = "en"
	SaveManager.save_game()
	
	print("=== ALL DEVELOPER BRANDING & CREDITS TESTS PASSED ===")
	get_tree().quit()
