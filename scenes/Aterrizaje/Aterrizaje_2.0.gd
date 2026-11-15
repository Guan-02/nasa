extends Node2D
## Aterrizaje_2.0.gd — Minijuego de alunizaje 2D estilo Lunar Lander (escena Aterrizaje_2.0.tscn).
## Combustible e integridad son LOCALES. El modelo de la nave se lee del Autoload "Mision".

signal mision_completada  # Útil para avanzar a la siguiente escena del juego.

# ---------------- AJUSTES DE JUGABILIDAD ----------------
const GRAVEDAD_LUNAR := 50.0          # px/s² hacia abajo (suave)
const EMPUJE_PROPULSOR := 150.0       # px/s² hacia arriba (debe ser > gravedad)
const VELOCIDAD_LATERAL := 140.0      # px/s máximos en X
const ACELERACION_LATERAL := 300.0    # qué tan rápido responde en X
const CONSUMO_COMBUSTIBLE := 24.0     # unidades de combustible por segundo
const VELOCIDAD_MAX_SEGURA := 60.0    # px/s: más que esto = impacto brusco
const DANO_IMPACTO := 25.0            # se resta a la integridad en cada choque
const VEL_MAX_BARRA := 300.0          # tope visual de la barra de velocidad

const COLOR_OK := Color(0.4, 1.0, 0.4)
const COLOR_PELIGRO := Color(1.0, 0.35, 0.3)

# ---------------- REFERENCIAS A NODOS ----------------
@onready var nave: CharacterBody2D = $Nave
@onready var cuerpo_nave: ColorRect = $Nave/Cuerpo
@onready var ventana_nave: ColorRect = $Nave/Ventana
@onready var sprite_nave: Sprite2D = $Nave/SpriteNave
@onready var fondo_imagen: TextureRect = $FondoImagen
@onready var llama: ColorRect = $Nave/Llama
@onready var zona_segura: Area2D = $Suelo/ZonaSegura

@onready var barra_combustible: ProgressBar = $UI/Panel/VBox/BarraCombustible
@onready var label_combustible: Label = $UI/Panel/VBox/LabelCombustible
@onready var barra_velocidad: ProgressBar = $UI/Panel/VBox/BarraVelocidad
@onready var label_velocidad: Label = $UI/Panel/VBox/LabelVelocidad
@onready var label_integridad: Label = $UI/Panel/VBox/LabelIntegridad
@onready var mensaje: Label = $UI/Mensaje

# ---------------- VARIABLES LOCALES ----------------
## Combustible con el que empieza cada intento. Editable desde el Inspector.
@export var combustible_maximo: float = 100.0
## Integridad con la que empieza la misión. Editable desde el Inspector.
@export var integridad_maxima: float = 100.0

var combustible: float = 0.0  # combustible actual del intento
var integridad: float = 0.0   # integridad actual (se conserva entre intentos)

## Ruta de la imagen de fondo. Cámbiala si guardas la imagen en otra carpeta.
@export_file("*.jpg", "*.png") var ruta_fondo: String = "res://scenes/Aterrizaje/fondo_luna2.jpg"
## Altura en píxeles a la que se escala el sprite de la nave.
@export var alto_sprite_nave: float = 40.0  # igual al alto de la colisión (30x40)

var terminado := false        # true cuando ya se aterrizó o se estrelló
var posicion_inicial := Vector2.ZERO


func _ready() -> void:
	posicion_inicial = nave.position
	integridad = integridad_maxima
	_cargar_fondo()
	_cargar_modelo_nave()
	barra_combustible.max_value = max(combustible_maximo, 1.0)
	barra_velocidad.max_value = VEL_MAX_BARRA
	_reiniciar_intento()


## Pone la nave arriba otra vez con el tanque lleno, sin tocar la integridad.
func _reiniciar_intento() -> void:
	combustible = combustible_maximo
	nave.position = posicion_inicial
	nave.velocity = Vector2.ZERO
	nave.modulate = Color.WHITE  # quita el tinte rojo del choque
	llama.visible = false
	mensaje.visible = false
	terminado = false
	_actualizar_ui()


# ---------------- APARIENCIA ----------------

func _cargar_fondo() -> void:
	if ruta_fondo != "" and ResourceLoader.exists(ruta_fondo):
		fondo_imagen.texture = load(ruta_fondo)
	else:
		push_warning("No se encontró la imagen de fondo: %s (se usa el color liso)" % ruta_fondo)


func _cargar_modelo_nave() -> void:
	# Lee el modelo elegido desde el Autoload "Mision".
	var datos: Dictionary = Mision.datos_nave()
	if not datos.has("capsula_img"):
		return
	var ruta: String = str(datos["capsula_img"])
	if not ResourceLoader.exists(ruta):
		push_warning("No se encontró la imagen de la nave: %s" % ruta)
		return

	var textura: Texture2D = load(ruta)
	sprite_nave.texture = textura
	sprite_nave.visible = true
	# Escalar el sprite para que mida 'alto_sprite_nave' px de alto, sin deformarlo
	var alto_textura: float = float(textura.get_height())
	if alto_textura > 0.0:
		var escala: float = alto_sprite_nave / alto_textura
		sprite_nave.scale = Vector2(escala, escala)
	# Oculta los cuadros de color placeholder
	cuerpo_nave.visible = false
	ventana_nave.visible = false


func _physics_process(delta: float) -> void:
	if terminado:
		return

	# --- Movimiento lateral (eje X): flechas o A/D ---
	var dir_x := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		dir_x += 1.0
	nave.velocity.x = move_toward(nave.velocity.x, dir_x * VELOCIDAD_LATERAL, ACELERACION_LATERAL * delta)

	# --- Gravedad lunar constante (Y positivo = hacia abajo en Godot) ---
	nave.velocity.y += GRAVEDAD_LUNAR * delta

	# --- Propulsor principal: Espacio, flecha Arriba o W ---
	var quiere_propulsar: bool = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var propulsando: bool = quiere_propulsar and combustible > 0.0

	if propulsando:
		nave.velocity.y -= EMPUJE_PROPULSOR * delta
		combustible = max(combustible - CONSUMO_COMBUSTIBLE * delta, 0.0)

	llama.visible = propulsando  # feedback visual del propulsor

	nave.move_and_slide()
	_limitar_a_pantalla()
	_actualizar_ui()


func _limitar_a_pantalla() -> void:
	var ancho: float = get_viewport_rect().size.x
	nave.position.x = clamp(nave.position.x, 15.0, ancho - 15.0)
	# Techo invisible para que no salga por arriba
	if nave.position.y < 20.0:
		nave.position.y = 20.0
		nave.velocity.y = max(nave.velocity.y, 0.0)


func _actualizar_ui() -> void:
	# Combustible
	barra_combustible.value = combustible
	label_combustible.text = "Combustible: %d" % ceili(combustible)
	label_combustible.modulate = COLOR_PELIGRO if combustible <= combustible_maximo * 0.2 else Color.WHITE

	# Velocidad de descenso (solo cuenta si va hacia abajo)
	var vel_descenso: float = max(nave.velocity.y, 0.0)
	barra_velocidad.value = min(vel_descenso, VEL_MAX_BARRA)
	label_velocidad.text = "Velocidad de descenso: %d (seguro <= %d)" % [roundi(vel_descenso), int(VELOCIDAD_MAX_SEGURA)]
	var color_vel: Color = COLOR_OK if vel_descenso <= VELOCIDAD_MAX_SEGURA else COLOR_PELIGRO
	label_velocidad.modulate = color_vel
	barra_velocidad.modulate = color_vel

	# Integridad
	label_integridad.text = "Integridad de la nave: %d%%" % roundi(integridad)


# ---------------- SEÑALES (body_entered) ----------------

## Conectada desde Suelo/ZonaSegura -> body_entered
func _on_zona_segura_body_entered(body: Node2D) -> void:
	if body != nave or terminado:
		return
	var vel_impacto: float = nave.velocity.y
	if vel_impacto <= VELOCIDAD_MAX_SEGURA:
		_victoria()
	else:
		_fallo("¡Impacto brusco!\nVelocidad: %d  (máx. segura %d)" % [roundi(vel_impacto), int(VELOCIDAD_MAX_SEGURA)])


## Conectada desde ZonaPeligrosaIzq y ZonaPeligrosaDer -> body_entered
func _on_zona_peligrosa_body_entered(body: Node2D) -> void:
	if body != nave or terminado:
		return
	_fallo("¡Caíste en un cráter!\nAlunizaje fuera de la plataforma")


# ---------------- RESULTADOS ----------------

func _detener_nave() -> void:
	terminado = true
	nave.velocity = Vector2.ZERO
	llama.visible = false


func _victoria() -> void:
	_detener_nave()
	# Asentar la nave justo encima de la plataforma
	var forma_zona: RectangleShape2D = $Suelo/ZonaSegura/CollisionShape2D.shape
	var forma_nave: RectangleShape2D = $Nave/CollisionShape2D.shape
	var tope_plataforma: float = zona_segura.global_position.y - forma_zona.size.y / 2.0
	nave.global_position.y = tope_plataforma - forma_nave.size.y / 2.0

	_mostrar_mensaje("¡Alunizaje exitoso!\nCombustible restante: %d" % ceili(combustible), COLOR_OK)
	_actualizar_ui()
	# Bitácora: alunizaje exitoso
	var bitacora = get_node_or_null("/root/Bitacora")
	if bitacora:
		bitacora.desbloquear_entrada("lunar_craters")
	mision_completada.emit()


func _fallo(texto: String) -> void:
	_detener_nave()
	nave.modulate = COLOR_PELIGRO  # tiñe de rojo la nave (sprite o placeholder)
	integridad = max(integridad - DANO_IMPACTO, 0.0)

	if integridad <= 0.0:
		texto += "\n\nNAVE DESTRUIDA - Misión fallida\n\nPresiona R para reiniciar la misión"
	else:
		texto += "\n-%d de integridad\n\nPresiona R para reintentar" % int(DANO_IMPACTO)
	_mostrar_mensaje(texto, COLOR_PELIGRO)
	_actualizar_ui()


func _mostrar_mensaje(texto: String, color: Color) -> void:
	mensaje.text = texto
	mensaje.modulate = color
	mensaje.visible = true


# ---------------- REINICIO ----------------

func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_R:
		if integridad <= 0.0:
			# Nave destruida: se reinicia toda la escena (integridad al 100 %).
			get_tree().reload_current_scene()
		else:
			# Otro intento conservando el daño recibido.
			_reiniciar_intento()
