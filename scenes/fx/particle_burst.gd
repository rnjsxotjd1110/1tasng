class_name ParticleBurst
extends Node2D
## CPUParticles2D 한 번 터뜨리고 스스로 사라지는 연출(칩 파티클·코인 분수·클로버).
## 크기 변화 없이(정수 배율 유지) 알파만 사라진다.

enum Kind { CHIPS, COINS, CLOVERS }

const SCENE_PATH := "res://scenes/fx/ParticleBurst.tscn"
const CHIP2 := preload("res://assets/sprites/ui/particle_chip2.png")
const CHIP3 := preload("res://assets/sprites/ui/particle_chip3.png")
const COIN := preload("res://assets/sprites/ui/coin.png")
const CLOVER := preload("res://assets/sprites/ui/particle_clover.png")
const COIN_FRAMES := 4
const CLEANUP_MARGIN := 0.2

var _life: float = 1.0


## parent 의 pos(부모 좌표)에서 터뜨린다. amount = 입자 수.
static func spawn(parent: Node, kind: Kind, pos: Vector2, amount: int) -> ParticleBurst:
	var burst: ParticleBurst = load(SCENE_PATH).instantiate()
	burst.position = pos.round()
	parent.add_child(burst)
	match kind:
		Kind.CHIPS:
			burst._emitter(CHIP2, amount / 2, 0.9, Vector2(0, -1), 80.0, 60.0, 140.0, 300.0)
			burst._emitter(CHIP3, amount - amount / 2, 0.9, Vector2(0, -1), 80.0, 50.0, 120.0, 300.0)
		Kind.COINS:
			var coins := burst._emitter(COIN, amount, 1.5, Vector2(0, -1), 22.0, 150.0, 230.0, 340.0)
			var material := CanvasItemMaterial.new()
			material.particles_animation = true
			material.particles_anim_h_frames = COIN_FRAMES
			material.particles_anim_v_frames = 1
			material.particles_anim_loop = true
			coins.material = material
			coins.anim_speed_min = 1.5
			coins.anim_speed_max = 3.0
			coins.explosiveness = 0.55
		Kind.CLOVERS:
			burst._emitter(CLOVER, amount, 0.8, Vector2(0, -1), 180.0, 30.0, 70.0, 60.0)
	return burst


func _emitter(texture: Texture2D, amount: int, lifetime: float, direction: Vector2, spread: float,
		speed_min: float, speed_max: float, gravity_y: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector2(0, gravity_y)
	particles.randomness = 0.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	particles.color_ramp = ramp
	particles.emitting = true
	add_child(particles)
	_life = maxf(_life, lifetime)
	return particles


func _process(delta: float) -> void:
	_life -= delta
	if _life < -CLEANUP_MARGIN:
		queue_free()
