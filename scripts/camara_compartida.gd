# OPCIÓN A: Cámara compartida.
# Una sola Camera2D que se coloca en medio de los dos jugadores y se aleja
# (zoom out) cuando se separan, para que siempre se vean los dos.
#
# Uso: agrega una Camera2D a la escena de la nave (NO dentro del Player)
# y ponle este script. Encuentra a los jugadores sola (grupo "players").
# Tip: en el Inspector, en Limit, pon los bordes de la nave para que
# la cámara no muestre el espacio vacío de afuera.
extends Camera2D

@export var smoothing := 5.0              # más alto = sigue más rápido
@export var margin := Vector2(60, 40)     # espacio extra alrededor de los jugadores (px)
@export var min_zoom := 0.5               # lo más alejada que puede estar
@export var max_zoom := 1.0               # lo más cerca (1 = tamaño normal pixel-perfect)

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return

	# Rectángulo que contiene a todos los jugadores + margen
	var rect := Rect2((players[0] as Node2D).global_position, Vector2.ZERO)
	for p in players:
		rect = rect.expand((p as Node2D).global_position)
	rect = rect.grow_individual(margin.x, margin.y, margin.x, margin.y)

	# Zoom necesario para que ese rectángulo quepa en pantalla
	var screen := get_viewport_rect().size
	var z := minf(screen.x / rect.size.x, screen.y / rect.size.y)
	z = clampf(z, min_zoom, max_zoom)

	var t := 1.0 - exp(-smoothing * delta)   # suavizado independiente de los FPS
	global_position = global_position.lerp(rect.get_center(), t)
	zoom = zoom.lerp(Vector2(z, z), t)
