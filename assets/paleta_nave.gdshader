// Cambia la paleta del tileset sin modificar la imagen.
// Toma el brillo de cada píxel y lo reemplaza por el color de la paleta
// que le corresponde (de oscuro a claro).
//
// Uso: en el TileMapLayer → Inspector → CanvasItem → Material →
//      Nuevo ShaderMaterial → Shader → Cargar → este archivo.
shader_type canvas_item;

// Paleta de la nave, de más oscuro a más claro
uniform vec4 col0 : source_color = vec4(0.0588, 0.0588, 0.1059, 1.0); // #0F0F1B contornos
uniform vec4 col1 : source_color = vec4(0.1137, 0.1255, 0.2000, 1.0); // #1D2033 sombra paredes
uniform vec4 col2 : source_color = vec4(0.1804, 0.2039, 0.3137, 1.0); // #2E3450 paredes
uniform vec4 col3 : source_color = vec4(0.2275, 0.2471, 0.3608, 1.0); // #3A3F5C piso
uniform vec4 col4 : source_color = vec4(0.3137, 0.3373, 0.4784, 1.0); // #50567A detalles piso
uniform vec4 col5 : source_color = vec4(0.5412, 0.5725, 0.6980, 1.0); // #8A92B2 metal
uniform vec4 col6 : source_color = vec4(0.9098, 0.9098, 0.9412, 1.0); // #E8E8F0 brillos

// Ajustes finos (muévelos en el Inspector si algo queda muy oscuro o muy claro)
uniform float brillo : hint_range(-0.5, 0.5) = 0.0;
uniform float contraste : hint_range(0.2, 3.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * contraste + 0.5 + brillo, 0.0, 1.0);
	float idx = floor(l * 6.999);

	vec3 c = col0.rgb;
	if (idx >= 1.0) c = col1.rgb;
	if (idx >= 2.0) c = col2.rgb;
	if (idx >= 3.0) c = col3.rgb;
	if (idx >= 4.0) c = col4.rgb;
	if (idx >= 5.0) c = col5.rgb;
	if (idx >= 6.0) c = col6.rgb;

	COLOR = vec4(c, tex.a) * COLOR;
}
