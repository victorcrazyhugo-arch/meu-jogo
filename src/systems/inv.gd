class_name Inv
extends RefCounted
## Inventario do personagem: itens carregados, roupas vestidas e armas equipadas.

var items: Array = []          # itens carregados
var worn: Dictionary = {}      # slot -> item de vestuario
var primary = null             # item nas maos (Dictionary) ou null
var secondary = null           # item nas costas / cintura
var favorites: Dictionary = {} # id -> true


## Adiciona a uma lista respeitando empilhamento.
static func add_to(list: Array, it: Dictionary) -> void:
	var d := Items.def(it["id"])
	var mx: int = int(d.get("st", 1))
	if mx > 1:
		for o in list:
			if int(o["n"]) < mx and Items.can_stack(o, it):
				var mv: int = mini(mx - int(o["n"]), int(it["n"]))
				o["n"] = int(o["n"]) + mv
				it["n"] = int(it["n"]) - mv
				if int(it["n"]) <= 0:
					return
		while int(it["n"]) > mx:
			var part := it.duplicate(true)
			part["n"] = mx
			it["n"] = int(it["n"]) - mx
			list.append(part)
	if int(it["n"]) > 0:
		list.append(it)


static func count_in(list: Array, id: String) -> int:
	var c := 0
	for o in list:
		if o["id"] == id:
			c += int(o["n"])
	return c


## Remove n unidades; retorna quantas removeu.
static func remove_from(list: Array, id: String, n: int) -> int:
	var left := n
	var i := list.size() - 1
	while i >= 0 and left > 0:
		var o: Dictionary = list[i]
		if o["id"] == id:
			var t: int = mini(int(o["n"]), left)
			o["n"] = int(o["n"]) - t
			left -= t
			if int(o["n"]) <= 0:
				list.remove_at(i)
		i -= 1
	return n - left


static func weight_of_list(list: Array) -> float:
	var w := 0.0
	for o in list:
		w += Items.weight_of(o)
	return w


func add(it: Dictionary) -> void:
	add_to(items, it)


func count(id: String) -> int:
	return count_in(items, id)


func remove(id: String, n: int = 1) -> int:
	return remove_from(items, id, n)


func remove_item(it: Dictionary) -> void:
	var i := items.find(it)
	if i >= 0:
		items.remove_at(i)


func weight() -> float:
	var w := weight_of_list(items)
	for s in worn:
		w += Items.weight_of(worn[s]) * 0.3
	if primary != null:
		w += Items.weight_of(primary) * 0.3
	if secondary != null:
		w += Items.weight_of(secondary) * 0.5
	return w


func capacity(sv: Survivor) -> float:
	var c := 8.0 + float(sv.level("forca") - 5) * 1.0
	if sv.has("magro"):
		c -= 1.0
	if worn.has("bag"):
		var d := Items.def(worn["bag"]["id"])
		c += float(d.get("bagcap", 0.0)) * float(d.get("red", 0.5))
	if worn.has("holster"):
		c += 0.5
	return maxf(c, 3.0)


## Primeiro item com a etiqueta de ferramenta (inclui armas equipadas).
func find_tag(tag: String):
	if primary != null and Items.has_tag(primary, tag):
		return primary
	if secondary != null and Items.has_tag(secondary, tag):
		return secondary
	for o in items:
		if Items.has_tag(o, tag):
			return o
	return null


func has_tag(tag: String) -> bool:
	return find_tag(tag) != null


func find(id: String):
	for o in items:
		if o["id"] == id:
			return o
	return null


## Recipiente carregado com liquido do tipo dado e quantidade minima.
func find_liquid(lt: String, min_l: float = 0.01):
	for o in items:
		if o.has("liq") and o.get("lt", "") == lt and float(o["liq"]) >= min_l:
			return o
	return null


func total_liquid(lt: String) -> float:
	var t := 0.0
	for o in items:
		if o.has("liq") and o.get("lt", "") == lt:
			t += float(o["liq"])
	return t


## Consome liquido de varios recipientes; retorna quanto foi consumido.
func use_liquid(lt: String, amount: float) -> float:
	var left := amount
	for o in items:
		if left <= 0.0:
			break
		if o.has("liq") and o.get("lt", "") == lt and float(o["liq"]) > 0.0:
			var t: float = minf(float(o["liq"]), left)
			o["liq"] = float(o["liq"]) - t
			left -= t
			if float(o["liq"]) <= 0.001:
				o["liq"] = 0.0
				o["lt"] = ""
	return amount - left


## Usa uma carga de um item com usos; remove quando acabar.
func use_charge(it: Dictionary) -> void:
	if it.has("u"):
		it["u"] = int(it["u"]) - 1
		if int(it["u"]) <= 0:
			remove_item(it)
	else:
		it["n"] = int(it["n"]) - 1
		if int(it["n"]) <= 0:
			remove_item(it)


func to_dict() -> Dictionary:
	return {"items": items, "worn": worn, "primary": primary, "secondary": secondary, "favorites": favorites}


func from_dict(d: Dictionary) -> void:
	items = d.get("items", [])
	worn = d.get("worn", {})
	primary = d.get("primary", null)
	secondary = d.get("secondary", null)
	favorites = d.get("favorites", {})
