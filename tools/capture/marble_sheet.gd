extends SceneTree
## 구슬 재질 15종 비교 시트(ART_BIBLE 9장 검수용). 640×360 원본과 확대본을 저장한다.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 -s tools/capture/marble_sheet.gd -- lang=ko time=1.3
## 인자: lang=ko|en  time=<셰이더 TIME 을 이만큼 흘린 뒤 찍음>  out=<폴더>  bg=felt|dark

const DEFAULT_OUT := "res://tools/capture/out"
const UPSCALE := 3
const COLS := 5
const CELL := Vector2(128, 110)
const ORIGIN := Vector2(0, 26)

var sheet: Control
var out_dir: String = DEFAULT_OUT


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _args() -> Dictionary:
	var args := {"lang": "ko", "time": "1.3", "out": DEFAULT_OUT, "bg": "dark"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	return args


func _run() -> void:
	var args := _args()
	out_dir = String(args["out"])
	TranslationServer.set_locale(String(args["lang"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# -s 스크립트는 오토로드 이름을 컴파일 시점에 모르므로 시트 스크립트를 실행 중에 불러온다
	sheet = (load("res://tools/capture/marble_sheet_view.gd") as GDScript).new()
	sheet.set("dark", String(args["bg"]) != "felt")
	root.add_child(sheet)
	var wait := float(args["time"])
	await create_timer(wait).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var base := "%s/marble_sheet_%s" % [out_dir, String(args["lang"])]
	image.save_png(base + ".png")
	var big := image.duplicate() as Image
	big.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	big.save_png(base + "_x3.png")
	print("saved ", base)
	sheet.queue_free()
	await process_frame
	quit(0)
