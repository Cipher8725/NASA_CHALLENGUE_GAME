class_name PhotoTools
extends RefCounted

## Ayudas para preparar la foto del carnet: recortar al tamaño de la foto
## del carnet y ponerle el casco de astronauta encima.

## Tamaño de la foto del carnet (proporción del recuadro de la foto, 170 x 196).
const CARD_PHOTO_SIZE: Vector2i = Vector2i(340, 392)
const HELMET_PATH: String = "res://ai_assets/textures/carnet/casco_overlay.png"

## Recorta la imagen por el centro (sin deformarla) y la deja del tamaño del carnet.
static func crop_to_card(source: Image, mirror: bool = false) -> Image:
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var target_ratio: float = float(CARD_PHOTO_SIZE.x) / float(CARD_PHOTO_SIZE.y)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var crop: Rect2i
	if float(w) / float(h) > target_ratio:
		var new_w: int = int(round(h * target_ratio))
		crop = Rect2i((w - new_w) / 2, 0, new_w, h)
	else:
		var new_h: int = int(round(w / target_ratio))
		crop = Rect2i(0, (h - new_h) / 2, w, new_h)
	var result: Image = image.get_region(crop)
	result.resize(CARD_PHOTO_SIZE.x, CARD_PHOTO_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if mirror:
		result.flip_x()
	return result

## Devuelve una copia de la foto con el casco de astronauta encima.
static func add_helmet(photo: Image) -> Image:
	var result: Image = photo.duplicate() as Image
	result.convert(Image.FORMAT_RGBA8)
	var helmet_tex: Texture2D = load(HELMET_PATH) as Texture2D
	if helmet_tex == null:
		return result
	var helmet: Image = helmet_tex.get_image()
	helmet.decompress()
	helmet.convert(Image.FORMAT_RGBA8)
	if helmet.get_size() != result.get_size():
		helmet.resize(result.get_width(), result.get_height(), Image.INTERPOLATE_BILINEAR)
	result.blend_rect(helmet, Rect2i(Vector2i.ZERO, helmet.get_size()), Vector2i.ZERO)
	return result
