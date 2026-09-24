extends Node
## 효과음·음악 재생(2단계에서 버튼음·코인음, 8단계에서 전체 사운드).
## 계획: SFX 풀(AudioStreamPlayer 여러 개) + 음악 크로스페이드, 버스 Master/Music/SFX, 설정 볼륨 연동.


func play_sfx(_id: String) -> void:
	pass


func play_music(_id: String, _fade_seconds: float = 0.0) -> void:
	pass
