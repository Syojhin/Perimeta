extends Node

## Bilingual Localization Manager (English / French) for Perimeta.
## Provides dynamic language switching, persistent saving, and reactive signal dispatch.

signal language_changed(new_lang: String)

var current_lang: String = "en" # "en" or "fr"

const TRANSLATIONS: Dictionary = {
	# --- UI & HUD ---
	"UI_TITLE": {
		"en": "PERIMETA",
		"fr": "PERIMETA"
	},
	"UI_SUBTITLE": {
		"en": "// NEON PERIMETER DEFENSE //",
		"fr": "// DÉFENSE DU PÉRIMÈTRE NÉON //"
	},
	"UI_START_MISSION": {
		"en": "COMMENCE MISSION",
		"fr": "LANCER LA MISSION"
	},
	"UI_SKILL_TREE": {
		"en": "META MATRIX",
		"fr": "MATRICE MÉTA"
	},
	"UI_SETTINGS": {
		"en": "SETTINGS",
		"fr": "PARAMÈTRES"
	},
	"UI_QUIT": {
		"en": "QUIT",
		"fr": "QUITTER"
	},
	"UI_WAVE": {
		"en": "WAVE",
		"fr": "VAGUE"
	},
	"UI_BITS": {
		"en": "BITS",
		"fr": "BITS"
	},
	"UI_CORES": {
		"en": "CORES",
		"fr": "CŒURS"
	},
	"UI_META_CORES": {
		"en": "META-CORES",
		"fr": "MÉTA-CŒURS"
	},
	"UI_GUN_COST": {
		"en": "GUN",
		"fr": "CANON"
	},
	"UI_EMP_READY": {
		"en": "EMP SHOCKWAVE READY!",
		"fr": "ONDE DE CHOC IEM PRÊTE !"
	},
	"UI_EMP_CHARGE": {
		"en": "EMP CHARGE: %d%%",
		"fr": "CHARGE IEM : %d%%"
	},
	"UI_OVERCHARGE_BTN": {
		"en": "OVERCHARGE EMP (1500 B)",
		"fr": "SURCHARGE IEM (1500 B)"
	},
	"UI_RESPEC": {
		"en": "RESPEC (REFUND ALL)",
		"fr": "RÉINITIALISER (REMBOURSER)"
	},
	"UI_CLOSE": {
		"en": "CLOSE",
		"fr": "FERMER"
	},
	"UI_RESUME": {
		"en": "RESUME",
		"fr": "REPRENDRE"
	},
	"UI_RESTART_RUN": {
		"en": "RESTART RUN",
		"fr": "RECOMMENCER"
	},
	"UI_MAIN_MENU": {
		"en": "MAIN MENU",
		"fr": "MENU PRINCIPAL"
	},
	"UI_AUDIO": {
		"en": "AUDIO",
		"fr": "AUDIO"
	},
	"UI_MASTER": {
		"en": "Master:",
		"fr": "Général :"
	},
	"UI_SFX": {
		"en": "SFX:",
		"fr": "Effets :"
	},
	"UI_MUSIC": {
		"en": "Music:",
		"fr": "Musique :"
	},
	"UI_DISPLAY": {
		"en": "DISPLAY",
		"fr": "AFFICHAGE"
	},
	"UI_FULLSCREEN": {
		"en": "Fullscreen",
		"fr": "Plein Écran"
	},
	"UI_CRT_FILTER": {
		"en": "Retro CRT Filter",
		"fr": "Filtre Rétro CRT"
	},
	"UI_PURGE_SAVE": {
		"en": "[ PURGE & RESET SAVE ]",
		"fr": "[ EFFACER ET RÉINITIALISER ]"
	},
	"UI_SAVE_PURGED": {
		"en": "[ SAVE PURGED // DEFAULTS RESTORED ]",
		"fr": "[ SAUVEGARDE EFFACÉE // PARAMÈTRES RÉINITIALISÉS ]"
	},
	"UI_SECTOR_ALERT": {
		"en": "[ALERT: NEW PERIMETER BREACH SECTOR ONLINE]",
		"fr": "[ALERTE : NOUVEAU SECTEUR DE BRÈCHE EN LIGNE]"
	},
	"UI_DEFEAT_HEADER": {
		"en": "CORE BREACH // RUN TERMINATED",
		"fr": "BRÈCHE DU CŒUR // MISSION TERMINÉE"
	},
	"UI_VICTORY_HEADER": {
		"en": "SECTOR SECURED // WAVE 25 CONQUERED",
		"fr": "SECTEUR SÉCURISÉ // VAGUE 25 SURMONTÉE"
	},
	"UI_VICTORY_SUBTITLE": {
		"en": "PERIMETER DEFENSES HELD AGAINST ALL HOSTILE FORCES",
		"fr": "DÉFENSES DU PÉRIMÈTRE MAINTENUES FACE AUX FORCES ENNEMIES"
	},
	"UI_BANK_CORES": {
		"en": "BANK REWARDS & RETURN",
		"fr": "ENCAISSER ET RETOURNER"
	},
	"UI_ENDLESS_MODE": {
		"en": "CONTINUE ENDLESS OVERCLOCK",
		"fr": "CONTINUER EN MODE INFINI"
	},
	"UI_WAVES_REACHED": {
		"en": "Waves Reached:",
		"fr": "Vagues Atteintes :"
	},
	"UI_ENEMIES_DEFEATED": {
		"en": "Enemies Defeated:",
		"fr": "Ennemis Éliminés :"
	},
	"UI_FINAL_SCORE": {
		"en": "Final Score:",
		"fr": "Score Final :"
	},
	"UI_BITS_HARVESTED": {
		"en": "Bits Harvested:",
		"fr": "Bits Récoltés :"
	},
	"UI_CORES_AWARDED": {
		"en": "Meta-Cores Awarded:",
		"fr": "Méta-Cœurs Obtenus :"
	},
	"UI_TOTAL_CORES": {
		"en": "Total Meta-Cores:",
		"fr": "Total Méta-Cœurs :"
	},
	"UI_BONUS_CORES": {
		"en": "Meta-Core Payout:",
		"fr": "Paiement Méta-Cœurs :"
	},
	"UI_CREDITS": {
		"en": "CREDITS",
		"fr": "CRÉDITS"
	},
	"UI_CREDITS_TITLE": {
		"en": "SYSTEM ARCHITECTURE // CREDITS",
		"fr": "ARCHITECTURE SYSTÈME // CRÉDITS"
	},
	"UI_CREDITS_LEAD": {
		"en": "Lead Developer & Game Design",
		"fr": "Développeur Principal & Conception du Jeu"
	},
	"UI_CREDITS_LEAD_VAL": {
		"en": "David Barreiros (Syojhin)",
		"fr": "David Barreiros (Syojhin)"
	},
	"UI_CREDITS_ENGINE": {
		"en": "Core Engine",
		"fr": "Moteur Principal"
	},
	"UI_CREDITS_AUDIO": {
		"en": "Soundtrack & Audio Engineering",
		"fr": "Bande-Son & Ingénierie Audio"
	},
	"UI_CREDITS_AUDIO_VAL": {
		"en": "Procedural Synthwave Suite",
		"fr": "Suite Synthwave Procédurale"
	},
	"UI_CREDITS_VISUALS": {
		"en": "Visual Architecture & Shaders",
		"fr": "Architecture Visuelle & Shaders"
	},
	"UI_CREDITS_VISUALS_VAL": {
		"en": "Vector CRT Matrix Pipeline",
		"fr": "Pipeline Matrice CRT Vectorielle"
	},
	"UI_CREDITS_CLOSE": {
		"en": "CLOSE TERMINAL",
		"fr": "FERMER LE TERMINAL"
	},
	"UI_DEV_WATERMARK": {
		"en": "PERIMETA // CREATED & ENGINEERED BY DAVID 'SYOJHIN' BARREIROS",
		"fr": "PERIMETA // CRÉÉ & DÉVELOPPÉ PAR DAVID 'SYOJHIN' BARREIROS"
	},
	"UI_VICTORY_DEV_CREDIT": {
		"en": "A GAME BY DAVID BARREIROS (SYOJHIN)",
		"fr": "UN JEU DE DAVID BARREIROS (SYOJHIN)"
	},

	# --- Turrets & Sockets ---
	"TURRET_PULSE_NAME": {
		"en": "Pulse Turret",
		"fr": "Tourelle à Impulsion"
	},
	"TURRET_CRYO_NAME": {
		"en": "Cryo Emitter",
		"fr": "Émetteur Cryo"
	},
	"TURRET_CHAIN_NAME": {
		"en": "Chain Turret",
		"fr": "Tourelle en Chaîne"
	},
	"TURRET_MORTAR_NAME": {
		"en": "Plasma Mortar",
		"fr": "Mortier à Plasma"
	},
	"TURRET_RAILGUN_NAME": {
		"en": "Railgun Turret",
		"fr": "Canon Électromagnétique"
	},
	"TARGET_FIRST": {
		"en": "TARGET: FIRST",
		"fr": "CIBLE : PREMIER"
	},
	"TARGET_LAST": {
		"en": "TARGET: LAST",
		"fr": "CIBLE : DERNIER"
	},
	"TARGET_STRONGEST": {
		"en": "TARGET: STRONGEST",
		"fr": "CIBLE : PLUS FORT"
	},
	"TARGET_WEAKEST": {
		"en": "TARGET: WEAKEST",
		"fr": "CIBLE : PLUS FAIBLE"
	},
	"TARGET_CLOSEST": {
		"en": "TARGET: CLOSEST",
		"fr": "CIBLE : PLUS PROCHE"
	},
	"UPGRADE_T5": {
		"en": "UPGRADE TO MASTER T5 [%d B]",
		"fr": "AMÉLIORER EN MAÎTRE T5 [%d B]"
	},
	"UPGRADE_TIER": {
		"en": "UPGRADE TO T%d (+35%% DMG) [%d B]",
		"fr": "AMÉLIORER T%d (+35%% DÉG) [%d B]"
	},
	"UPGRADE_TIER_NO_BITS": {
		"en": "UPGRADE T%d (%d BITS)",
		"fr": "AMÉLIORER T%d (%d BITS)"
	},
	"INFUSION_BTN": {
		"en": "INFUSION +%d (+5%% DMG) [%d B]",
		"fr": "INFUSION +%d (+5%% DÉG) [%d B]"
	},
	"DECOMMISSION_BTN": {
		"en": "DECOMMISSION (+%d BITS)",
		"fr": "DÉMANTELER (+%d BITS)"
	},

	# --- Roguelite Draft Cards ---
	"DRAFT_TITLE": {
		"en": "// ROGUELITE CARD DRAFT //",
		"fr": "// PROTOCOLE DE TIRAGE ROGUELITE //"
	},
	"DRAFT_SUBTITLE": {
		"en": "SELECT 1 IN-RUN PERIMETER PROTOCOL TO AUGMENT COMBAT",
		"fr": "CHOISISSEZ 1 PROTOCOLE DE PÉRIMÈTRE POUR AUGMENTER LE COMBAT"
	},
	"CARD_SELECT": {
		"en": "[ SELECT PROTOCOL ]",
		"fr": "[ SÉLECTIONNER ]"
	},
	"CARD_TAG_OFFENSE": {
		"en": "OFFENSE",
		"fr": "ATTAQUE"
	},
	"CARD_TAG_TACTICAL": {
		"en": "TACTICAL",
		"fr": "TACTIQUE"
	},
	"CARD_TAG_ECONOMY": {
		"en": "ECONOMY",
		"fr": "ÉCONOMIE"
	},
	"CARD_TAG_CURSOR": {
		"en": "CURSOR",
		"fr": "CURSEUR"
	},
	"CARD_TAG_SUPER": {
		"en": "SUPER",
		"fr": "SUPER"
	},
	"CARD_TAG_DEFENSE": {
		"en": "DEFENSE",
		"fr": "DÉFENSE"
	},
	"CARD_TAG_MORTAR": {
		"en": "MORTAR",
		"fr": "MORTIER"
	},
	"CARD_TAG_RAILGUN": {
		"en": "RAILGUN",
		"fr": "CANON"
	},
	"CARD_TAG_SYNERGY": {
		"en": "SYNERGY",
		"fr": "SYNERGIE"
	},

	# Card Descriptions & Names
	"CARD_chain_overload_NAME": {
		"en": "Chain Overload",
		"fr": "Surcharge en Chaîne"
	},
	"CARD_chain_overload_DESC": {
		"en": "Chain Turret arcs jump to +2 additional enemy targets.",
		"fr": "Les arcs de la tourelle en chaîne touchent +2 cibles supplémentaires."
	},
	"CARD_cryo_shatter_NAME": {
		"en": "Cryo Shatter",
		"fr": "Fracas Cryo"
	},
	"CARD_cryo_shatter_DESC": {
		"en": "Slowed enemies take +35% increased damage from all sources.",
		"fr": "Les ennemis ralentis subissent +35% de dégâts supplémentaires de toutes sources."
	},
	"CARD_kinetic_velocity_NAME": {
		"en": "Kinetic Velocity",
		"fr": "Vélocité Cinétique"
	},
	"CARD_kinetic_velocity_DESC": {
		"en": "All turrets gain +25% attack speed for the rest of this run.",
		"fr": "Toutes les tourelles gagnent +25% de vitesse d'attaque pour cette partie."
	},
	"CARD_bountiful_bits_NAME": {
		"en": "Bountiful Bits",
		"fr": "Bits Abondants"
	},
	"CARD_bountiful_bits_DESC": {
		"en": "Defeated enemies award +2 bonus Bits on kill.",
		"fr": "Chaque ennemi vaincu rapporte +2 Bits supplémentaires."
	},
	"CARD_laser_drill_NAME": {
		"en": "Laser Drill",
		"fr": "Foreuse Laser"
	},
	"CARD_laser_drill_DESC": {
		"en": "Coin Gun cursor shots deal +50% increased damage.",
		"fr": "Les tirs du canon à curseur infligent +50% de dégâts."
	},
	"CARD_core_overcharge_NAME": {
		"en": "Core Overcharge",
		"fr": "Surcharge du Cœur"
	},
	"CARD_core_overcharge_DESC": {
		"en": "Core EMP Super Ability charges +30% faster from all sources.",
		"fr": "La super capacité IEM du Cœur se charge +30% plus vite."
	},
	"CARD_vital_surge_NAME": {
		"en": "Vital Surge",
		"fr": "Surge Vitale"
	},
	"CARD_vital_surge_DESC": {
		"en": "Increase Max Core HP by +30 and instantly restore +30 Core HP.",
		"fr": "Augmente les PV max du Cœur de +30 et restaure immédiatement 30 PV."
	},
	"CARD_overclock_burst_NAME": {
		"en": "Overclock Burst",
		"fr": "Rafale Surcadencée"
	},
	"CARD_overclock_burst_DESC": {
		"en": "Increase base damage of all placed and future turrets by +20%.",
		"fr": "Augmente les dégâts de base de toutes les tourelles de +20%."
	},
	"CARD_mortar_cluster_shells_NAME": {
		"en": "Cluster Shells",
		"fr": "Obus à Sous-Munitions"
	},
	"CARD_mortar_cluster_shells_DESC": {
		"en": "Mortar impacts scatter 3 mini-shrapnel bomblets around the blast zone (dealing 35% damage each).",
		"fr": "Les impacts de mortier dispersent 3 mini-bombes shrapnel (35% de dégâts chacune)."
	},
	"CARD_mortar_thermal_napalm_NAME": {
		"en": "Thermal Napalm",
		"fr": "Napalm Thermique"
	},
	"CARD_mortar_thermal_napalm_DESC": {
		"en": "Mortar explosions leave a burning hazard puddle for 3.0s, dealing ticking fire damage to passing enemies.",
		"fr": "Les explosions laissent une zone en flammes pendant 3.0s infligeant des dégâts continus."
	},
	"CARD_mortar_heavy_ordnance_NAME": {
		"en": "Heavy Ordnance",
		"fr": "Artillerie Lourde"
	},
	"CARD_mortar_heavy_ordnance_DESC": {
		"en": "+40% Mortar blast radius and +25% damage, but -15% fire rate.",
		"fr": "+40% de rayon d'explosion et +25% de dégâts au mortier, mais -15% de cadence."
	},
	"CARD_railgun_superconductor_NAME": {
		"en": "Superconductor",
		"fr": "Supraconducteur"
	},
	"CARD_railgun_superconductor_DESC": {
		"en": "Railgun slugs gain +15% damage for each enemy pierced in a single shot.",
		"fr": "Les tirs de canon gagnent +15% de dégâts pour chaque ennemi transpercé."
	},
	"CARD_railgun_ionized_trail_NAME": {
		"en": "Ionized Trail",
		"fr": "Traînée Ionisée"
	},
	"CARD_railgun_ionized_trail_DESC": {
		"en": "Railgun beams leave an electrified energy beam on the track for 2.0s that shocks crossing enemies.",
		"fr": "Le rayon laisse une traînée électrifiée de 2.0s électrocutant les ennemis qui traversent."
	},
	"CARD_railgun_dual_capacitor_NAME": {
		"en": "Dual Capacitor",
		"fr": "Double Condensateur"
	},
	"CARD_railgun_dual_capacitor_DESC": {
		"en": "Railgun beam width is doubled (+100% width) and deals +20% damage to Shielded/Armored enemies.",
		"fr": "La largeur du rayon est doublée (+100%) et inflige +20% de dégâts aux cibles blindées/boucliers."
	},
	"CARD_synergy_thermal_shock_NAME": {
		"en": "Thermal Shock",
		"fr": "Choc Thermique"
	},
	"CARD_synergy_thermal_shock_DESC": {
		"en": "Enemies slowed or frozen by Cryo turrets take +50% extra explosive damage from Plasma Mortars.",
		"fr": "Les ennemis ralentis ou gelés par Cryo subissent +50% de dégâts explosifs du Mortier."
	},
	"CARD_synergy_kinetic_overclock_NAME": {
		"en": "Kinetic Overclock",
		"fr": "Surcadençage Cinétique"
	},
	"CARD_synergy_kinetic_overclock_DESC": {
		"en": "Railguns and Mortars gain +30% faster attack speed when any Pulse turret is within their range.",
		"fr": "Les Canons et Mortiers tirent 30% plus vite lorsqu'une tourelle à impulsion est à portée."
	},

	# --- Meta-Matrix Perks ---
	"PERK_MAX_LEVEL": {
		"en": "MAX LEVEL",
		"fr": "NIVEAU MAX"
	},
	"PERK_REQ": {
		"en": "REQ: %s",
		"fr": "REQUIS : %s"
	},
	"PERK_UNLOCK": {
		"en": "UNLOCK (%d CORES)",
		"fr": "DÉBLOQUER (%d CŒURS)"
	},
	"PERK_CORES_FMT": {
		"en": "%d CORES",
		"fr": "%d CŒURS"
	},
	"PERK_LVL_FMT": {
		"en": "LVL %d / %d",
		"fr": "NIV %d / %d"
	},
	"PERK_kinetic_damage_NAME": {
		"en": "Kinetic Amplifier",
		"fr": "Amplificateur Cinétique"
	},
	"PERK_kinetic_damage_DESC": {
		"en": "+10% Tower Damage per level.",
		"fr": "+10% de dégâts des tourelles par niveau."
	},
	"PERK_overclock_NAME": {
		"en": "Overclock Relays",
		"fr": "Relais Surcadencés"
	},
	"PERK_overclock_DESC": {
		"en": "+8% Attack Speed per level.",
		"fr": "+8% de vitesse d'attaque par niveau."
	},
	"PERK_chain_arc_bounces_NAME": {
		"en": "Chain Arc Subroutines",
		"fr": "Sous-routines d'Arc en Chaîne"
	},
	"PERK_chain_arc_bounces_DESC": {
		"en": "+1 Chain Lightning bounce per level.",
		"fr": "+1 rebond d'éclair en chaîne par niveau."
	},
	"PERK_elemental_mastery_NAME": {
		"en": "Elemental Mastery",
		"fr": "Maîtrise Élémentaire"
	},
	"PERK_elemental_mastery_DESC": {
		"en": "+20% Elemental Reaction damage per level.",
		"fr": "+20% de dégâts des réactions élémentaires par niveau."
	},
	"PERK_specialist_doctrine_NAME": {
		"en": "Specialist Doctrine",
		"fr": "Doctrine Spécialiste"
	},
	"PERK_specialist_doctrine_DESC": {
		"en": "+15% damage to all turrets when maintaining an active Resonance.",
		"fr": "+15% de dégâts à toutes les tourelles lors d'une résonance active."
	},
	"PERK_sensor_array_NAME": {
		"en": "Sensor Array",
		"fr": "Réseau de Capteurs"
	},
	"PERK_sensor_array_DESC": {
		"en": "+15% Tower Range per level.",
		"fr": "+15% de portée des tourelles par niveau."
	},
	"PERK_starting_capital_NAME": {
		"en": "Starting Capital",
		"fr": "Capital de Départ"
	},
	"PERK_starting_capital_DESC": {
		"en": "+50 starting Bits per level.",
		"fr": "+50 Bits de départ par niveau."
	},
	"PERK_discount_ammo_NAME": {
		"en": "Discount Ammo",
		"fr": "Munitions au Rabais"
	},
	"PERK_discount_ammo_DESC": {
		"en": "-1 Bit per Coin Gun cursor shot (min cost: 1).",
		"fr": "-1 Bit par tir du canon à curseur (coût min : 1)."
	},
	"PERK_bit_dividend_NAME": {
		"en": "Bit Dividend",
		"fr": "Dividende de Bits"
	},
	"PERK_bit_dividend_DESC": {
		"en": "+5% compound interest on unspent Bits per wave.",
		"fr": "+5% d'intérêts composés sur les Bits non dépensés par vague."
	},
	"PERK_reinforced_core_NAME": {
		"en": "Reinforced Core",
		"fr": "Cœur Renforcé"
	},
	"PERK_reinforced_core_DESC": {
		"en": "+25 Max Core HP per level.",
		"fr": "+25 PV Max du Cœur par niveau."
	},
	"PERK_cryo_frostbite_NAME": {
		"en": "Cryo Frostbite",
		"fr": "Engelure Cryo"
	},
	"PERK_cryo_frostbite_DESC": {
		"en": "+1.0s Freeze / Slow status duration per level.",
		"fr": "+1.0s de durée de gel / ralentissement par niveau."
	},
	"PERK_thermal_insulator_NAME": {
		"en": "Thermal Insulator",
		"fr": "Isolateur Thermique"
	},
	"PERK_thermal_insulator_DESC": {
		"en": "Core reactive shield shocks and ignites attackers on breach.",
		"fr": "Le bouclier réactif du Cœur électrocute et embrase les attaquants lors d'une brèche."
	},

	# --- Elemental Reactions & Resonances ---
	"REACTION_SUPERCONDUCT": {
		"en": "SUPERCONDUCT!",
		"fr": "SUPRACONDUCTION !"
	},
	"REACTION_MELT": {
		"en": "MELT x2.0!",
		"fr": "FONTE x2.0 !"
	},
	"REACTION_OVERLOAD": {
		"en": "OVERLOAD BLAST!",
		"fr": "EXPLOSION SURCHARGE !"
	},
	"RESONANCE_CRYO": {
		"en": "[PERMAFROST RESONANCE ACTIVE: +25% FREEZE & SLOW DURATION]",
		"fr": "[RÉSONANCE PERMAFROST ACTIVE : +25% DURÉE DE GEL ET RALENTISSEMENT]"
	},
	"RESONANCE_ELECTRO": {
		"en": "[HIGH VOLTAGE RESONANCE ACTIVE: +1 CHAIN ARC TARGET]",
		"fr": "[RÉSONANCE HAUTE TENSION ACTIVE : +1 CIBLE D'ARC EN CHAÎNE]"
	},
	"RESONANCE_PYRO": {
		"en": "[COMBUSTION RESONANCE ACTIVE: +30% MORTAR AOE RADIUS]",
		"fr": "[RÉSONANCE COMBUSTION ACTIVE : +30% RAYON D'EXPLOSION DU MORTIER]"
	},
	"RESONANCE_KINETIC": {
		"en": "[BALLISTIC SWARM RESONANCE ACTIVE: +20% ATTACK SPEED]",
		"fr": "[RÉSONANCE SALVE BALLISTIQUE ACTIVE : +20% VITESSE D'ATTAQUE]"
	}
}


func _ready() -> void:
	# Default to English if not explicitly set
	if current_lang.is_empty():
		current_lang = "en"
	TranslationServer.set_locale(current_lang)


func toggle_language() -> void:
	set_language("fr" if current_lang == "en" else "en")


func set_language(lang: String) -> void:
	if lang != "en" and lang != "fr":
		lang = "en"
	current_lang = lang
	TranslationServer.set_locale(lang)
	
	if SaveManager != null and is_instance_valid(SaveManager):
		SaveManager.language = lang
		SaveManager.save_game()
	
	language_changed.emit(lang)


func get_text(key: String, default_text: String = "") -> String:
	if TRANSLATIONS.has(key):
		var dict: Dictionary = TRANSLATIONS[key]
		if dict.has(current_lang):
			return dict[current_lang]
		elif dict.has("en"):
			return dict["en"]
	return default_text if not default_text.is_empty() else key


func get_card_name(card_id: String, default_name: String) -> String:
	return get_text("CARD_" + card_id + "_NAME", default_name)


func get_card_desc(card_id: String, default_desc: String) -> String:
	return get_text("CARD_" + card_id + "_DESC", default_desc)


func get_card_tag(tag: String) -> String:
	return get_text("CARD_TAG_" + tag.to_upper(), tag)


func get_perk_name(perk_id: String, default_name: String) -> String:
	return get_text("PERK_" + perk_id + "_NAME", default_name)


func get_perk_desc(perk_id: String, default_desc: String) -> String:
	return get_text("PERK_" + perk_id + "_DESC", default_desc)


func get_toggle_button_text() -> String:
	if current_lang == "fr":
		return "EN | [ FR ]"
	else:
		return "[ EN ] | FR"
