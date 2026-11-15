class_name AstronautCardView
extends PanelContainer

## Muestra un `AstronautCard` como un carnet de identificación:
## foto, nombre, número, rango, nivel de acceso, base, fechas, chip y código de barras.
## Solo muestra datos: no los cambia.

## Color de la insignia de cada nivel de acceso (el índice es el nivel).
@export var level_colors: Array[Color] = [Color(0.5, 0.5, 0.5), Color(0.25, 0.65, 1.0), Color(1.0, 0.62, 0.15), Color(0.9, 0.25, 0.3)]

@onready var _photo: TextureRect = %Photo
@onready var _name: Label = %NameValue
@onready var _number: Label = %NumberValue
@onready var _rank: Label = %RankValue
@onready var _base: Label = %BaseValue
@onready var _issued: Label = %IssuedValue
@onready var _expires: Label = %ExpiresValue
@onready var _level_badge: PanelContainer = %LevelBadge
@onready var _level_label: Label = %LevelValue
@onready var _barcode: CardBarcode = %Barcode
@onready var _barcode_text: Label = %BarcodeText

func show_card(card: AstronautCard) -> void:
	if card == null:
		return
	_photo.texture = card.get_avatar_texture()
	_name.text = card.nombre.to_upper() if not card.nombre.is_empty() else tr("SIN NOMBRE")
	_number.text = card.numero
	_rank.text = tr(card.get_rank())
	_base.text = tr(card.base)
	_issued.text = card.fecha_emision
	_expires.text = card.fecha_vencimiento
	_level_label.text = tr("NIVEL %d") % card.nivel_acceso
	var style: StyleBoxFlat = (_level_badge.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = level_colors[clampi(card.nivel_acceso, 0, level_colors.size() - 1)]
	_level_badge.add_theme_stylebox_override("panel", style)
	_barcode.code = card.numero
	_barcode_text.text = card.numero.replace("-", " ")
