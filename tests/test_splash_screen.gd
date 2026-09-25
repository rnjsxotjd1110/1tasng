extends "res://tests/lib/test_case.gd"
## SplashScreen: 로고가 투명하게 시작해 정확히 배치되는지만 확인한다. _advance() 는 실제로
## get_tree().change_scene_to_file() 를 부르므로(스킵 입력·트윈 완료 시) 여기서는 절대 호출하지
## 않는다 — 공유 SceneTree 오염 방지(test_title_screen.gd 와 같은 이유).

var splash: SplashScreen


func before_each() -> void:
	super.before_each()
	splash = SplashScreen.new()
	tree.root.add_child(splash)


func after_each() -> void:
	super.after_each()
	_disconnect_all()
	splash.free()
	splash = null


func test_logo_starts_transparent_and_centered() -> void:
	check_eq(splash._logo.modulate.a, 0.0, "로고가 투명하게 시작(페이드인 전)")
	var expected := ((SplashScreen.SCREEN - splash._logo.size) * 0.5).round()
	check_eq(splash._logo.position, expected, "로고가 화면 중앙에 배치됨")


func test_advancing_flag_starts_false() -> void:
	check(not splash._advancing, "아직 전환 시작 전")
