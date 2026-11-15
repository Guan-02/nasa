extends Control
## ÓRBITA Y ESCAPE: después de salir de la exosfera, la cápsula da vueltas a la
## Tierra (órbita de estacionamiento) y luego enciende motores para escapar.
## Albertsahur explica por qué se hace así. Al final se muestra el puntaje.

# ---------- Cosas que puedes cambiar fácilmente ----------
const RUTA := "res://assets/espacio/"
const NEBULOSA := "nebula-violet-tile.png"   # o "nebula-teal-tile.png" / "nebula-rose-tile.png"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const ESCENA_SIGUIENTE := ""                  # la fase que sigue, cuando exista
const ESCENA_TALLER := "res://scenes/taller.tscn"
const ESCENA_SELECCION := "res://scenes/seleccion_nave.tscn"
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const SEGUNDOS_POR_VUELTA := 9.0
const TAMANO_TIERRA := 6.0      # la Tierra mide 48 px; se agranda 6 veces
const ALTO_CAPSULA := 46.0
const INCLINACION := -0.22      # inclinación de la órbita (radianes)

const LINEAS_ORBITA := [
	"¡Salimos de la atmósfera! Ahora estamos en órbita alrededor de la Tierra.",
	"Vamos a casi 28,000 km/h. Estamos cayendo todo el tiempo hacia la Tierra, pero vamos tan rápido de lado que nunca chocamos con ella: eso es una órbita.",
	"No salimos directo al espacio. Primero damos vueltas en una 'órbita de estacionamiento' para revisar que todos los sistemas funcionen bien.",
	"También esperamos el momento justo: cuando el destino queda bien alineado, aprovechamos la velocidad que ya llevamos y gastamos menos combustible.",
]
const LINEA_NAVE := {
	"apollo11": "Así lo hizo el Apollo 11 en 1969: dio una vuelta y media a la Tierra antes de encender el motor rumbo a la Luna.",
	"artemis2": "Artemis II también revisa sus sistemas dando vueltas a la Tierra antes de encender motores hacia la Luna.",
	"gemini4": "Dato curioso: la Gemini IV real nunca salió de la órbita; pasó 4 días dando vueltas a la Tierra. ¡Nosotros sí vamos a ir más lejos!",
}
const LINEAS_ESCAPE := [
	"¡Ahora! Encendemos motores hasta unos 40,000 km/h: la velocidad de escape de la Tierra.",
	"A esa velocidad la gravedad ya no puede regresarnos. ¡Adiós, Tierra! ¡Rumbo al espacio profundo!",
]
# ---------------------------------------------------------

var k := 1.0
var pantalla := Vector2.ZERO
var fuente: Font
var tiempo := 0.0
var id_nave := "apollo11"

var capas := []
var tierra: Sprite2D
var luna: Sprite2D
var centro := Vector2.ZERO
var radio_x := 0.0
var radio_y := 0.0
var orbita_atras: Node2D
var orbita_frente: Node2D
var capsula: Sprite2D
var fuego: CPUParticles2D
var reloj_frames := 0.0

var estado := "orbita"     # orbita, listo, escape, fin
var angulo := 0.6
var vueltas := 0.0
var t_escape := 0.0
var escala_orbita := 1.0
var temblor := 0.0
var raiz: Node2D

var lbl_titulo: Label
var lbl_velocidad: Label
var lbl_vuelta: Label
var lbl_centro: Label
var capa_hud: CanvasLayer

# Diálogo
var retrato: TextureRect
var lbl_dialogo: Label
var tex_normal: Texture2D
var tex_hablando: Texture2D
var tex_parpadeo: Texture2D
var cola := []
var al_terminar := Callable()
var letras := 0.0
var espera := 0.0
var reloj_boca := 0.0
var boca_abierta := false
var parpadeo := 2.0


func _ready() -> void:
	pantalla = get_viewport_rect().size
	k = pantalla.y / 648.0
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	raiz = Node2D.new()
	add_child(raiz)

	# Fondo espacial (igual que el menú)
	_crear_capa(NEBULOSA, 3.0, 256)
	_crear_capa("stars-mid-tile.png", 8.0, 128)
	_crear_capa("stars-near-tile.png", 16.0, 128)

	# Tierra girando
	centro = Vector2(pantalla.x * 0.42, pantalla.y * 0.48)
	var halo := Node2D.new()
	halo.position = centro
	halo.z_index = -3
	halo.draw.connect(_dibujar_halo.bind(halo))
	raiz.add_child(halo)

	orbita_atras = Node2D.new()
	orbita_atras.z_index = -2
	orbita_atras.draw.connect(_dibujar_orbita.bind(orbita_atras, true))
	raiz.add_child(orbita_atras)

	tierra = Sprite2D.new()
	tierra.texture = _cargar(RUTA + "planetas/planet-terran-spin-24f.png")
	tierra.hframes = 24
	tierra.scale = Vector2.ONE * TAMANO_TIERRA * k
	tierra.position = centro
	raiz.add_child(tierra)

	orbita_frente = Node2D.new()
	orbita_frente.z_index = 1
	orbita_frente.draw.connect(_dibujar_orbita.bind(orbita_frente, false))
	raiz.add_child(orbita_frente)

	# La Luna a lo lejos: nuestro destino
	luna = Sprite2D.new()
	luna.texture = _cargar(RUTA + "planetas/planet-moon-spin-24f.png")
	luna.hframes = 24
	luna.scale = Vector2.ONE * 1.6 * k
	luna.position = Vector2(pantalla.x * 0.86, pantalla.y * 0.18)
	raiz.add_child(luna)

	radio_x = 24.0 * TAMANO_TIERRA * k * 1.75
	radio_y = radio_x * 0.38

	# Cápsula de la nave elegida (en órbita ya no lleva el cohete)
	capsula = Sprite2D.new()
	capsula.texture = _cargar(Mision.NAVES[id_nave].capsula_img)
	var esc := ALTO_CAPSULA * k / capsula.texture.get_size().y
	capsula.scale = Vector2(esc, esc)
	capsula.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if esc < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(capsula)
	_crear_fuego()

	_crear_hud()
	_crear_dialogo()
	_mover_capsula(0.0)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	var lineas: Array = LINEAS_ORBITA.duplicate()
	lineas.append(LINEA_NAVE.get(id_nave, ""))
	decir(lineas, _listo_para_escapar)


func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _crear_capa(archivo: String, velocidad: float, tile: int) -> void:
	var capa := TextureRect.new()
	capa.texture = _cargar(RUTA + "fondos/" + archivo)
	capa.stretch_mode = TextureRect.STRETCH_TILE
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = -10
	add_child(capa)
	move_child(capa, capas.size())   # detrás de todo lo demás
	capa.size = pantalla + Vector2(tile, tile)
	capas.append({"nodo": capa, "vel": velocidad, "tile": tile, "d": 0.0})


func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_dialogo(delta)

	for c in capas:
		c.d += c.vel * delta * (4.0 if estado == "escape" else 1.0)
		c.nodo.position.x = -round(fposmod(c.d, c.tile))

	reloj_frames += delta
	if reloj_frames >= 0.12:
		reloj_frames = 0.0
		tierra.frame = (tierra.frame + 1) % tierra.hframes
		luna.frame = (luna.frame + 1) % luna.hframes

	var w := TAU / SEGUNDOS_POR_VUELTA
	match estado:
		"orbita", "listo":
			_mover_capsula(w * delta)
			# Enciende motores cuando pasa por el lado derecho, por delante de la Tierra
			if estado == "listo" and fposmod(angulo, TAU) < 0.35:
				_iniciar_escape()
		"escape":
			t_escape += delta
			escala_orbita = 1.0 + 0.45 * t_escape * t_escape
			_mover_capsula(w * (1.0 + t_escape * 0.9) * delta)
			var v: float = lerp(27600.0, 40300.0, clamp(t_escape / 3.0, 0.0, 1.0))
			if t_escape > 3.0:
				v += (t_escape - 3.0) * 900.0
			lbl_velocidad.text = "VELOCIDAD: %s km/h" % _miles(v)
			var fuera := capsula.position.distance_to(centro) > pantalla.length() * 0.7
			if fuera:
				_terminar()

	if temblor > 0.0:
		temblor -= delta
		raiz.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0 * k
	else:
		raiz.position = Vector2.ZERO

	orbita_atras.queue_redraw()
	orbita_frente.queue_redraw()


# ================= Órbita =================

func _punto_orbita(a: float) -> Vector2:
	var p := Vector2(cos(a) * radio_x, sin(a) * radio_y) * escala_orbita
	return centro + p.rotated(INCLINACION)


func _mover_capsula(avance: float) -> void:
	angulo += avance
	vueltas += avance / TAU
	if estado != "escape":
		lbl_vuelta.text = "VUELTA %d" % (int(vueltas) + 1)
	capsula.position = _punto_orbita(angulo)
	# La punta mira hacia donde avanza
	var siguiente := _punto_orbita(angulo + 0.05)
	capsula.rotation = (siguiente - capsula.position).angle() + PI * 0.5
	# Detrás de la Tierra (mitad de arriba de la órbita): más chica y oscura
	var atras := sin(angulo) < 0.0
	capsula.z_index = -1 if atras and escala_orbita < 1.6 else 2
	var prof := 0.82 + 0.18 * (sin(angulo) * 0.5 + 0.5)
	var esc := ALTO_CAPSULA * k / capsula.texture.get_size().y * prof
	capsula.scale = Vector2(esc, esc)
	capsula.modulate = Color(prof, prof, prof + 0.05)


func _dibujar_halo(nodo: Node2D) -> void:
	var r := 24.0 * TAMANO_TIERRA * k
	for i in 6:
		nodo.draw_circle(Vector2.ZERO, r + (6 - i) * 5.0 * k, Color(0.45, 0.75, 1.0, 0.035 * (i + 1)))


func _dibujar_orbita(nodo: Node2D, atras: bool) -> void:
	if estado == "escape" or estado == "fin":
		return
	var n := 90
	for i in n:
		if i % 2 == 1:
			continue
		var a := TAU * i / n
		if (sin(a) < 0.0) != atras:
			continue
		var p1 := _punto_orbita(a)
		var p2 := _punto_orbita(a + TAU / n)
		nodo.draw_line(p1, p2, Color(0.6, 0.9, 1.0, 0.35 if atras else 0.7), 2.0 * k)


func _listo_para_escapar() -> void:
	estado = "listo"


func _iniciar_escape() -> void:
	estado = "escape"
	fuego.emitting = true
	temblor = 3.5
	lbl_titulo.text = "¡INYECCIÓN DE ESCAPE!"
	lbl_titulo.add_theme_color_override("font_color", Color("ffb37a"))
	lbl_vuelta.text = "MOTORES AL 100%"
	_texto_centro("¡MOTORES ENCENDIDOS!", Color("ffb37a"))
	decir(LINEAS_ESCAPE)


func _terminar() -> void:
	if estado == "fin":
		return
	estado = "fin"
	fuego.emitting = false
	capsula.visible = false
	_texto_centro("¡RUMBO AL ESPACIO PROFUNDO!", Color("f5c542"))
	get_tree().create_timer(4.0).timeout.connect(_mostrar_resultado)


func _crear_fuego() -> void:
	fuego = CPUParticles2D.new()
	fuego.amount = 60
	fuego.lifetime = 0.6
	fuego.local_coords = false
	fuego.emitting = false
	fuego.direction = Vector2(0, 1)
	fuego.spread = 14.0
	fuego.gravity = Vector2.ZERO
	fuego.initial_velocity_min = 90.0 * k
	fuego.initial_velocity_max = 160.0 * k
	fuego.scale_amount_min = 2.0 * k
	fuego.scale_amount_max = 5.0 * k
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.2, 0.85), Color(0.6, 0.3, 0.6, 0)])
	fuego.color_ramp = g
	fuego.position = Vector2(0, capsula.texture.get_size().y * 0.5)
	capsula.add_child(fuego)


# ================= HUD =================

func _etiqueta(tamano: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", int(tamano * k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b0f24"))
	l.add_theme_constant_override("outline_size", int(6 * k))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_hud() -> void:
	capa_hud = CanvasLayer.new()
	add_child(capa_hud)
	lbl_titulo = _etiqueta(24, Color("8fd3e8"))
	lbl_titulo.text = "ÓRBITA TERRESTRE"
	lbl_titulo.position = Vector2(18, 12) * k
	capa_hud.add_child(lbl_titulo)
	lbl_velocidad = _etiqueta(16, Color.WHITE)
	lbl_velocidad.text = "VELOCIDAD: 27,600 km/h"
	lbl_velocidad.position = Vector2(18, 46) * k
	capa_hud.add_child(lbl_velocidad)
	lbl_vuelta = _etiqueta(16, Color("f5c542"))
	lbl_vuelta.position = Vector2(18, 70) * k
	capa_hud.add_child(lbl_vuelta)
	var nave := _etiqueta(14, Color("c9d3ff"))
	nave.text = String(Mision.NAVES[id_nave].nombre)
	nave.position = Vector2(18, 94) * k
	capa_hud.add_child(nave)

	lbl_centro = _etiqueta(48, Color.WHITE)
	lbl_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_centro.size = Vector2(pantalla.x, 70 * k)
	lbl_centro.position = Vector2(0, pantalla.y * 0.12)
	lbl_centro.modulate.a = 0.0
	capa_hud.add_child(lbl_centro)


func _texto_centro(texto: String, color: Color) -> void:
	lbl_centro.text = texto
	lbl_centro.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl_centro, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(lbl_centro, "modulate:a", 0.0, 0.6)


func _miles(v: float) -> String:
	var s := str(int(v))
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)


# ================= Albertsahur =================

func _crear_dialogo() -> void:
	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")

	var caja := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.15, 0.88)
	estilo.border_color = Color("6a76a8")
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(14 * k, pantalla.y - 112 * k)
	caja.custom_minimum_size = Vector2(620 * k, 98 * k)
	capa_hud.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(8 * k))
	caja.add_child(fila)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(78 * k, 70 * k)
	hueco.clip_contents = true
	fila.add_child(hueco)
	retrato = TextureRect.new()
	retrato.texture = tex_normal
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(col)
	var nombre := _etiqueta(13, Color("f5c542"))
	nombre.text = "ALBERTSAHUR"
	col.add_child(nombre)
	lbl_dialogo = _etiqueta(15, Color("f4eefc"))
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_dialogo.custom_minimum_size.x = 500 * k
	col.add_child(lbl_dialogo)


func decir(lineas: Array, despues: Callable = Callable()) -> void:
	cola = lineas.duplicate()
	al_terminar = despues
	_siguiente_linea()


func _siguiente_linea() -> void:
	if cola.is_empty():
		var f := al_terminar
		al_terminar = Callable()
		if f.is_valid():
			f.call()
		return
	lbl_dialogo.text = cola.pop_front()
	lbl_dialogo.visible_characters = 0
	letras = 0.0
	espera = 2.0 + lbl_dialogo.text.length() * 0.03


func _actualizar_dialogo(delta: float) -> void:
	var total := lbl_dialogo.get_total_character_count()
	if lbl_dialogo.visible_characters < total:
		letras = min(letras + 45.0 * delta, total)
		lbl_dialogo.visible_characters = int(letras)
		reloj_boca += delta
		if reloj_boca >= 0.11:
			reloj_boca = 0.0
			boca_abierta = not boca_abierta
		retrato.texture = tex_hablando if boca_abierta else tex_normal
		var salto: float = round(abs(sin(tiempo * 14.0)) * 2.0 * k)
		retrato.offset_top = -salto
		retrato.offset_bottom = -salto
	else:
		retrato.offset_top = 0
		retrato.offset_bottom = 0
		parpadeo -= delta
		if parpadeo <= 0.0:
			retrato.texture = tex_parpadeo
			if parpadeo <= -0.12:
				parpadeo = randf_range(2.0, 4.5)
		else:
			retrato.texture = tex_normal
		if total > 0 and (not cola.is_empty() or al_terminar.is_valid()):
			espera -= delta
			if espera <= 0.0:
				_siguiente_linea()


func _input(event: InputEvent) -> void:
	# Clic o Espacio: adelanta el texto de Albertsahur
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and estado != "fin"):
		if lbl_dialogo.visible_characters < lbl_dialogo.get_total_character_count():
			letras = lbl_dialogo.get_total_character_count()
		else:
			espera = 0.0


# ================= Resultado final =================

func _mostrar_resultado() -> void:
	var r: Dictionary = Mision.resultado
	var fondo_panel := ColorRect.new()
	fondo_panel.color = Color(0, 0, 0, 0.55)
	fondo_panel.size = pantalla
	capa_hud.add_child(fondo_panel)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("0b1026")
	estilo.border_color = Color("f5c542")
	estilo.set_border_width_all(max(1, int(3 * k)))
	estilo.set_content_margin_all(int(18 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	capa_hud.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * k))
	panel.add_child(v)
	var titulo := _etiqueta(34, Color("f5c542"))
	titulo.text = "¡MISIÓN CUMPLIDA!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var info := _etiqueta(16, Color("f4eefc"))
	if r.is_empty():
		info.text = "Escapamos de la gravedad de la Tierra."
	else:
		info.text = "Nave: %s\nResistencia restante: %d / %d   (+%d)\nGolpes recibidos: %d  |  Escudos recogidos: %d\nAltitud máxima: %s km\nDatos científicos: %d\nPresupuesto sin usar: %s   (+%d)" % [
			r.nave, r.vida, r.vida_max, r.bono_vida, r.golpes, r.escudos, r.altitud,
			r.datos, Mision.dinero(Mision.presupuesto_restante), r.bono_dinero]
	v.add_child(info)
	if not r.is_empty():
		var puntaje := _etiqueta(28, Color("f5c542"))
		puntaje.text = "PUNTAJE: %d" % int(r.puntaje)
		puntaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(puntaje)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", int(10 * k))
	v.add_child(botones)
	if ESCENA_SIGUIENTE != "" and ResourceLoader.exists(ESCENA_SIGUIENTE):
		botones.add_child(_boton("CONTINUAR", ESCENA_SIGUIENTE))
	botones.add_child(_boton("TALLER", ESCENA_TALLER))
	botones.add_child(_boton("CAMBIAR NAVE", ESCENA_SELECCION))
	botones.add_child(_boton("MENÚ", ESCENA_MENU))

	await get_tree().process_frame
	panel.position = (pantalla - panel.size) * 0.5


func _boton(texto: String, ruta: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", int(15 * k))
	b.custom_minimum_size = Vector2(0, 36 * k)
	b.pressed.connect(_ir_a.bind(ruta))
	return b


func _ir_a(ruta: String) -> void:
	if ResourceLoader.exists(ruta):
		get_tree().change_scene_to_file(ruta)
	else:
		push_warning("No existe " + ruta)
