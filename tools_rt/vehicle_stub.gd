extends Node3D
## Substituto vazio do gerenciador de veiculos (usado apenas se o modulo real faltar).
func chunk_loaded(_k: Vector2i) -> void:
	pass
func chunk_unloaded(_k: Vector2i) -> void:
	pass
func targets_near(_p: Vector3, _out: Array) -> void:
	pass
func nearest(_p: Vector3, _r: float) -> Variant:
	return null
func to_dict() -> Dictionary:
	return {}
func from_dict(_d: Dictionary) -> void:
	pass
