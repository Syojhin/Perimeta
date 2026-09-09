class_name HazardChevrons
extends Control

## Procedural diagonal hazard chevrons for Overclock-rarity card headers.

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0 or h <= 0:
		return
		
	var stripe_w: float = 14.0
	var x: float = -h
	var is_gold: bool = true
	while x < w + h + stripe_w:
		var col: Color = Color(1.0, 0.84, 0.0, 0.85) if is_gold else Color(0.1, 0.08, 0.02, 0.9)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x, 0),
			Vector2(x + stripe_w, 0),
			Vector2(x + stripe_w - h, h),
			Vector2(x - h, h)
		])
		draw_colored_polygon(pts, col)
		x += stripe_w
		is_gold = not is_gold
