extends CanvasLayer
## MENÚ DE PAUSA (en todas las escenas)
## Un botoncito (II) arriba a la izquierda. Al darle clic se pausa el juego y aparece:
##   CONTINUAR | REINICIAR ESCENA | MENÚ PRINCIPAL
## Se instala UNA sola vez como Autoload (ver instrucciones) y aparece solo
## en todas las escenas, menos en el menú principal.

# ---------- Cosas que puedes cambiar fácilmente ----------
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const POSICION := Vector2(6, 6)        # dónde va el botón (pantalla de 648 de alto)
const TAMANO := Vector2(30, 26)        # tamaño del botón
# ---------------------------------------------------------

const C_FONDO := Color(0.04, 0.06, 0.15, 0.92)
const C_BORDE := Color("6a76a8")
const C_HOVER := Color("3a2a66")
const C_BORDE_HOVER := Color("f2c6e0")
const C_TEXTO := Color("f4eefc")

var k := 1.0
var fuente: Font
var boton: Button
var fondo: ColorRect
var panel: PanelContainer
var abierto := false
var escena_actual: Node = null


func _ready() -> void:
	layer = 100                                   # siempre encima de todo
	process_mode = Node.PROCESS_MODE_ALWAYS       # funciona aunque el juego esté en pausa
	k = get_viewport().get_visible_rect().size.y / 648.0
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font

	# Botón pequeño con tres rayitas
	boton = Button.new()
	boton.text = "II"
	boton.focus_mode = Control.FOCUS_NONE
	boton.position = POSICION * k
	boton.size = TAMANO * k
	boton.custom_minimum_size = TAMANO * k
	boton.tooltip_text = "Menú"
	_estilo_boton(boton, 16)
	boton.modulate.a = 0.75
	boton.mouse_entered.connect(func(): boton.modulate.a = 1.0)
	boton.mouse_exited.connect(func(): boton.modulate.a = 0.75)
	boton.pressed.connect(_alternar)
	add_child(boton)

	# Fondo oscuro (solo cuando el menú está abierto)
	fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.45)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.size = get_viewport().get_visible_rect().size
	fondo.visible = false
	fondo.gui_input.connect(_clic_fuera)
	add_child(fondo)
	move_child(fondo, 0)

	# Menú desplegable debajo del botón
	panel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = C_FONDO
	estilo.border_color = C_BORDE
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	panel.position = (POSICION + Vector2(0, TAMANO.y + 4)) * k
	panel.visible = false
	add_child(panel)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", int(4 * k))
	panel.add_child(lista)
	lista.add_child(_opcion("CONTINUAR", _cerrar))
	lista.add_child(_opcion("REINICIAR ESCENA", _reiniciar))
	lista.add_child(_opcion("MENÚ PRINCIPAL", _ir_al_menu))

	_revisar_escena()


func _opcion(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 26) * k
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_estilo_boton(b, 12)
	b.pressed.connect(accion)
	return b


func _estilo_boton(b: Button, tam: int) -> void:
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", int(tam * k))
	for estado in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = C_FONDO if estado == "normal" else C_HOVER
		s.border_color = C_BORDE if estado == "normal" else C_BORDE_HOVER
		s.set_border_width_all(max(1, int(1 * k)))
		s.set_content_margin_all(int(4 * k))
		b.add_theme_stylebox_override(estado, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, C_TEXTO)


# ---------- Abrir / cerrar ----------

func _alternar() -> void:
	if abierto:
		_cerrar()
	else:
		_abrir()


func _abrir() -> void:
	abierto = true
	panel.visible = true
	fondo.visible = true
	get_tree().paused = true


func _cerrar() -> void:
	abierto = false
	panel.visible = false
	fondo.visible = false
	get_tree().paused = false


func _clic_fuera(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cerrar()


func _reiniciar() -> void:
	_cerrar()
	get_tree().reload_current_scene()


func _ir_al_menu() -> void:
	_cerrar()
	if ResourceLoader.exists(ESCENA_MENU):
		get_tree().change_scene_to_file(ESCENA_MENU)
	else:
		push_warning("No existe " + ESCENA_MENU)


# ---------- Ocultarlo en el menú principal ----------

func _process(_delta: float) -> void:
	if get_tree().current_scene != escena_actual:
		_revisar_escena()


func _revisar_escena() -> void:
	escena_actual = get_tree().current_scene
	var escena := get_tree().current_scene
	var en_menu := escena != null and escena.scene_file_path == ESCENA_MENU
	boton.visible = not en_menu
	if en_menu and abierto:
		_cerrar()
