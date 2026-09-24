extends "res://tests/lib/test_case.gd"
## 품질 기준 자동 검사: 팔레트 밖 색 없음, 기본 테마 대체, 번역 키 누락 없음, 효과음 파일.

const ASSET_DIRS: Array[String] = ["res://assets/sprites", "res://assets/ui", "res://assets/fonts"]
const CODE_DIRS: Array[String] = ["res://scenes", "res://scripts"]
const CSV_PATH := "res://translations/strings.csv"
## 번역 키처럼 생겼지만 번역하지 않는 문자열(네온 글자·칸 키 등).
const NOT_KEYS: Array[String] = ["JACKPOT", "LUCKY", "BIG WIN!", "SPIN", "HEADLESS"]


func _files(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(ext):
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		out.append_array(_files(dir_path.path_join(sub), ext))
	return out


func test_all_pixel_assets_use_palette() -> void:
	var allowed := {}
	for color: Color in Palette.ALL.values():
		allowed[color.to_rgba32() >> 8] = true
	var files: Array[String] = []
	for dir in ASSET_DIRS:
		files.append_array(_files(dir, ".png"))
	check(files.size() > 40, "PNG 에셋 %d개" % files.size())
	for path in files:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		image.convert(Image.FORMAT_RGBA8)
		var data := image.get_data()
		var bad := 0
		for i in range(0, data.size(), 4):
			if data[i + 3] == 0:
				continue
			var rgb := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			if not allowed.has(rgb):
				bad += 1
		check(bad == 0, "%s 팔레트 밖 픽셀 %d개" % [path, bad])


func test_project_theme_replaces_default() -> void:
	var path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	check_eq(path, "res://assets/ui/theme_main.tres", "프로젝트 기본 테마")
	var theme: Theme = load(path)
	check(theme != null and theme.default_font != null, "기본 글꼴 Galmuri")
	for type_name: String in ["Button", "Panel", "PanelContainer", "TooltipPanel", "VScrollBar", "HSlider", "CheckBox", "LineEdit", "ProgressBar"]:
		var styles := theme.get_stylebox_list(type_name)
		check(not styles.is_empty(), "%s 스타일 있음" % type_name)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		check(theme.has_stylebox(state, "Button"), "버튼 %s" % state)
	# 코드가 쓰는 theme_type_variation 이 테마에 모두 있다
	var regex := RegEx.create_from_string("theme_type_variation = \"([A-Za-z0-9]+)\"")
	var variations := {}
	for dir in CODE_DIRS:
		for file in _files(dir, ".gd"):
			for m in regex.search_all(FileAccess.get_file_as_string(file)):
				variations[m.get_string(1)] = file
	for name: String in variations.keys():
		check(theme.get_type_variation_base(name) != &"" or theme.get_type_list().has(name), "테마 변형 %s (%s)" % [name, variations[name]])
	check(variations.size() >= 10, "변형 %d개 검사" % variations.size())


func test_code_translation_keys_exist() -> void:
	var keys := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			keys[row[0]] = true
	var regex := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var used := {}
	for dir in CODE_DIRS:
		for path in _files(dir, ".gd"):
			for m in regex.search_all(FileAccess.get_file_as_string(path)):
				used[m.get_string(1)] = path
	check(used.size() > 30, "키 %d개 검사" % used.size())
	for key: String in used.keys():
		if NOT_KEYS.has(key):
			continue
		check(keys.has(key), "번역 키 %s (%s)" % [key, used[key]])


func test_sfx_files_exist() -> void:
	for id: String in AudioManager.SFX.keys():
		check(ResourceLoader.exists(AudioManager.SFX_DIR + id + ".wav"), "효과음 %s" % id)
	for bus: String in AudioManager.BUSES:
		check(AudioServer.get_bus_index(bus) >= 0, "버스 %s" % bus)

