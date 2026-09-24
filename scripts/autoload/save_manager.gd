extends Node
## 저장·불러오기(4단계에서 구현).
## 계획: user://save.json 에 GameState.to_dict() + RngService.get_state() + 설정을 저장.
## 임시 파일에 쓴 뒤 교체(원자적 저장), 백업 1개 유지, 버전 필드로 마이그레이션.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


func save_game() -> bool:
	push_warning("SaveManager.save_game: 4단계에서 구현 예정")
	return false


func load_game() -> bool:
	push_warning("SaveManager.load_game: 4단계에서 구현 예정")
	return false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
