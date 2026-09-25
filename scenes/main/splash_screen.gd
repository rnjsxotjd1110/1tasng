class_name SplashScreen
extends Control
## 부팅 스플래시(8단계 1/N). 개발사 로고를 잠깐 보여주고 타이틀 화면으로 넘어간다. run/main_scene.
## 클릭·Space·Enter 로 즉시 건너뛸 수 있다.

const SCREEN := Vector2(640, 360)
const LOGO := preload("res://assets/sprites/title/dev_logo.png")
const FADE_IN := 0.4
const HOLD := 1.1
const FADE_OUT := 0.35
const NEXT_SCENE := "res://scenes/main/TitleScreen.tscn"

var _logo: TextureRect
var _advancing: bool = false


func _ready() -> void:
	CursorTheme.apply(get_tree())
	LetterboxFit.apply(self)
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Palette.VOID
	bg.size = SCREEN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.position = ((SCREEN - LOGO.get_size()) * 0.5).round()
	_logo.size = LOGO.get_size()
	_logo.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	var tween := create_tween()
	tween.tween_property(_logo, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_property(_logo, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(_advance)


func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_advance()
		get_viewport().set_input_as_handled()
