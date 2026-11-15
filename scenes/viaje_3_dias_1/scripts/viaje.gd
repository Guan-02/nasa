extends Control
## VIAJE TIERRA-LUNA EN PRIMERA PERSONA (3 días)
## Vamos dentro de la cabina. La barra de arriba muestra el progreso del viaje.
## En ciertos momentos aparece una falla (minijuego). Cada nave tiene sus
## propias desventajas: qué fallas le tocan y qué tan difíciles son.
## Albertsahur explica todo abajo a la izquierda.
## Al terminar, se regresa a la escena de la órbita para llegar a la Luna.
##
## Los minijuegos están en res://scripts/minijuegos/ (uno por archivo).

# ---------- Cosas que puedes cambiar fácilmente ----------
const CABINA := "res://assets/viaje/cabina.jpg"
const CABINA_ASTRONAUTA := "res://assets/viaje/cabina_astronauta.jpg"
const REFUGIO := "res://assets/viaje/refugio.jpg"
const RUTA_MINIJUEGOS := "res://scripts/minijuegos/"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const ESCENA_SIGUIENTE := "res://scenes/orbita.tscn"
const ESCENA_TALLER := "res://scenes/taller.tscn"
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const DURACION_VIAJE := 150.0      # segundos de viaje (sin contar las fallas)
const PUNTOS_POR_FALLA := 300

# Fallas de cada nave: [en qué parte del viaje (0 a 1), cuál minijuego]
const FALLAS := {
	"gemini4": [[0.10, "valvulas"], [0.24, "asteroides"], [0.40, "valvulas"], [0.55, "tormenta"], [0.72, "antena"], [0.86, "valvulas"]],
	"apollo11": [[0.12, "antena"], [0.28, "valvulas"], [0.45, "asteroides"], [0.62, "tormenta"], [0.80, "computadora"]],
	"artemis2": [[0.15, "antena"], [0.35, "asteroides"], [0.55, "computadora"], [0.72, "tormenta"], [0.88, "valvulas"]],
}
const PROBABILIDAD_VALVULAS_ARTEMIS := 0.4   # Artemis casi nunca tiene falla de válvulas

const INTRO := [
	"Ya vamos rumbo a la Luna, director. Son unos 3 días de viaje, casi todo con los motores apagados.",
	"Desde la cabina vigilamos el oxígeno, el combustible y el casco. Si algo falla, hay que arreglarlo rápido.",
]
const DESVENTAJAS := {
	"gemini4": "Ojo: la Gemini IV es pequeña y vieja. Sus válvulas fallan seguido y los propulsores responden con un poco de retraso.",
	"apollo11": "Ojo: la computadora del Apollo tiene muy poca memoria. Si recibe demasiados datos se satura... como en la famosa alarma 1202.",
	"artemis2": "Artemis es muy confiable, pero la radiación del espacio profundo altera su computadora. Y si algo llega a fallar, falla todo junto.",
}
const DIAS := {
	2: "Día 2. La Tierra ya se ve chiquita por la ventana. Seguimos en silencio rumbo a la Luna.",
	3: "Día 3. ¡La Luna se ve cada vez más grande! Ya casi llegamos.",
}
# Lo que dice Albertsahur al empezar cada falla
const AVISOS := {
	"valvulas": [
		"¡Falla en las válvulas de oxígeno! En el Apollo 13 un tanque de oxígeno explotó camino a la Luna.",
		"Elige una válvula (1, 2 o 3) y gira el regulador con A/D o arrastrando el mouse hasta que la aguja quede en verde.",
	],
	"asteroides": [
		"¡Basura espacial en la ruta! Un pedacito del tamaño de una tuerca puede atravesar el casco.",
		"La NASA hace maniobras de evasión con impulsos cortos. Muévete con las flechas, pero cada movimiento gasta combustible.",
	],
	"tormenta": [
		"¡Tormenta solar! El Sol lanzó una eyección de masa coronal: radiación que daña la electrónica y a la tripulación.",
		"Baja la palanca del escudo de plomo y mantén presionado DEPLOY para cerrar las ventanas.",
	],
	"computadora": [
		"¡Alarma 1202! En el Apollo 11 la computadora se saturó durante el descenso a la Luna.",
		"Por suerte sabía descartar lo menos importante. Elimina los procesos basura (ámbar), ¡pero no toques los vitales (verdes)!",
	],
	"antena": [
		"Perdimos la señal con la Tierra. Mientras más nos alejamos, más débil llega.",
		"La NASA usa la Red del Espacio Profundo para hablar con las naves. Ajusta la onda verde con W/S y A/D hasta que quede sobre la azul.",
	],
}
const BIEN := {
	"valvulas": "¡Válvulas estables! El oxígeno vuelve a subir.",
	"asteroides": "¡Esquivamos todo! Ni un rasguño en el casco.",
	"tormenta": "¡Escudo cerrado! Nos refugiamos hasta que pase la tormenta.",
	"computadora": "¡CPU bajo control! La computadora vuelve a guiarnos.",
	"antena": "¡Enlace restablecido! Ya estamos mandando datos a la Tierra otra vez.",
}
const MAL := {
	"asteroides": "Nos pegaron algunas rocas. El casco quedó al %d%%.",
	"tormenta": "¡La radiación nos alcanzó! Se alteraron los monitores y perdimos datos científicos.",
	"computadora": "La computadora nos desvió de la ruta. Gastamos combustible para corregir y retrasamos el viaje.",
	"antena": "No logramos alinear bien la antena. La señal llega débil: juntaremos menos datos.",
}
# ---------------------------------------------------------

var k := 1.0
var pantalla := Vector2.ZERO
var arriba := 0.0
var fuente: Font
var tiempo := 0.0
var id_nave := "apollo11"

# Recursos de la nave (los minijuegos los cambian)
var oxigeno := 100.0
var combustible := 100.0
var casco := 100.0
var datos := 0.0
var progreso := 0.0
var mult_oxigeno := 1.0     # energía: qué tan rápido se pierde oxígeno
var dano_casco := 30.0      # cap. de masa: daño por roca
var casco_reforzado := false
var tasa_datos := 10.0      # ciencia: datos por segundo
var factor_antena := 1.0

var estado := "intro"       # intro, viajando, alerta, minijuego, pausa, escena, llegando, fallo
var eventos := []
var indice_evento := 0
var resueltas := 0
var total_fallas := 0
var dia := 1
var temblor := 0.0
var glitch := 0.0

var cabina: Control
var hud: Control
var capa_minijuegos: Control
var vineta: Control
var capa_efectos: Control
var lbl_centro: Label
var tex_tierra: Texture2D
var tex_luna: Texture2D

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
	k = pantalla.x / 1024.0
	arriba = (pantalla.y - 576.0 * k) * 0.5
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"

	# --- Lo que hacen las mejoras del taller en el viaje ---
	combustible = clamp(50.0 + Mision.valor(id_nave, "propulsion") * 0.5, 0.0, 100.0)
	mult_oxigeno = 1.3 - Mision.valor(id_nave, "energia") / 200.0
	casco_reforzado = Mision.valor(id_nave, "masa") >= 70
	dano_casco = 20.0 if casco_reforzado else 30.0
	tasa_datos = Mision.datos_por_capa(id_nave) / 40.0

	# --- Fallas de esta nave ---
	for e in FALLAS.get(id_nave, FALLAS["apollo11"]):
		if id_nave == "artemis2" and e[1] == "valvulas" and randf() > PROBABILIDAD_VALVULAS_ARTEMIS:
			continue
		eventos.append(e)

	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.size = pantalla
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(negro)

	# --- Cabina (todo lo que usa coordenadas de la imagen) ---
	cabina = Control.new()
	cabina.position = Vector2(0, arriba)
	cabina.size = Vector2(1024, 576) * k
	cabina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cabina)
	var fondo := TextureRect.new()
	fondo.texture = _cargar(CABINA)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.size = cabina.size
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabina.add_child(fondo)

	tex_tierra = _cargar("res://assets/espacio/planetas/planet-terran.png")
	tex_luna = _cargar("res://assets/espacio/planetas/planet-moon.png")
	hud = Control.new()
	hud.size = cabina.size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_dibujar_hud)
	cabina.add_child(hud)

	capa_minijuegos = Control.new()
	capa_minijuegos.size = cabina.size
	capa_minijuegos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabina.add_child(capa_minijuegos)

	vineta = Control.new()
	vineta.size = cabina.size
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.draw.connect(_dibujar_vineta)
	cabina.add_child(vineta)

	capa_efectos = Control.new()
	capa_efectos.size = cabina.size
	capa_efectos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_efectos.draw.connect(_dibujar_glitch)
	cabina.add_child(capa_efectos)

	_crear_textos()
	_crear_dialogo()
	_intro()
	_transicion_de_entrada()


func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _transicion_de_entrada() -> void:
	if Mision.captura != null:
		var capa := CanvasLayer.new()
		capa.layer = 20
		add_child(capa)
		var foto := TextureRect.new()
		foto.texture = Mision.captura
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_SCALE
		foto.size = pantalla
		capa.add_child(foto)
		Mision.captura = null
		var t := create_tween()
		t.tween_property(foto, "modulate:a", 0.0, 1.5)
		t.tween_callback(capa.queue_free)
	else:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func sacudir(segundos: float) -> void:
	temblor = max(temblor, segundos)


# ================= Intro: el astronauta en su asiento =================

func _intro() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 8
	add_child(capa)
	var foto := TextureRect.new()
	foto.texture = _cargar(CABINA_ASTRONAUTA)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.size = pantalla
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(foto)
	var titulo := _etiqueta(46, Color("f5c542"))
	titulo.text = "DÍA 1"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(pantalla.x, 60 * k)
	titulo.position = Vector2(0, pantalla.y * 0.08)
	foto.add_child(titulo)
	var sub := _etiqueta(20, Color("8fd3e8"))
	sub.text = "RUMBO A LA LUNA"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(pantalla.x, 30 * k)
	sub.position = Vector2(0, pantalla.y * 0.08 + 56 * k)
	foto.add_child(sub)
	var t := create_tween()
	t.tween_interval(5.5)
	t.tween_property(foto, "modulate:a", 0.0, 1.5)
	t.tween_callback(capa.queue_free)

	var lineas: Array = INTRO.duplicate()
	lineas.append(DESVENTAJAS.get(id_nave, ""))
	decir(lineas, _empezar_viaje)


func _empezar_viaje() -> void:
	if estado == "intro":
		estado = "viajando"


# ================= Ciclo principal =================

func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_dialogo(delta)

	if estado == "viajando":
		progreso = min(progreso + delta / DURACION_VIAJE, 1.0)
		datos += tasa_datos * factor_antena * delta
		oxigeno = min(oxigeno + 3.0 * delta, 100.0)
		var d: int = clamp(1 + int(progreso * 3.0), 1, 3)
		if d > dia:
			dia = d
			_texto_centro("DÍA %d" % d, Color("f5c542"))
			decir([DIAS.get(d, "")])
		if indice_evento < eventos.size() and progreso >= float(eventos[indice_evento][0]):
			var tipo: String = eventos[indice_evento][1]
			indice_evento += 1
			_alerta(tipo)
		elif progreso >= 1.0:
			_llegar()
	elif estado == "minijuego" and _minijuego_actual() == "":
		estado = "pausa"   # por si un minijuego se cerró solo

	if temblor > 0.0:
		temblor -= delta
		cabina.position = Vector2(0, arriba) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * k
	else:
		cabina.position = Vector2(0, arriba)
	glitch = max(glitch - delta, 0.0)

	hud.queue_redraw()
	vineta.queue_redraw()
	capa_efectos.queue_redraw()


func _minijuego_actual() -> String:
	return "si" if capa_minijuegos.get_child_count() > 0 else ""


# ================= Fallas (minijuegos) =================

func _alerta(tipo: String) -> void:
	estado = "alerta"
	total_fallas += 1
	sacudir(0.5)
	_texto_centro("¡ALERTA!", Color("ff4a3d"))
	if tipo == "antena":
		factor_antena = 0.0   # sin señal no se juntan datos
	decir(AVISOS.get(tipo, []))
	get_tree().create_timer(1.8).timeout.connect(_iniciar_minijuego.bind(tipo))


func _iniciar_minijuego(tipo: String) -> void:
	if estado == "fallo":
		return
	var ruta := RUTA_MINIJUEGOS + tipo + ".gd"
	if not ResourceLoader.exists(ruta):
		push_error("No encuentro el minijuego " + ruta)
		estado = "viajando"
		return
	estado = "minijuego"
	var mj = load(ruta).new()
	mj.configurar(self, k, fuente, id_nave)
	mj.terminado.connect(_fin_minijuego.bind(tipo))
	capa_minijuegos.add_child(mj)


func _fin_minijuego(exito: bool, tipo: String) -> void:
	if estado == "fallo":
		return
	if exito:
		resueltas += 1
		_texto_centro("¡RESUELTO!", Color("5ee36a"))
	match tipo:
		"valvulas":
			if not exito:
				_fallar("Nos quedamos sin oxígeno.")
				return
		"asteroides":
			if casco <= 0.0:
				_fallar("El casco no aguantó los impactos.")
				return
		"tormenta":
			if not exito:
				datos *= 0.7
				glitch = 2.5
				sacudir(0.6)
		"computadora":
			if not exito:
				progreso = max(progreso - 0.06, 0.0)
				combustible = max(combustible - 10.0, 0.0)
		"antena":
			factor_antena = 1.0 if exito else 0.5

	if exito:
		decir([BIEN.get(tipo, "¡Bien hecho!")])
	elif tipo == "asteroides":
		decir([MAL["asteroides"] % int(casco)])
	else:
		decir([MAL.get(tipo, "Eso no salió bien, pero seguimos.")])

	if tipo == "tormenta" and exito:
		estado = "escena"
		get_tree().create_timer(1.5).timeout.connect(_escena_refugio)
	else:
		estado = "pausa"
		get_tree().create_timer(2.0).timeout.connect(_reanudar)


func _reanudar() -> void:
	if estado == "pausa":
		estado = "viajando"


## Después de la tormenta: los 3 cuadros de "salir del refugio"
func _escena_refugio() -> void:
	if estado == "fallo":
		return
	var capa := CanvasLayer.new()
	capa.layer = 8
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.size = pantalla
	capa.add_child(fondo)
	var tex := _cargar(REFUGIO)
	var esc: float = min(pantalla.x / tex.get_size().x, pantalla.y / tex.get_size().y)
	var tam := tex.get_size() * esc
	var pos := (pantalla - tam) * 0.5
	var foto := TextureRect.new()
	foto.texture = tex
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_SCALE
	foto.position = pos
	foto.size = tam
	fondo.add_child(foto)
	# Tapas negras que se van quitando cuadro por cuadro
	var t := create_tween()
	fondo.modulate.a = 0.0
	t.tween_property(fondo, "modulate:a", 1.0, 0.6)
	for i in 3:
		var tapa := ColorRect.new()
		tapa.color = Color.BLACK
		tapa.position = pos + Vector2(tam.x * i / 3.0, 0)
		tapa.size = Vector2(tam.x / 3.0 + 2, tam.y)
		fondo.add_child(tapa)
		t.tween_property(tapa, "modulate:a", 0.0, 0.8)
		t.tween_interval(0.8)
	t.tween_interval(2.0)
	t.tween_property(fondo, "modulate:a", 0.0, 0.8)
	t.tween_callback(capa.queue_free)
	t.tween_callback(_reanudar_despues_de_escena)
	decir(["La tormenta pasó. Salimos del refugio, revisamos los sistemas y volvemos a nuestros puestos."])


func _reanudar_despues_de_escena() -> void:
	if estado == "escena":
		estado = "viajando"


# ================= Llegada y fallo =================

func _llegar() -> void:
	estado = "llegando"
	_texto_centro("¡LLEGAMOS!", Color("f5c542"))
	decir(["¡Ya vemos la Luna enorme por la ventana! Prepárate para la maniobra de llegada."])
	get_tree().create_timer(4.5).timeout.connect(_ir_a_la_luna)


func _ir_a_la_luna() -> void:
	Mision.viaje = {"datos": int(datos), "resueltas": resueltas, "total": total_fallas}
	if not Mision.resultado.is_empty():
		Mision.resultado["datos"] = int(Mision.resultado.get("datos", 0)) + int(datos)
		Mision.resultado["puntaje"] = int(Mision.resultado.get("puntaje", 0)) + int(datos) + resueltas * PUNTOS_POR_FALLA
	Mision.fase_orbita = "llegada"
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		await RenderingServer.frame_post_draw
		Mision.captura = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
	else:
		push_error("No existe " + ESCENA_SIGUIENTE)


func _fallar(razon: String) -> void:
	estado = "fallo"
	for mj in capa_minijuegos.get_children():
		mj.queue_free()
	sacudir(0.8)
	_texto_centro("MISIÓN FALLIDA", Color("ff4a3d"))
	decir([razon + " Revisemos el diseño de la nave e intentémoslo otra vez."])
	get_tree().create_timer(2.5).timeout.connect(_panel_fallo.bind(razon))


func _panel_fallo(razon: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.size = pantalla
	capa.add_child(fondo)
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("0b1026")
	estilo.border_color = Color("ff5a5a")
	estilo.set_border_width_all(max(1, int(3 * k)))
	estilo.set_content_margin_all(int(18 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	capa.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * k))
	panel.add_child(v)
	var titulo := _etiqueta(32, Color("ff5a5a"))
	titulo.text = "MISIÓN FALLIDA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var info := _etiqueta(16, Color("f4eefc"))
	info.text = "%s\nDía %d del viaje  |  Fallas resueltas: %d de %d" % [razon, dia, resueltas, total_fallas]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", int(10 * k))
	v.add_child(botones)
	botones.add_child(_boton("REINTENTAR VIAJE", ""))
	botones.add_child(_boton("TALLER", ESCENA_TALLER))
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
	if ruta == "":
		get_tree().reload_current_scene()
	elif ResourceLoader.exists(ruta):
		get_tree().change_scene_to_file(ruta)


# ================= Dibujo del HUD de la cabina =================

func R(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * k, y * k, w * k, h * k)


func P(x: float, y: float) -> Vector2:
	return Vector2(x * k, y * k)


func _texto(nodo: CanvasItem, pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	nodo.draw_string_outline(fuente, pos, s, alineacion, ancho, int(tam * k), int(3 * k), Color(0, 0, 0, 0.85))
	nodo.draw_string(fuente, pos, s, alineacion, ancho, int(tam * k), color)


func _color_nivel(v: float) -> Color:
	if v > 50.0:
		return Color("5ee36a")
	if v > 25.0:
		return Color("ffb347")
	return Color("ff4a3d")


func _dibujar_hud() -> void:
	# --- Barra PROGRESO TIERRA-LUNA ---
	var panel := R(186, 6, 652, 42)
	hud.draw_rect(panel.grow(2 * k), Color("1c1f24"))
	hud.draw_rect(panel, Color("2b3036"))
	_texto(hud, Vector2(panel.position.x, panel.position.y + 15 * k), "PROGRESO TIERRA-LUNA", 10, Color("dfe6ee"), panel.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var barra := R(210, 24, 604, 16)
	hud.draw_rect(barra.grow(1.5 * k), Color("101317"))
	hud.draw_rect(Rect2(barra.position, Vector2(barra.size.x * progreso, barra.size.y)), Color("5ee36a"))
	hud.draw_rect(Rect2(barra.position, Vector2(barra.size.x * progreso, 4 * k)), Color("a6ffad"))
	for i in range(1, 3):
		var x := barra.position.x + barra.size.x * i / 3.0
		hud.draw_line(Vector2(x, barra.position.y - 2 * k), Vector2(x, barra.end.y + 2 * k), Color("dfe6ee"), 1.5 * k)
	hud.draw_texture_rect(tex_tierra, R(168, 10, 36, 36), false)
	hud.draw_texture_rect(tex_luna, R(820, 10, 36, 36), false)

	# --- Línea de estado ---
	var estado_r := R(232, 52, 560, 20)
	hud.draw_rect(estado_r, Color(0.05, 0.06, 0.08, 0.75))
	var linea := "DÍA %d DE 3   |   O2 %d%%   |   FUEL %d%%   |   CASCO %d%%   |   DATOS %d" % [dia, int(oxigeno), int(combustible), int(casco), int(datos)]
	_texto(hud, Vector2(estado_r.position.x, estado_r.position.y + 15 * k), linea, 10, Color("dfe6ee"), estado_r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# --- Medidores de la pared izquierda (encima de los de la imagen) ---
	var o2 := R(30, 177, 18, 75)
	hud.draw_rect(o2, Color("101317"))
	var alto_o2 := o2.size.y * oxigeno / 100.0
	hud.draw_rect(Rect2(o2.position.x, o2.end.y - alto_o2, o2.size.x, alto_o2), _color_nivel(oxigeno))
	var fu := R(74, 182, 11, 65)
	hud.draw_rect(fu, Color("101317"))
	var alto_fu := fu.size.y * combustible / 100.0
	hud.draw_rect(Rect2(fu.position.x, fu.end.y - alto_fu, fu.size.x, alto_fu), Color("ffb347") if combustible > 20.0 else Color("ff4a3d"))
	# Aguja del reloj FUEL
	var c := P(146, 182)
	hud.draw_circle(c, 21 * k, Color("0d1013"))
	for m in 7:
		var am: float = lerp(deg_to_rad(135.0), deg_to_rad(405.0), m / 6.0)
		hud.draw_line(c + Vector2.from_angle(am) * 15 * k, c + Vector2.from_angle(am) * 19 * k, Color("dfe6ee"), 1.5 * k)
	var ang: float = lerp(deg_to_rad(135.0), deg_to_rad(405.0), combustible / 100.0)
	hud.draw_line(c, c + Vector2.from_angle(ang) * 17 * k, Color("ffffff"), 2.0 * k)
	hud.draw_circle(c, 2.5 * k, Color("ff4a3d"))
	# Barrita de CASCO (sobre la barra naranja debajo del reloj)
	var ca := R(126, 228, 48, 11)
	hud.draw_rect(ca, Color("101317"))
	hud.draw_rect(Rect2(ca.position, Vector2(ca.size.x * casco / 100.0, ca.size.y)), _color_nivel(casco))
	_texto(hud, P(127, 252), "CASCO", 7, Color("dfe6ee"))


func _dibujar_vineta() -> void:
	# Marco rojo que pulsa mientras hay una falla
	if estado == "alerta" or estado == "minijuego":
		var a := 0.25 + 0.2 * sin(tiempo * 8.0)
		var w := 10.0 * k
		var s := vineta.size
		var c := Color(1, 0.1, 0.05, a)
		vineta.draw_rect(Rect2(0, 0, s.x, w), c)
		vineta.draw_rect(Rect2(0, s.y - w, s.x, w), c)
		vineta.draw_rect(Rect2(0, 0, w, s.y), c)
		vineta.draw_rect(Rect2(s.x - w, 0, w, s.y), c)


func _dibujar_glitch() -> void:
	# "Bit-flip" por radiación: barras de colores que brincan
	if glitch <= 0.0:
		return
	var s := capa_efectos.size
	for i in 14:
		var y := randf() * s.y
		var h := randf_range(2.0, 14.0) * k
		var col := Color(randf(), randf(), randf(), 0.35 * min(glitch, 1.0))
		capa_efectos.draw_rect(Rect2(randf_range(-40, 40) * k, y, s.x, h), col)
	capa_efectos.draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0, 0.8, 0.08 * min(glitch, 1.0)))


# ================= Textos y Albertsahur =================

func _etiqueta(tamano: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", int(tamano * k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b0f24"))
	l.add_theme_constant_override("outline_size", int(6 * k))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_textos() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	lbl_centro = _etiqueta(46, Color.WHITE)
	lbl_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_centro.size = Vector2(pantalla.x, 70 * k)
	lbl_centro.position = Vector2(0, arriba + 92 * k)
	lbl_centro.modulate.a = 0.0
	capa.add_child(lbl_centro)


func _texto_centro(texto: String, color: Color) -> void:
	lbl_centro.text = texto
	lbl_centro.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl_centro, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.4)
	t.tween_property(lbl_centro, "modulate:a", 0.0, 0.5)


func _crear_dialogo() -> void:
	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")

	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	var caja := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.15, 0.9)
	estilo.border_color = Color("6a76a8")
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(5 * k))
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(206 * k, arriba + 484 * k)
	caja.custom_minimum_size = Vector2(500 * k, 84 * k)
	caja.size = caja.custom_minimum_size
	capa.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(8 * k))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(fila)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(70 * k, 64 * k)
	hueco.clip_contents = true
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(hueco)
	retrato = TextureRect.new()
	retrato.texture = tex_normal
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(1 * k))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(col)
	var nombre := _etiqueta(11, Color("f5c542"))
	nombre.text = "ALBERTSAHUR"
	col.add_child(nombre)
	lbl_dialogo = _etiqueta(13, Color("f4eefc"))
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_dialogo.custom_minimum_size.x = 400 * k
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
	espera = 2.2 + lbl_dialogo.text.length() * 0.03


func _actualizar_dialogo(delta: float) -> void:
	var total := lbl_dialogo.get_total_character_count()
	if lbl_dialogo.visible_characters < total:
		letras = min(letras + 50.0 * delta, total)
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
