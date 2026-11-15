class_name Mision
## Datos compartidos de la misión. No hay que configurar nada:
## cualquier script puede usar Mision.nave_elegida, Mision.presupuesto, etc.
## Las variables "static" no se borran al cambiar de escena.

static var presupuesto := 75_000_000
static var nave_elegida := ""   # "gemini4", "apollo11" o "artemis2"
static var presupuesto_restante := 75_000_000   # lo que queda después de pagar la nave

# Stats de 0 a 100. Los números son de juego, no datos oficiales:
# ajústenlos para balancear.
const NAVES := {
	"gemini4": {
		"nombre": "GEMINI IV",
		"cohete": "Titan II GLV",
		"anio": 1965,
		"tripulacion": 2,
		"duracion": "4 días",
		"destino": "Órbita terrestre",
		"costo": 18_000_000,
		"stats": {"propulsion": 35, "energia": 40, "masa": 25, "ciencia": 30, "comunicaciones": 45},
		"descripcion": "Nave pequeña y barata para misiones cortas en órbita.",
		"comentario": "La Gemini IV es chiquita pero confiable. En ella se hizo la primera caminata espacial de Estados Unidos. Barata, pero no llega lejos ni carga mucho.",
		"cohete_img": "res://assets/naves/gemini4_cohete.png",
		"capsula_img": "res://assets/naves/gemini4_capsula.png",
	},
	"apollo11": {
		"nombre": "APOLLO 11",
		"cohete": "Saturn V",
		"anio": 1969,
		"tripulacion": 3,
		"duracion": "8 días",
		"destino": "Superficie lunar",
		"costo": 52_000_000,
		"stats": {"propulsion": 95, "energia": 60, "masa": 90, "ciencia": 70, "comunicaciones": 60},
		"descripcion": "El cohete más poderoso de su época. Puede llegar a la Luna.",
		"comentario": "¡El Saturn V! Con él llegamos a la Luna por primera vez. Tiene muchísima potencia y carga, pero se come buena parte del presupuesto.",
		"cohete_img": "res://assets/naves/apollo11_cohete.png",
		"capsula_img": "res://assets/naves/apollo11_capsula.png",
	},
	"artemis2": {
		"nombre": "ARTEMIS II",
		"cohete": "SLS + Orion",
		"anio": 2026,
		"tripulacion": 4,
		"duracion": "10 días",
		"destino": "Sobrevuelo lunar",
		"costo": 68_000_000,
		"stats": {"propulsion": 90, "energia": 85, "masa": 80, "ciencia": 75, "comunicaciones": 90},
		"descripcion": "Tecnología moderna: paneles solares y comunicaciones de primera.",
		"comentario": "Artemis II lleva cuatro tripulantes alrededor de la Luna. Es la más moderna y la mejor en energía y comunicaciones... pero casi no te deja dinero para lo demás.",
		"cohete_img": "res://assets/naves/artemis2_cohete.png",
		"capsula_img": "res://assets/naves/artemis2_capsula.png",
	},
}

# Orden en el que aparecen en la pantalla de selección
const ORDEN := ["gemini4", "apollo11", "artemis2"]


# ---------- Stats que se usan en el ascenso (salen de los stats de cada nave) ----------

## Golpes que aguanta la nave. Más capacidad de masa = casco más fuerte.
static func vida_max(id: String) -> int:
	return 2 + int(round(NAVES[id].stats.masa / 25.0))


## Qué tan rápido se mueve a los lados. Las naves ligeras son más ágiles.
static func maniobra(id: String) -> float:
	return 420.0 - NAVES[id].stats.masa * 2.4


static func maniobra_texto(id: String) -> String:
	var m := maniobra(id)
	if m >= 300.0:
		return "ÁGIL"
	if m >= 215.0:
		return "MEDIA"
	return "LENTA"


## Segundos que tarda en llegar a la exosfera. Más propulsión = sube más rápido.
static func duracion_ascenso(id: String) -> float:
	return 75.0 - NAVES[id].stats.propulsion * 0.25


static func datos_nave() -> Dictionary:
	return NAVES.get(nave_elegida, {})


static func dinero(cantidad: int) -> String:
	# 75000000 -> "$75,000,000"
	var texto := str(cantidad)
	var resultado := ""
	var contador := 0
	for i in range(texto.length() - 1, -1, -1):
		resultado = texto[i] + resultado
		contador += 1
		if contador % 3 == 0 and i > 0:
			resultado = "," + resultado
	return "$" + resultado
