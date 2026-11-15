extends "res://scripts/minijuegos/base.gd"
## MINIJUEGO 3: ESCUDO ANTI-RADIACIÓN POR TORMENTA SOLAR
## Se usan piezas que ya están dibujadas en la pared izquierda de la cabina:
##   1. Clic en la palanca DEPLOYABLE LEAD LINED (o tecla E) para bajarla.
##   2. Mantén presionado el botón verde DEPLOY (o ESPACIO) hasta que las
##      persianas de plomo cierren las ventanas.
## Si el DOSIMETER llega a DANGER antes de cerrar, la radiación causa un
## "bit-flip": se distorsionan los monitores y se pierden datos científicos.
## Con casco reforzado (CAP. DE MASA 70 o más) el escudo cierra el doble de rápido.

const PALANCA := Rect2(146, 316, 44, 78)
const BOTON := Rect2(53, 412, 58, 34)
const DOSIMETRO := Rect2(24, 470, 76, 62)
const VENTANAS := [Rect2(222, 126, 280, 176), Rect2(512, 132, 126, 152), Rect2(640, 132, 142, 152), Rect2(784, 128, 172, 174)]
const TIEMPO_LIMITE := 11.0

var paso := 1               # 1 = bajar palanca, 2 = mantener DEPLOY
var palanca := 0.0          # 0 arriba, 1 abajo
var cierre := 0.0           # 0 abiertas, 1 cerradas
var dosis := 0.0            # 0 LOW, 1 DANGER
var tiempo_cierre := 3.0
var presionando := false
var historial := []
var reloj_historial := 0.0
var geiger: AudioStreamPlayer
var reloj_geiger := 0.0


func iniciar() -> void:
	tiempo_cierre = 1.5 if viaje.casco_reforzado else 3.0
	geiger = AudioStreamPlayer.new()
	geiger.stream = _sonido_click()
	geiger.volume_db = -8.0
	add_child(geiger)


## Sonido de un "clic" de contador Geiger hecho con código (ruido muy corto)
func _sonido_click() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 22050
	var datos := PackedByteArray()
	for i in 260:
		var v := int(randf_range(-1.0, 1.0) * 110.0 * (1.0 - i / 260.0))
		datos.append(v & 0xFF)
	w.data = datos
	return w


func actualizar(delta: float) -> void:
	dosis = min(dosis + delta / TIEMPO_LIMITE, 1.0)

	# Contador Geiger: más clics mientras más radiación
	reloj_geiger -= delta
	if reloj_geiger <= 0.0:
		geiger.pitch_scale = randf_range(0.8, 1.3)
		geiger.play()
		reloj_geiger = lerp(0.45, 0.03, dosis) * randf_range(0.5, 1.5) * (1.0 - cierre * 0.8)

	# Gráfica del dosímetro
	reloj_historial -= delta
	if reloj_historial <= 0.0:
		reloj_historial = 0.12
		historial.append(dosis * (1.0 - cierre * 0.6) + randf_range(-0.04, 0.04))
		if historial.size() > 22:
			historial.pop_front()

	if paso == 2:
		var sosteniendo := presionando or tecla(KEY_SPACE)
		if sosteniendo:
			cierre = min(cierre + delta / tiempo_cierre, 1.0)

	if cierre >= 1.0:
		terminar(true)
	elif dosis >= 1.0:
		terminar(false)


func _bajar_palanca() -> void:
	if paso != 1:
		return
	paso = 2
	create_tween().tween_property(self, "palanca", 1.0, 0.3).set_trans(Tween.TRANS_BACK)


func _input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		_bajar_palanca()


func _gui_input(event: InputEvent) -> void:
	if acabado:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if RR(PALANCA).grow(6 * k).has_point(event.position):
				_bajar_palanca()
			elif paso == 2 and RR(BOTON).grow(6 * k).has_point(event.position):
				presionando = true
		else:
			presionando = false


# ================= Dibujo =================

func _draw() -> void:
	# Resplandor naranja en las ventanas + persianas de plomo bajando
	for v in VENTANAS:
		var r := RR(v)
		var brillo := (0.22 + 0.12 * sin(tiempo * 7.0 + v.position.x)) * (1.0 - cierre)
		draw_rect(r, Color(1.0, 0.45, 0.1, brillo))
		var alto := r.size.y * cierre
		if alto > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x, alto)), Color("4b5057"))
			var y := r.position.y + 6.0 * k
			while y < r.position.y + alto:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("2c3035"), 2.0 * k)
				y += 9.0 * k
			draw_rect(Rect2(r.position.x, r.position.y + alto - 3 * k, r.size.x, 3 * k), Color("8a9099"))

	# Palanca DEPLOYABLE LEAD LINED (se dibuja encima de la de la imagen)
	var pr := RR(PALANCA)
	draw_rect(pr, Color("3a3f45"))
	draw_rect(Rect2(pr.position.x + pr.size.x * 0.42, pr.position.y + 6 * k, pr.size.x * 0.16, pr.size.y - 12 * k), C_OSCURO)
	var y_mango: float = lerp(pr.position.y + 14 * k, pr.end.y - 14 * k, palanca)
	draw_rect(Rect2(pr.position.x + 6 * k, y_mango - 7 * k, pr.size.x - 12 * k, 14 * k), Color("9aa0a6"))
	draw_rect(Rect2(pr.position.x + 6 * k, y_mango - 7 * k, pr.size.x - 12 * k, 14 * k), C_OSCURO, false, 1.5 * k)
	draw_rect(Rect2(pr.position.x + 10 * k, y_mango - 3 * k, pr.size.x - 20 * k, 6 * k), Color("c0392b"))

	# Botón DEPLOY con barra de progreso
	var b := RR(BOTON)
	var verde := Color("3cb44b") if paso == 2 else Color("2b5e33")
	if presionando or (paso == 2 and tecla(KEY_SPACE)):
		verde = Color("7dff8a")
	draw_rect(b, verde)
	draw_rect(b, C_OSCURO, false, 2.0 * k)
	texto_centrado(b, b.position.y + b.size.y * 0.68, "DEPLOY", 11, C_OSCURO)
	if paso == 2:
		draw_rect(Rect2(b.position.x, b.end.y + 3 * k, b.size.x, 5 * k), C_OSCURO)
		draw_rect(Rect2(b.position.x, b.end.y + 3 * k, b.size.x * cierre, 5 * k), C_VERDE)

	# Dosímetro
	var d := RR(DOSIMETRO)
	draw_rect(d, Color("061008"))
	draw_rect(d, Color("2c3035"), false, 2.0 * k)
	var color_dosis := C_VERDE.lerp(C_ROJO, dosis)
	if historial.size() > 1:
		var puntos := PackedVector2Array()
		for i in historial.size():
			var x := d.position.x + 4 * k + (d.size.x - 8 * k) * i / 21.0
			var y: float = d.end.y - 6 * k - (d.size.y - 22 * k) * clamp(float(historial[i]), 0.0, 1.0)
			puntos.append(Vector2(x, y))
		draw_polyline(puntos, color_dosis, 2.0 * k)
	texto(d.position + Vector2(4, 12) * k, "DANGER" if dosis > 0.7 else ("MED" if dosis > 0.35 else "LOW"), 9, color_dosis)
	texto(d.position + Vector2(d.size.x - 34 * k, 12 * k), "%d%%" % int(dosis * 100), 9, color_dosis)

	# Marcos que parpadean e instrucciones del paso actual
	if paso == 1:
		marco_parpadeante(pr, C_ROJO)
		_instruccion(P(198, 334), "1. BAJA LA PALANCA", "(clic o tecla E)")
	else:
		marco_parpadeante(b, C_ROJO)
		_instruccion(P(120, 420), "2. MANTÉN PRESIONADO DEPLOY", "(clic sostenido o ESPACIO)")
	marco_parpadeante(d, C_ROJO if dosis > 0.6 else C_AMBAR)

	# Aviso arriba
	var aviso := R(300, 78, 424, 30)
	draw_rect(aviso, Color(0.3, 0.05, 0.02, 0.85))
	draw_rect(aviso, C_ROJO if fmod(tiempo, 0.5) < 0.3 else Color("7a1a14"), false, 2 * k)
	texto_centrado(aviso, aviso.position.y + 21 * k, "¡TORMENTA SOLAR! CIERRA EL ESCUDO DE PLOMO", 12, C_AMBAR)


func _instruccion(pos: Vector2, linea1: String, linea2: String) -> void:
	var r := Rect2(pos, Vector2(205, 38) * k)
	draw_rect(r, Color(0.05, 0.05, 0.08, 0.9))
	draw_rect(r, C_AMBAR, false, 1.5 * k)
	texto(pos + Vector2(6, 16) * k, linea1, 10, C_AMBAR)
	texto(pos + Vector2(6, 31) * k, linea2, 9, C_TEXTO)
