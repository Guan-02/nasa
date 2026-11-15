extends "res://scripts/minijuegos/base.gd"
## MINIJUEGO 1: ESTABILIZAR VÁLVULAS DE O2 Y COMBUSTIBLE
## Las agujas de los 3 relojes suben hacia el rojo y el oxígeno baja.
## Elige una válvula (1, 2, 3 con clic o teclado) y gira el REGULADOR DE FLUJO
## (A/D, flechas o arrastrando el mouse en círculo) para regresar la aguja al verde.
## Cuando una aguja se queda un momento en verde, esa válvula queda asegurada.
## Hay que asegurar las 3 antes de que el oxígeno llegue a 0 %.

const VERDE_MIN := 0.40
const VERDE_MAX := 0.58
const ROJO := 0.80
const SEGUNDOS_PARA_ASEGURAR := 0.8

const PANEL := Rect2(205, 126, 230, 322)
const RELOJES := [Vector2(246, 206), Vector2(320, 206), Vector2(394, 206)]
const RADIO_RELOJ := 30.0
const BOTONES_Y := 246.0
const VOLANTE := Vector2(320, 368)
const RADIO_VOLANTE := 44.0

var agujas := [0.5, 0.5, 0.5]
var activas := [false, false, false]     # ya falló
var seguras := [false, false, false]     # ya se aseguró
var en_verde := [0.0, 0.0, 0.0]
var elegida := 0
var giro := 0.0
var deriva := 0.07
var siguiente_falla := 3.0
var arrastrando := false
var angulo_anterior := 0.0


func iniciar() -> void:
	match nave:
		"gemini4":
			deriva = 0.10   # la Gemini es vieja: las agujas suben rápido
		"artemis2":
			deriva = 0.05   # Artemis casi nunca falla... pero fallan las 3 juntas
		_:
			deriva = 0.07
	if nave == "artemis2":
		for i in 3:
			_desestabilizar(i)
	else:
		var i := randi() % 3
		_desestabilizar(i)
		elegida = i


func _desestabilizar(i: int) -> void:
	activas[i] = true
	agujas[i] = randf_range(0.64, 0.76)


func actualizar(delta: float) -> void:
	# Las demás válvulas van fallando una por una
	if nave != "artemis2":
		siguiente_falla -= delta
		if siguiente_falla <= 0.0:
			var libres := []
			for i in 3:
				if not activas[i]:
					libres.append(i)
			if not libres.is_empty():
				_desestabilizar(libres.pick_random())
			siguiente_falla = 2.0 if nave == "gemini4" else 3.0

	var inestables := 0
	for i in 3:
		if not activas[i] or seguras[i]:
			continue
		agujas[i] = clamp(float(agujas[i]) + deriva * delta + randf_range(-0.004, 0.004), 0.0, 1.0)
		if agujas[i] >= VERDE_MIN and agujas[i] <= VERDE_MAX:
			en_verde[i] = float(en_verde[i]) + delta
			if en_verde[i] >= SEGUNDOS_PARA_ASEGURAR:
				seguras[i] = true
				_elegir_siguiente()
		else:
			en_verde[i] = 0.0
		if not seguras[i]:
			inestables += 1

	# Girar con el teclado
	var lado := 0.0
	if tecla(KEY_A) or Input.is_action_pressed("ui_left"):
		lado -= 1.0
	if tecla(KEY_D) or Input.is_action_pressed("ui_right"):
		lado += 1.0
	if lado != 0.0:
		_girar(lado * 2.6 * delta)

	viaje.oxigeno -= (1.0 + inestables * 1.6) * viaje.mult_oxigeno * delta

	if seguras[0] and seguras[1] and seguras[2]:
		terminar(true)
	elif viaje.oxigeno <= 0.0:
		viaje.oxigeno = 0.0
		terminar(false)


func _elegir_siguiente() -> void:
	for i in 3:
		if activas[i] and not seguras[i]:
			elegida = i
			return


func _girar(angulo: float) -> void:
	giro += angulo
	var i := elegida
	if activas[i] and not seguras[i]:
		agujas[i] = clamp(float(agujas[i]) + angulo * 0.12, 0.0, 1.0)


func _rect_boton(i: int) -> Rect2:
	return R(RELOJES[i].x - 13, BOTONES_Y, 26, 22)


func _input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				elegida = 0
			KEY_2:
				elegida = 1
			KEY_3:
				elegida = 2


func _gui_input(event: InputEvent) -> void:
	if acabado:
		return
	var centro := PV(VOLANTE)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in 3:
				if _rect_boton(i).has_point(event.position) or PV(RELOJES[i]).distance_to(event.position) < RADIO_RELOJ * k:
					elegida = i
					return
			if centro.distance_to(event.position) < RADIO_VOLANTE * k * 1.4:
				arrastrando = true
				angulo_anterior = (event.position - centro).angle()
		else:
			arrastrando = false
	elif event is InputEventMouseMotion and arrastrando:
		var a: float = (event.position - centro).angle()
		_girar(wrapf(a - angulo_anterior, -PI, PI))
		angulo_anterior = a


# ================= Dibujo =================

func _draw() -> void:
	var panel := RR(PANEL)
	placa(panel, Color("6a6458"))
	# Encabezado
	var cab := R(214, 134, 212, 40)
	pantallita(cab)
	texto(P(220, 151), "¡FALLA CRÍTICA!", 11, C_ROJO)
	texto(P(220, 166), "ESTABILIZAR O2/COMBUSTIBLE", 10, C_TEXTO)

	for i in 3:
		_dibujar_reloj(i)
		_dibujar_boton(i)

	texto_centrado(panel, 297 * k, "REGULADOR DE FLUJO", 9, C_TEXTO)
	_dibujar_volante()

	# Pie: oxígeno e instrucciones
	var pie := R(214, 418, 212, 24)
	pantallita(pie, Color("170707"))
	var ox: float = viaje.oxigeno
	texto(P(220, 434), "O2: %d%%" % int(ox), 11, C_ROJO if ox < 35.0 else C_AMBAR)
	texto(P(290, 434), "1-2-3 elegir | A/D girar", 9, C_AMBAR)


func _dibujar_reloj(i: int) -> void:
	var c := PV(RELOJES[i])
	var r := RADIO_RELOJ * k
	var a0 := deg_to_rad(150.0)
	var a1 := deg_to_rad(390.0)
	if seguras[i]:
		draw_circle(c, r + 7.0 * k, Color(0.37, 0.89, 0.42, 0.45))
	elif activas[i] and agujas[i] >= ROJO:
		draw_circle(c, r + 7.0 * k, Color(1, 0.29, 0.24, 0.25 + 0.25 * sin(tiempo * 12.0)))
	draw_circle(c, r + 2.0 * k, C_OSCURO)
	draw_circle(c, r, Color("d9d6cc"))
	# Franjas verde y roja
	draw_arc(c, r * 0.78, lerp(a0, a1, VERDE_MIN), lerp(a0, a1, VERDE_MAX), 12, Color("3cb44b"), 7.0 * k)
	draw_arc(c, r * 0.78, lerp(a0, a1, ROJO), a1, 12, Color("e5383b"), 7.0 * k)
	# Marcas
	for m in 9:
		var am: float = lerp(a0, a1, m / 8.0)
		draw_line(c + Vector2.from_angle(am) * r * 0.9, c + Vector2.from_angle(am) * r * 0.98, C_OSCURO, 1.5 * k)
	# Aguja (vibra si está inestable)
	var v: float = agujas[i]
	if activas[i] and not seguras[i]:
		v += sin(tiempo * 40.0 + i) * 0.008
	var ang: float = lerp(a0, a1, v)
	draw_line(c, c + Vector2.from_angle(ang) * r * 0.82, Color("8b0000"), 2.5 * k)
	draw_circle(c, 3.0 * k, C_OSCURO)


func _dibujar_boton(i: int) -> void:
	var b := _rect_boton(i)
	draw_rect(b.grow(1.5 * k), C_OSCURO)
	draw_rect(b, Color("4a4740") if elegida != i else Color("7a6f5a"))
	texto(b.position + Vector2(b.size.x * 0.32, b.size.y * 0.78), str(i + 1), 13, C_TEXTO)
	# Luz debajo
	var luz := b.position + Vector2(b.size.x * 0.5, b.size.y + 7.0 * k)
	var color := Color(0.25, 0.25, 0.25)
	if seguras[i]:
		color = C_VERDE
	elif elegida == i:
		color = C_ROJO if fmod(tiempo, 0.5) < 0.3 else Color("7a1a14")
	draw_circle(luz, 3.5 * k, color)


func _dibujar_volante() -> void:
	var c := PV(VOLANTE)
	var r := RADIO_VOLANTE * k
	draw_circle(c, r + 3.0 * k, C_OSCURO)
	draw_arc(c, r, 0, TAU, 40, Color("9aa0a6"), 8.0 * k)
	draw_arc(c, r, 0, TAU, 40, Color("c8ccd0"), 2.0 * k)
	for s in 4:
		var a := giro + s * PI * 0.5
		draw_line(c, c + Vector2.from_angle(a) * r, Color("7d8389"), 5.0 * k)
	# Manija roja
	draw_circle(c + Vector2.from_angle(giro) * r, 6.0 * k, Color("c0392b"))
	draw_circle(c, 9.0 * k, Color("c0392b"))
	draw_circle(c, 4.0 * k, C_OSCURO)
	if arrastrando or tecla(KEY_A) or tecla(KEY_D):
		draw_arc(c, r + 8.0 * k, giro - 0.6, giro + 0.6, 10, C_AMBAR, 2.0 * k)
