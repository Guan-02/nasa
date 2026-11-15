extends "res://scripts/minijuegos/base.gd"
## MINIJUEGO 2: EVASIÓN DE MICROMETEORITOS Y BASURA ORBITAL
## Durante 10 segundos caen rocas por las columnas del radar. Una línea punteada
## marca por dónde va a pasar cada una. Mueve la nave casilla por casilla
## (flechas, WASD o la cruceta en pantalla) para esquivarlas.
## Cada movimiento enciende los propulsores RCS y gasta combustible:
## sin combustible ya no te puedes mover.

const VENTANA := Rect2(372, 148, 288, 274)
const REJILLA := Rect2(384, 176, 264, 168)
const COLS := 7
const FILAS := 5
const DURACION := 10.0
const PASO := 0.42            # segundos que tarda una roca en bajar una casilla
const COSTO_MOVIMIENTO := 2.5 # % de combustible por movimiento
const CRUCETA := Vector2(520, 384)

var col := 3
var fila := 4
var rocas := []
var reloj_rocas := 0.5
var cada := 0.55
var anticipacion := 1          # casillas de aviso antes de que una roca entre al radar
var retraso := 0.0             # segundos de retraso de los controles
var pendientes := []           # movimientos esperando (por el retraso)
var golpes := 0
var restante := DURACION
var flash := 0.0
var aviso_combustible := 0.0
var tex_nave: Texture2D
var tex_rocas := []


func iniciar() -> void:
	match nave:
		"gemini4":
			retraso = 0.2       # la Gemini responde con un pequeño retraso
			cada = 0.55
		"artemis2":
			anticipacion = 2    # el radar de Artemis predice 2 casillas antes
			cada = 0.5
		_:
			cada = 0.52
	var ruta: String = Mision.NAVES[nave].capsula_img
	tex_nave = load(ruta) if ResourceLoader.exists(ruta) else null
	for i in range(1, 9):
		var r := "res://assets/espacio/asteroides/asteroid-%d.png" % i
		if ResourceLoader.exists(r):
			tex_rocas.append(load(r))


func actualizar(delta: float) -> void:
	restante -= delta
	flash = max(flash - delta, 0.0)
	aviso_combustible = max(aviso_combustible - delta, 0.0)

	# Movimientos con retraso (Gemini)
	for p in pendientes.duplicate():
		p[1] -= delta
		if p[1] <= 0.0:
			pendientes.erase(p)
			_aplicar(p[0])

	# Nuevas rocas
	reloj_rocas -= delta
	if reloj_rocas <= 0.0 and restante > PASO * (FILAS + anticipacion):
		reloj_rocas = cada * randf_range(0.8, 1.2)
		var roca := {"col": randi() % COLS, "fila": -float(anticipacion) - 0.5, "tex": null, "pego": false, "giro": randf() * TAU}
		if not tex_rocas.is_empty():
			roca.tex = tex_rocas.pick_random()
		rocas.append(roca)

	# Mover rocas y revisar choques
	for r in rocas.duplicate():
		r.fila += delta / PASO
		r.giro += delta
		if not r.pego and r.col == col and absf(r.fila - fila) < 0.45:
			r.pego = true
			golpes += 1
			flash = 0.35
			viaje.casco -= viaje.dano_casco
			viaje.sacudir(0.35)
			if viaje.casco <= 0.0:
				viaje.casco = 0.0
				terminar(false)
				return
		if r.fila > FILAS + 0.5:
			rocas.erase(r)

	if restante <= 0.0:
		terminar(golpes == 0)


func _mover(direccion: Vector2i) -> void:
	if acabado:
		return
	if viaje.combustible < COSTO_MOVIMIENTO:
		aviso_combustible = 1.0
		return
	if retraso > 0.0:
		pendientes.append([direccion, retraso])
	else:
		_aplicar(direccion)


func _aplicar(direccion: Vector2i) -> void:
	var nueva_col: int = clamp(col + direccion.x, 0, COLS - 1)
	var nueva_fila: int = clamp(fila + direccion.y, 0, FILAS - 1)
	if nueva_col == col and nueva_fila == fila:
		return
	if viaje.combustible < COSTO_MOVIMIENTO:
		aviso_combustible = 1.0
		return
	col = nueva_col
	fila = nueva_fila
	viaje.combustible -= COSTO_MOVIMIENTO


func _input(event: InputEvent) -> void:
	if acabado or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_LEFT, KEY_A:
			_mover(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:
			_mover(Vector2i(1, 0))
		KEY_UP, KEY_W:
			_mover(Vector2i(0, -1))
		KEY_DOWN, KEY_S:
			_mover(Vector2i(0, 1))


func _gui_input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dirs := {Vector2i(0, -1): Vector2(0, -22), Vector2i(0, 1): Vector2(0, 22),
			Vector2i(-1, 0): Vector2(-26, 0), Vector2i(1, 0): Vector2(26, 0)}
		for d in dirs:
			var c: Vector2 = CRUCETA + dirs[d]
			if R(c.x - 10, c.y - 9, 20, 18).has_point(event.position):
				_mover(d)
				return


# ================= Dibujo =================

func _celda(c: float, f: float) -> Rect2:
	var w := REJILLA.size.x / COLS
	var h := REJILLA.size.y / FILAS
	return R(REJILLA.position.x + c * w, REJILLA.position.y + f * h, w, h)


func _draw() -> void:
	# Letrero de alerta arriba
	var banner := R(258, 6, 518, 42)
	draw_rect(banner.grow(2 * k), C_OSCURO)
	draw_rect(banner, Color("2a0d0b"))
	draw_rect(banner, Color("ff7a3d") if fmod(tiempo, 0.6) < 0.35 else Color("8a2a14"), false, 2.0 * k)
	texto_centrado(banner, 24 * k, "¡ALERTA: CAMBIO DE CURSO!", 13, C_ROJO)
	texto_centrado(banner, 41 * k, "SELECCIONE EL VECTOR DE EVASIÓN", 11, C_AMBAR)

	# Ventana gris
	var v := RR(VENTANA)
	draw_rect(v.grow(3 * k), C_OSCURO)
	draw_rect(v, Color("a8adb3"))
	draw_rect(R(VENTANA.position.x, VENTANA.position.y, VENTANA.size.x, 22), Color("7c8288"))
	texto(P(380, 164), "SYSTEM: ASTEROID EVASION", 10, Color("1c1f24"))
	var x_cerrar := R(642, 152, 14, 14)
	draw_rect(x_cerrar, Color("5d636b"), false, 1.5 * k)
	texto(P(645, 164), "X", 10, Color("1c1f24"))

	# Radar
	var rej := RR(REJILLA)
	draw_rect(rej.grow(2 * k), C_OSCURO)
	draw_rect(rej, Color("0f1a24"))
	for c in range(1, COLS):
		var x := rej.position.x + rej.size.x * c / COLS
		draw_line(Vector2(x, rej.position.y), Vector2(x, rej.end.y), Color(0.3, 0.75, 0.75, 0.35), 1.0)
	for f in range(1, FILAS):
		var y := rej.position.y + rej.size.y * f / FILAS
		draw_line(Vector2(rej.position.x, y), Vector2(rej.end.x, y), Color(0.3, 0.75, 0.75, 0.35), 1.0)

	# Rocas: línea punteada de su trayectoria + la roca
	for r in rocas:
		var celda := _celda(r.col, max(r.fila, 0.0))
		var x_centro := celda.get_center().x
		var y_desde: float = max(rej.position.y, celda.get_center().y)
		var y := y_desde
		while y < rej.end.y:
			draw_line(Vector2(x_centro, y), Vector2(x_centro, min(y + 4 * k, rej.end.y)), Color(1, 0.6, 0.4, 0.35), 1.5 * k)
			y += 9 * k
		if r.fila < -0.3:
			# Todavía no entra: flechita de aviso arriba del radar
			var punta := Vector2(x_centro, rej.position.y + 9 * k)
			draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(-6, -8) * k, punta + Vector2(6, -8) * k]),
				Color(1, 0.35, 0.25, 0.6 + 0.4 * sin(tiempo * 14.0)))
		else:
			var rc := _celda(r.col, r.fila)
			var tam := rc.size.y * 0.9
			var cent := rc.get_center()
			if r.tex != null:
				draw_set_transform(cent, r.giro, Vector2.ONE)
				draw_texture_rect(r.tex, Rect2(-tam * 0.5, -tam * 0.5, tam, tam), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(cent, tam * 0.4, Color("7a5a3a"))

	# Nave
	var cn := _celda(col, fila)
	var cc := cn.get_center()
	if tex_nave != null:
		var tam_n := cn.size.y * 0.85
		var esc := tam_n / tex_nave.get_size().y
		var tn := tex_nave.get_size() * esc
		draw_texture_rect(tex_nave, Rect2(cc - tn * 0.5, tn), false, Color(1, 0.6, 0.6) if flash > 0.0 else Color.WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -10) * k, cc + Vector2(-7, 8) * k, cc + Vector2(7, 8) * k]), Color.WHITE)
	# Esquinas verdes alrededor de la nave
	var g := Color(0.37, 0.89, 0.42)
	var l := 6.0 * k
	for esq in [cn.position, Vector2(cn.end.x, cn.position.y), Vector2(cn.position.x, cn.end.y), cn.end]:
		var sx := 1.0 if esq.x == cn.position.x else -1.0
		var sy := 1.0 if esq.y == cn.position.y else -1.0
		draw_line(esq, esq + Vector2(l * sx, 0), g, 1.5 * k)
		draw_line(esq, esq + Vector2(0, l * sy), g, 1.5 * k)

	if flash > 0.0:
		draw_rect(rej, Color(1, 0.2, 0.1, flash))

	# Abajo: joystick, cruceta, tiempo y combustible
	var joy := R(386, 356, 40, 40)
	draw_rect(joy, Color("7c8288"))
	draw_rect(joy, C_OSCURO, false, 1.5 * k)
	draw_line(P(406, 386), P(406, 368), C_OSCURO, 3 * k)
	draw_circle(P(406, 366), 5 * k, C_OSCURO)
	draw_rect(R(396, 386, 20, 6), C_OSCURO)

	var dirs := [Vector2(0, -22), Vector2(0, 22), Vector2(-26, 0), Vector2(26, 0)]
	var flechas := ["^", "v", "<", ">"]
	for i in 4:
		var c: Vector2 = CRUCETA + dirs[i]
		var b := R(c.x - 10, c.y - 9, 20, 18)
		draw_rect(b, Color("5d8a7a"))
		draw_rect(b, C_OSCURO, false, 1.5 * k)
		texto(b.position + Vector2(b.size.x * 0.32, b.size.y * 0.8), flechas[i], 10, C_TEXTO)
	draw_circle(PV(CRUCETA), 4 * k, Color("5d8a7a"))

	texto(P(572, 372), "%.1f s" % max(restante, 0.0), 12, Color("1c1f24"))
	var comb: float = viaje.combustible
	texto(P(572, 390), "FUEL %d%%" % int(comb), 10, C_ROJO if comb < 15.0 else Color("1c1f24"))
	if retraso > 0.0:
		texto(P(572, 406), "RETRASO 0.2s", 8, Color("8a2a14"))
	if aviso_combustible > 0.0:
		texto_centrado(rej, rej.get_center().y, "¡SIN COMBUSTIBLE RCS!", 13, C_ROJO)
