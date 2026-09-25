extends SceneTree
## 스팀 스토어용 투명 배경 로고(8단계 5/N, docs/STEAM.md). 실제 타이틀 화면과 같은 NeonText 컴포넌트를
## 투명 배경 SubViewport 에 그려서 뽑는다(파이썬으로 네온 합성을 다시 만들지 않고 엔진 렌더링을 그대로 재사용).
##
##   xvfb-run -a -s "-screen 0 640x360x24" godot --rendering-driver opengl3 -s tools/capture/gen_store_logo.gd
##
## tools/capture/store_assets/logo_transparent.png 에 저장(기록 전에 build/art_preview 처럼 비율 그대로 크롭·
## 정수 배율 확대). 이 결과물은 게임이 로드하는 실제 에셋이 아니라 마케팅용이라 assets/ 밖에 둔다 — assets/
## 안에 두면 test_ui_assets.gd 의 "36색 팔레트만 쓰는지" 검사에 걸린다(네온 발광 가장자리는 반투명 혼합색이라
## 팔레트 밖 색이 섞인다).

const OUT_DIR := "tools/capture/store_assets"
const CANVAS := Vector2i(400, 80)
const SCALE := 6
const PAD := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sv := SubViewport.new()
	sv.size = CANVAS
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	# NeonText.gd 를 이름(class_name)으로 바로 쓰면 -s 진입 스크립트가 컴파일 시점에 그 안의 RngService
	# 참조까지 앞당겨 읽어 "Identifier not found" 오류가 난다(CLAUDE.md 의 -s 스크립트 주의사항과 같은 원인,
	# tools/capture/capture.gd 의 정수 리터럴 우회와 같은 이유) — load().new() 로 우회한다.
	var neon: Control = load("res://scenes/fx/neon_text.gd").new()
	neon.set("atlas", load("res://assets/sprites/fx/neon_pink.png"))
	sv.add_child(neon)
	neon.call("set_text_value", "HOUSE EDGE", true)
	neon.position = Vector2(20, 20)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := sv.get_texture().get_image()
	var bbox := _opaque_bbox(image)
	var cropped := image.get_region(bbox)
	var out := Image.create(cropped.get_width() + PAD * 2, cropped.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
	out.blend_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), Vector2i(PAD, PAD))
	out.resize(out.get_width() * SCALE, out.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT_DIR))
	var path := OUT_DIR + "/logo_transparent.png"
	out.save_png(path)
	print("saved ", path, " ", out.get_size())
	quit(0)


func _opaque_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := 0
	var max_y := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
