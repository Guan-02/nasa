extends "res://scripts/minijuegos/base.gd"
## MINIJUEGO 5: SINTONIZACIÓN DE LA ANTENA DE ALTA GANANCIA
## Mientras más lejos de la Tierra, más débil llega la señal.
## Ajusta la onda verde (tu nave) hasta que quede encima de la azul (la Tierra):
##   W/S (o flechas arriba/abajo, o arrastrar la perilla FRECUENCIA) -> frecuencia
##   A/D (o flechas izquierda/derecha, o arrastrar la perilla ÁNGULO) -> ángulo
## Cuando coinciden se ponen doradas: mantenlas así 2 segundos.
## Mientras la antena esté desalineada no se juntan datos científicos.

const PANEL := Rect2(448, 280, 350, 196)
const PANTALLA := Rect2(460, 306, 236, 132)
const PERILLA_FREC := Vector2(748, 340)
const PERILLA_ANG := Vector2(748, 414)
const RADIO_PERILLA := 22.0
const LIMITE := 25.0
const SOSTENER := 2.0

var frec_meta := 3.0
var fase_meta := 0.0
var frec := 1.5
var fase := 0.0
var tolerancia := 0.15
var sostenido := 0.0
var restante := LIMITE
var arrastrando := ""        # "frec", "ang" o ""
var mouse_anterior := Vector2.ZERO


func iniciar() -> void:
	frec_meta = randf_range(1.8, 4.2)
	fase_meta = randf_range(0.0, TAU)
	frec = clamp(frec_meta + randf_range(1.0, 1.8) * (1.0 if randf() < 0.5 else -1.0), 1.0, 5.0)
	fase = wrapf(fase_meta + randf_range(1.2, 2.6), 0.0, TAU)
	# Mejores comunicaciones = más fácil alinear
	tolerancia = 0.10 + Mision.valor(nave, "comunicaciones") / 1000.0


func _error() -> float:
	return absf(frec - frec_meta) / 3.0 + absf(wrapf(fase - fase_meta, -PI, PI)) / PI


func _alineada() -> bool:
	return _error() < tolerancia


func actualizar(delta: float) -> void:
	restante -= delta
	var arriba := tecla(KEY_W) or Input.is_action_pressed("ui_up")
	var abajo := tecla(KEY_S) or Input.is_action_pressed("ui_down")
	var izq := tecla(KEY_A) or Input.is_action_pressed("ui_left")
	var der := tecla(KEY_D) or Input.is_action_pressed("ui_right")
	if arriba:
		frec = min(frec + 1.0 * delta, 5.0)
	if abajo:
		frec = max(frec - 1.0 * delta, 1.0)
	if der:
		fase = wrapf(fase + 1.6 * delta, 0.0, TAU)
	if izq:
		fase = wrapf(fase - 1.6 * delta, 0.0, TAU)

	if _alineada():
		sostenido += delta
		if sostenido >= SOSTENER:
			terminar(true)
	else:
		sostenido = 0.0
	if restante <= 0.0 and not acabado:
		terminar(false)


func _gui_input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if PV(PERILLA_FREC).distance_to(event.position) < RADIO_PERILLA * k * 1.3:
				arrastrando = "frec"
			elif PV(PERILLA_ANG).distance_to(event.position) < RADIO_PERILLA * k * 1.3:
				arrastrando = "ang"
			mouse_anterior = event.position
		else:
			arrastrando = ""
	elif event is InputEventMouseMotion and arrastrando != "":
		var mov: Vector2 = event.position - mouse_anterior
		mouse_anterior = event.position
		if arrastrando == "frec":
			frec = clamp(frec - mov.y / (40.0 * k), 1.0, 5.0)
		else:
			fase = wrapf(fase + mov.x / (30.0 * k), 0.0, TAU)


# ================= Dibujo =================

func _onda(r: Rect2, f: float, ph: float, color: Color, punteada: bool, grosor: float) -> void:
	var puntos := PackedVector2Array()
	var n := 90
	for i in n + 1:
		var t := float(i) / n
		var x := r.position.x + r.size.x * t
		var y := r.get_center().y - sin(t * TAU * f * 0.5 + ph) * r.size.y * 0.32
		puntos.append(Vector2(x, y))
	if punteada:
		for i in range(0, n, 2):
			draw_line(puntos[i], puntos[i + 1], color, grosor)
	else:
		draw_polyline(puntos, color, grosor)


func _perilla(centro: Vector2, angulo: float, nombre: String, activa: bool) -> void:
	var c := PV(centro)
	var r := RADIO_PERILLA * k
	draw_circle(c, r + 3 * k, C_OSCURO)
	draw_circle(c, r, Color("8a9099") if not activa else Color("b0b6bd"))
	for m in 8:
		var a := m * TAU / 8.0
		draw_line(c + Vector2.from_angle(a) * r * 0.75, c + Vector2.from_angle(a) * r * 0.95, C_OSCURO, 1.5 * k)
	draw_line(c, c + Vector2.from_angle(angulo) * r * 0.85, C_ROJO, 3.0 * k)
	draw_circle(c, 4 * k, C_OSCURO)
	texto(c + Vector2(-r - 8 * k, r + 14 * k), nombre, 8, C_TEXTO)


func _draw() -> void:
	var panel := RR(PANEL)
	placa(panel, Color("50565d"))
	texto(panel.position + Vector2(10, 18) * k, "SEÑAL DE LA TIERRA PERDIDA", 11, C_ROJO if fmod(tiempo, 0.6) < 0.35 else C_AMBAR)

	var pan := RR(PANTALLA)
	pantallita(pan, Color("04140a"))
	# Cuadrícula del osciloscopio
	for i in range(1, 6):
		var x := pan.position.x + pan.size.x * i / 6.0
		draw_line(Vector2(x, pan.position.y), Vector2(x, pan.end.y), Color(0.2, 0.6, 0.3, 0.25), 1.0)
	for i in range(1, 4):
		var y := pan.position.y + pan.size.y * i / 4.0
		draw_line(Vector2(pan.position.x, y), Vector2(pan.end.x, y), Color(0.2, 0.6, 0.3, 0.25), 1.0)

	var alineada := _alineada()
	var dorado := Color("f5c542")
	_onda(pan, frec_meta, fase_meta + tiempo * 1.2, dorado if alineada else Color("5aa9ff"), true, 2.0 * k)
	_onda(pan, frec, fase + tiempo * 1.2, dorado if alineada else Color("6dff8a"), false, 2.0 * k)
	texto(pan.position + Vector2(6, 14) * k, "TIERRA (azul)  NAVE (verde)", 8, Color(0.7, 1, 0.75, 0.7))

	# Perillas
	_perilla(PERILLA_FREC, (frec - 1.0) / 4.0 * TAU * 0.8 - PI * 0.9, "FRECUENCIA", arrastrando == "frec")
	_perilla(PERILLA_ANG, fase, "ÁNGULO", arrastrando == "ang")

	# Telemetría y tiempo
	var calidad := clampf(100.0 - _error() * 160.0, 5.0, 100.0)
	var info := R(460, 446, 236, 24)
	pantallita(info, Color("0a0f12"))
	var c_tel := dorado if alineada else (C_AMBAR if calidad > 50.0 else C_ROJO)
	texto(info.position + Vector2(6, 17) * k, "TELEMETRÍA: %d%%" % int(calidad), 11, c_tel)
	texto(info.position + Vector2(140, 17) * k, "%.0f s" % max(restante, 0.0), 10, C_TEXTO)
	if alineada:
		var b := R(PANTALLA.position.x, PANTALLA.end.y - 18, PANTALLA.size.x, 16)
		draw_rect(Rect2(b.position, Vector2(b.size.x * sostenido / SOSTENER, b.size.y)), Color(dorado, 0.6))
		texto_centrado(b, b.position.y + 13 * k, "MANTÉN...  ENLACE AL %d%%" % int(sostenido / SOSTENER * 100), 9, Color.WHITE)
	if acabado and sostenido >= SOSTENER:
		texto_centrado(pan, pan.get_center().y, "ENLACE RESTABLECIDO", 16, dorado)
	texto(panel.position + Vector2(258, 186) * k, "W/S  A/D", 9, C_TEXTO)
