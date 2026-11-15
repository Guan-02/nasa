extends "res://scripts/minijuegos/base.gd"
## MINIJUEGO 4: PURGA DE LA COMPUTADORA DE NAVEGACIÓN — ALARMA "1202"
## La computadora está saturada. Los procesos basura (ámbar: RADAR_ECHO,
## DIAG_DUMP, TEMP_LOG) se multiplican y llenan el CPU.
## Tienes 8 segundos para darles clic ([KILL]) hasta bajar el CPU de 50 %.
## ¡Cuidado! Si eliminas un sistema vital (verde) hay castigo:
##   LIFE_SUPP -> baja el oxígeno | NAV_CORE -> te desvías de la ruta | TELEMETRY -> pierdes datos
## En Artemis II la interferencia cósmica revuelve los nombres y quita los colores.

const CRT := Rect2(366, 196, 512, 228)
const VITALES := ["LIFE_SUPP", "NAV_CORE", "TELEMETRY"]
const BASURA := ["RADAR_ECHO", "DIAG_DUMP", "TEMP_LOG"]
const COLUMNAS := 4
const LIMITE := 8.0
const CPU_BASE := 20.0
const CPU_POR_BASURA := 15.0

var ranuras := []          # 8 lugares: {"nombre", "vital"} o null
var restante := LIMITE
var reloj_basura := 1.0
var cada := 1.1
var revuelto := false
var nombres_revueltos := {}
var reloj_revuelto := 0.0
var destello := {}         # ranura -> [tiempo, color]
var mensaje := ""
var reloj_mensaje := 0.0


func iniciar() -> void:
	revuelto = nave == "artemis2"
	cada = 0.9 if revuelto else 1.1
	ranuras.resize(8)
	var lugares := range(8)
	lugares.shuffle()
	for i in 3:
		ranuras[lugares[i]] = {"nombre": VITALES[i], "vital": true}
	for i in range(3, 8):
		ranuras[lugares[i]] = {"nombre": BASURA.pick_random(), "vital": false}


func _cpu() -> float:
	var basura := 0
	for r in ranuras:
		if r != null and not r.vital:
			basura += 1
	return CPU_BASE + basura * CPU_POR_BASURA


func actualizar(delta: float) -> void:
	restante -= delta
	reloj_mensaje = max(reloj_mensaje - delta, 0.0)
	for i in destello.keys():
		destello[i][0] -= delta
		if destello[i][0] <= 0.0:
			destello.erase(i)

	# Los procesos basura se multiplican
	reloj_basura -= delta
	if reloj_basura <= 0.0:
		reloj_basura = cada
		var libres := []
		for i in 8:
			if ranuras[i] == null:
				libres.append(i)
		if not libres.is_empty():
			ranuras[libres.pick_random()] = {"nombre": BASURA.pick_random(), "vital": false}

	if revuelto:
		reloj_revuelto -= delta
		if reloj_revuelto <= 0.0:
			reloj_revuelto = 0.35
			nombres_revueltos.clear()
			for i in 8:
				if ranuras[i] != null:
					nombres_revueltos[i] = _revolver(ranuras[i].nombre)

	if _cpu() < 50.0:
		terminar(true)
	elif restante <= 0.0:
		terminar(false)


## Cambia 2 letras al azar por símbolos (interferencia de la radiación)
func _revolver(nombre: String) -> String:
	var s := nombre
	var simbolos := "#%&?@$*"
	for n in 2:
		var i := randi() % s.length()
		if s[i] != "_":
			s = s.substr(0, i) + simbolos[randi() % simbolos.length()] + s.substr(i + 1)
	return s


func _rect_ranura(i: int) -> Rect2:
	var c := i % COLUMNAS
	var f := i / COLUMNAS
	return R(CRT.position.x + 14 + c * 122, CRT.position.y + 72 + f * 64, 114, 54)


func _matar(i: int) -> void:
	var r = ranuras[i]
	if r == null:
		return
	if r.vital:
		destello[i] = [0.5, C_ROJO]
		mensaje = "¡ESE ERA UN SISTEMA VITAL!"
		reloj_mensaje = 1.2
		match String(r.nombre):
			"LIFE_SUPP":
				viaje.oxigeno = max(viaje.oxigeno - 15.0, 0.0)
			"NAV_CORE":
				viaje.progreso = max(viaje.progreso - 0.03, 0.0)
			"TELEMETRY":
				viaje.datos = max(viaje.datos - 60.0, 0.0)
		viaje.sacudir(0.2)
	else:
		destello[i] = [0.3, C_VERDE]
		ranuras[i] = null


func _gui_input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 8:
			if _rect_ranura(i).has_point(event.position):
				_matar(i)
				return


func _input(event: InputEvent) -> void:
	if acabado or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var n: int = event.physical_keycode - KEY_1
	if n >= 0 and n < 8:
		_matar(n)


# ================= Dibujo =================

func _draw() -> void:
	var crt := RR(CRT)
	placa(crt.grow(8 * k), Color("4a4f55"))
	draw_rect(crt, Color("04140a"))
	var verde := Color("6dff8a")

	texto(crt.position + Vector2(12, 20) * k, "PGNCS  ALARMA 1202 — EXECUTIVE OVERFLOW", 12, C_ROJO if fmod(tiempo, 0.5) < 0.3 else verde)

	# Barra de CPU
	var cpu := _cpu()
	var barra := R(CRT.position.x + 12, CRT.position.y + 30, CRT.size.x - 24, 26)
	draw_rect(barra, Color("0b2614"))
	var c_cpu := C_ROJO if cpu >= 80.0 else (C_AMBAR if cpu >= 50.0 else verde)
	if cpu >= 80.0 and fmod(tiempo, 0.4) < 0.2:
		c_cpu = Color("7a1a14")
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * clamp(cpu / 100.0, 0.0, 1.0), barra.size.y)), c_cpu)
	draw_line(Vector2(barra.position.x + barra.size.x * 0.5, barra.position.y - 3 * k), Vector2(barra.position.x + barra.size.x * 0.5, barra.end.y + 3 * k), Color.WHITE, 2 * k)
	texto(barra.position + Vector2(8, 18) * k, "CPU OVERLOAD: %d%%   (meta: menos de 50%%)" % int(cpu), 11, Color.WHITE)

	# Procesos
	for i in 8:
		var r := _rect_ranura(i)
		var p = ranuras[i]
		if p == null:
			draw_rect(r, Color("06200f"))
			draw_rect(r, Color(0.43, 1, 0.54, 0.2), false, 1.0 * k)
			texto(r.position + Vector2(8, 32) * k, "[ LIBRE ]", 9, Color(0.43, 1, 0.54, 0.35))
			continue
		var color := verde if p.vital else C_AMBAR
		if revuelto:
			color = Color("9fd8a8")   # la interferencia no deja ver colores
		draw_rect(r, Color(color, 0.18))
		draw_rect(r, color, false, 2.0 * k)
		var nombre: String = nombres_revueltos.get(i, p.nombre) if revuelto else String(p.nombre)
		texto(r.position + Vector2(8, 22) * k, nombre, 11, color)
		texto(r.position + Vector2(8, 44) * k, "%d  [KILL]" % (i + 1), 10, Color(color, 0.8))
		if destello.has(i):
			draw_rect(r, Color(destello[i][1], 0.5))

	# Pie
	texto(crt.position + Vector2(12, crt.size.y / k - 10) * k, "TIEMPO: %.1f s   |   clic o teclas 1-8 para purgar" % max(restante, 0.0), 10, verde)
	if reloj_mensaje > 0.0:
		texto_centrado(crt, crt.get_center().y + 8 * k, mensaje, 15, C_ROJO)

	# Líneas de monitor viejo
	var y := crt.position.y
	while y < crt.end.y:
		draw_line(Vector2(crt.position.x, y), Vector2(crt.end.x, y), Color(0, 0, 0, 0.18), 1.0)
		y += 3.0 * k
