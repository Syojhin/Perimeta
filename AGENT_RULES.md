# Antigravity Agent Guidelines for Project Perimeta

- **Engine Version:** Godot 4.3+ GDScript.
- **Strict Typing:** Always use static typing for all variables, parameters, and return types (`var hp: float = 100.0`, `func fire(target: EnemyBase) -> void:`).
- **Modern Syntax Only:**
  - Use `@export`, `@onready`, `@icon` instead of deprecated Godot 3 syntax.
  - Never use `yield()`; always use `await`.
  - Use `PackedScene`, `Vector2`, `Callable`, and `Array[Type]` generics.
- **Architecture Guidelines:**
  - Keep systems decoupled using the `EventBus` singleton.
  - Store data models using custom Godot Resources (`.tres`) instead of raw dictionaries where possible.
  - Handle all entity cleanup with `queue_free()`.