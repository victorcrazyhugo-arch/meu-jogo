class_name Save
extends RefCounted
## Salvamento local versionado com gravacao segura (arquivo temporario + copia de
## recuperacao) e migracao entre versoes. Multiplos mundos em user://mundos/<slot>/.

const DIR := "user://mundos"


static func slot_dir(slot: String) -> String:
	return "%s/%s" % [DIR, slot]


static func _write_var(path: String, data: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data)
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	return ok


static func _read_var(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 8:
		return null
	var d = f.get_var()
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("v"):
		return null
	return d


## Grava em arquivo temporario, confere a leitura e so entao substitui o save anterior,
## que passa a ser a copia de recuperacao.
static func write(slot: String, data: Dictionary, meta: Dictionary) -> bool:
	var dir := slot_dir(slot)
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := dir + "/save.tmp"
	var cur := dir + "/save.dat"
	var bak := dir + "/save.bak"
	if not _write_var(tmp, data):
		return false
	var chk = _read_var(tmp)
	if chk == null or int(chk.get("v", -1)) != int(data["v"]):
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(cur):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(cur, bak)
	var err := DirAccess.rename_absolute(tmp, cur)
	if err != OK:
		# restaura o anterior se a troca falhar
		if FileAccess.file_exists(bak) and not FileAccess.file_exists(cur):
			DirAccess.rename_absolute(bak, cur)
		return false
	_write_var(dir + "/meta.dat", meta)
	return true


## Le o save; se estiver corrompido, usa a copia de recuperacao.
static func read(slot: String) -> Dictionary:
	var dir := slot_dir(slot)
	var d = _read_var(dir + "/save.dat")
	var from_backup := false
	if d == null:
		d = _read_var(dir + "/save.bak")
		from_backup = d != null
	if d == null:
		# gravacao interrompida depois de remover o atual: o temporario pode estar integro
		d = _read_var(dir + "/save.tmp")
		from_backup = d != null
	if d == null:
		return {}
	d = migrate(d)
	d["_from_backup"] = from_backup
	return d


static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("v", 0))
	# v0 -> v1: primeiros prototipos nao tinham clima nem marcadores de mapa
	if v < 1:
		if not d.has("env"):
			d["env"] = {}
		if not d.has("ui"):
			d["ui"] = {}
		v = 1
	d["v"] = v
	# propriedades novas recebem valores padrao sem apagar as existentes
	var sb: Dictionary = d.get("sandbox", {})
	for k in G.SANDBOX_DEFAULT:
		if not sb.has(k):
			sb[k] = G.SANDBOX_DEFAULT[k]
	d["sandbox"] = sb
	return d


static func list() -> Array:
	var out: Array = []
	var da := DirAccess.open(DIR)
	if da == null:
		return out
	for s in da.get_directories():
		var m = null
		var mp := "%s/%s/meta.dat" % [DIR, s]
		if FileAccess.file_exists(mp):
			var f := FileAccess.open(mp, FileAccess.READ)
			if f != null:
				m = f.get_var()
				f.close()
		if typeof(m) != TYPE_DICTIONARY:
			if not FileAccess.file_exists("%s/%s/save.dat" % [DIR, s]) and not FileAccess.file_exists("%s/%s/save.bak" % [DIR, s]):
				continue
			m = {"name": s}
		m["slot"] = s
		out.append(m)
	out.sort_custom(func(a, b): return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0)))
	return out


static func delete(slot: String) -> void:
	var dir := slot_dir(slot)
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(dir)


static func new_slot() -> String:
	var i := 1
	while DirAccess.dir_exists_absolute(slot_dir("mundo%d" % i)):
		i += 1
	return "mundo%d" % i
