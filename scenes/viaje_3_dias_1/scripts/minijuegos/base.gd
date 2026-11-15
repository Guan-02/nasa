extends Control
## BASE DE LOS MINIJUEGOS DEL VIAJE
## Cada minijuego cubre la cabina completa y dibuja sus piezas con _draw(),
## usando coordenadas de la imagen de la cabina (1024 x 576). Así es fácil
## acomodar cosas: R(x, y, ancho, alto) y P(x, y) convierten a pantalla.
## Al terminar emite "terminado(true)" si se resolvió o "terminado(false)" si no.

signal terminado(exito: bool)

const C_METAL := Color("5d636b")
const C_METAL_CLARO := Color("8a9099")
const C_OSCURO := Color("1c1f24")
const C_ROJO := Color("ff4a3d")
const C_VERDE := Color("5ee36a")
const C_AMBAR := Color("ffb347")
const C_TEXTO := Color("f4eefc")

var viaje                  # la escena del viaje (oxigeno, combustible, casco, datos...)
var k := 1.0               # escala: pantalla / 1024
var fuente: Font
var nave := "apollo11"
var tiempo := 0.0
var acabado := false


func configurar(escena: Node, escala: float, f: Font, id: String) -> void:
	viaje = escena
	k = escala
	fuente = f
	nave = id


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1024, 576) * k
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	iniciar()


## Cada minijuego pone aquí lo que pasa al empezar
func iniciar() -> void:
	pass


## Cada minijuego pone aquí lo que pasa en cada cuadro
func actualizar(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	tiempo += delta
	if not acabado:
		actualizar(delta)
	queue_redraw()


func terminar(exito: bool) -> void:
	if acabado:
		return
	acabado = true
	terminado.emit(exito)
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


# ---------- Ayudas para dibujar ----------

func R(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * k, y * k, w * k, h * k)


func RR(r: Rect2) -> Rect2:
	return Rect2(r.position * k, r.size * k)


func P(x: float, y: float) -> Vector2:
	return Vector2(x * k, y * k)


func PV(v: Vector2) -> Vector2:
	return v * k


## Placa de metal con remaches, como los paneles de la cabina
func placa(r: Rect2, color: Color = C_METAL) -> void:
	draw_rect(r.grow(3.0 * k), C_OSCURO)
	draw_rect(r, color)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0 * k)), color.lightened(0.2))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0 * k), Vector2(r.size.x, 3.0 * k)), color.darkened(0.25))
	var m := 6.0 * k
	for p in [r.position + Vector2(m, m), r.position + Vector2(r.size.x - m, m),
			r.position + Vector2(m, r.size.y - m), r.end - Vector2(m, m)]:
		draw_circle(p, 2.2 * k, color.darkened(0.4))
		draw_circle(p - Vector2(0.6, 0.6) * k, 1.0 * k, color.lightened(0.3))


## Pantallita oscura (tipo monitor) con borde
func pantallita(r: Rect2, fondo: Color = Color("0a0f12")) -> void:
	draw_rect(r.grow(2.0 * k), C_OSCURO)
	draw_rect(r, fondo)


func texto(pos: Vector2, s: String, tam: float, color: Color, ancho: float = -1.0, alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var t := int(tam * k)
	draw_string_outline(fuente, pos, s, alineacion, ancho, t, int(3 * k), Color(0, 0, 0, 0.8))
	draw_string(fuente, pos, s, alineacion, ancho, t, color)


func texto_centrado(r: Rect2, y: float, s: String, tam: float, color: Color) -> void:
	texto(Vector2(r.position.x, y), s, tam, color, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func marco_parpadeante(r: Rect2, color: Color) -> void:
	var a := 0.45 + 0.45 * sin(tiempo * 9.0)
	var c := color
	c.a = a
	draw_rect(r.grow(4.0 * k), c, false, 3.0 * k)


func tecla(codigo: Key) -> bool:
	return Input.is_physical_key_pressed(codigo)
