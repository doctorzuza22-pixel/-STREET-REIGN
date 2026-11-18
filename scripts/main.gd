extends Node3D

const ROAD_LENGTH := 420.0
const AUDIO_RATE := 22050.0
var car: CharacterBody3D
var camera: Camera3D
var speed := 0.0
var cash := 2500
var reputation := 0
var police_car: Node3D
var police_light_red: OmniLight3D
var police_light_blue: OmniLight3D
var hud: Label
var touch_left := false
var touch_right := false
var touch_gas := false
var touch_brake := false
var wheel_nodes: Array[Node3D] = []
var music_player: AudioStreamPlayer
var effects_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var effects_playback: AudioStreamGeneratorPlayback
var music_clock := 0.0
var engine_phase := 0.0
var siren_phase := 0.0
var fx_clock := 0.0
var gear_shift_timer := 0.0
var crash_timer := 0.0
var crash_cooldown := 0.0
var previous_gear := 0
var music_enabled := true
var effects_enabled := true
var distance_score := 0.0
var street_lights: Array[OmniLight3D] = []

func _ready() -> void:
	_setup_world_environment()
	_build_city()
	_build_car()
	_build_police()
	_build_hud()
	_setup_input()
	_setup_audio()

func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.25, 0.38)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.13, 0.20)
	env.fog_density = 0.008
	world_env.environment = env
	add_child(world_env)

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.025, 0.075)
	sky_mat.sky_horizon_color = Color(0.10, 0.13, 0.22)
	sky_mat.ground_bottom_color = Color(0.015, 0.018, 0.03)
	sky_mat.ground_horizon_color = Color(0.10, 0.12, 0.17)
	sky.sky_material = sky_mat
	env.sky = sky

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, -28, 0)
	moon.light_color = Color(0.48, 0.58, 0.82)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	add_child(moon)

func _build_city() -> void:
	var asphalt := _material(Color(0.045, 0.052, 0.068), 0.12, 0.28)
	_box("M1 city road", Vector3(0, -0.15, -185), Vector3(23, 0.3, ROAD_LENGTH), asphalt)
	_box("Left pavement", Vector3(-12.2, -0.02, -185), Vector3(1.5, 0.35, ROAD_LENGTH), _material(Color(0.20, 0.20, 0.20), 0.0, 0.85))
	_box("Right pavement", Vector3(12.2, -0.02, -185), Vector3(1.5, 0.35, ROAD_LENGTH), _material(Color(0.20, 0.20, 0.20), 0.0, 0.85))
	_box("Left barrier", Vector3(-13.1, 0.55, -185), Vector3(0.25, 1.0, ROAD_LENGTH), _material(Color(0.12, 0.14, 0.17), 0.35, 0.35))
	_box("Right barrier", Vector3(13.1, 0.55, -185), Vector3(0.25, 1.0, ROAD_LENGTH), _material(Color(0.12, 0.14, 0.17), 0.35, 0.35))

	for z in range(-395, 35, 10):
		_box("Centre dash", Vector3(0, 0.018, z), Vector3(0.16, 0.035, 4.5), _material(Color(1.0, 0.82, 0.30), 0.0, 0.5, Color(0.8, 0.58, 0.12)))
	for z in range(-395, 35, 18):
		_box("Lane divider", Vector3(-5.7, 0.018, z), Vector3(0.10, 0.025, 7.0), _material(Color(0.78, 0.82, 0.88), 0.0, 0.5))
		_box("Lane divider", Vector3(5.7, 0.018, z), Vector3(0.10, 0.025, 7.0), _material(Color(0.78, 0.82, 0.88), 0.0, 0.5))

	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for side in [-1, 1]:
		for i in range(27):
			var z := -i * 15.0 - 8.0
			var h := rng.randf_range(13.0, 42.0)
			var w := rng.randf_range(8.0, 13.0)
			var d := rng.randf_range(8.0, 14.0)
			var x := float(side) * rng.randf_range(20.0, 30.0)
			var base := Color(rng.randf_range(0.07, 0.16), rng.randf_range(0.09, 0.18), rng.randf_range(0.14, 0.25))
			_box("Jozi tower", Vector3(x, h * 0.5, z), Vector3(w, h, d), _material(base, 0.35, 0.45))
			for floor_i in range(1, int(h / 3.2)):
				for window_side in [-1, 1]:
					var wx := x + float(window_side) * w * 0.23
					var lit := rng.randf() > 0.35
					var window_color := Color(1.0, 0.68, 0.32) if lit else Color(0.10, 0.18, 0.27)
					_box("Tower window", Vector3(wx, floor_i * 3.2, z + d * 0.5 + 0.035), Vector3(w * 0.24, 0.72, 0.07), _material(window_color, 0.0, 0.25, window_color if lit else Color.BLACK))
			if i % 3 == 0:
				_add_streetlight(float(side) * 10.4, z + 3.0)

	_add_jozi_landmarks()
	_add_city_sign(-7.6, -72.0, "JOHANNESBURG  |  M1")
	_add_city_sign(7.6, -205.0, "PRETORIA  ↑   N1")
	_add_city_sign(-7.6, -325.0, "SANDTON  •  NEXT EXIT")

func _add_jozi_landmarks() -> void:
	# Distinctive Hillbrow Tower silhouette on the skyline.
	_cylinder("Hillbrow tower shaft", Vector3(-47, 28, -118), 2.2, 56.0, _material(Color(0.28, 0.31, 0.36), 0.45, 0.35))
	_cylinder("Hillbrow observation deck", Vector3(-47, 51, -118), 4.0, 3.2, _material(Color(0.18, 0.22, 0.28), 0.55, 0.3))
	_cylinder("Hillbrow antenna", Vector3(-47, 62, -118), 0.22, 19.0, _material(Color(0.55, 0.58, 0.64), 0.6, 0.25))
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(-47, 72, -118)
	beacon.light_color = Color(1.0, 0.08, 0.05)
	beacon.light_energy = 2.0
	beacon.omni_range = 18.0
	add_child(beacon)

	# Ponte City-inspired cylindrical landmark.
	_cylinder("Ponte City tower", Vector3(48, 30, -165), 11.0, 60.0, _material(Color(0.24, 0.28, 0.34), 0.25, 0.42))
	_cylinder("Ponte inner core", Vector3(48, 31, -165), 4.2, 61.0, _material(Color(0.055, 0.07, 0.10), 0.1, 0.8))
	for y in range(5, 58, 6):
		_cylinder("Ponte floor band", Vector3(48, y, -165), 11.08, 0.42, _material(Color(0.43, 0.47, 0.53), 0.4, 0.38))

func _add_city_sign(x: float, z: float, words: String) -> void:
	var post := _box("Road sign post", Vector3(x, 3.2, z), Vector3(0.16, 6.4, 0.16), _material(Color(0.55, 0.58, 0.62), 0.65, 0.25))
	var board := _box("Green route sign", Vector3(x, 6.0, z), Vector3(5.2, 1.55, 0.18), _material(Color(0.015, 0.20, 0.12), 0.1, 0.35))
	var label := Label3D.new()
	label.text = words
	label.font_size = 48
	label.pixel_size = 0.012
	label.position = Vector3(x, 6.0, z - 0.12)
	label.rotation_degrees.y = 0 if x < 0 else 180
	label.modulate = Color.WHITE
	add_child(label)

func _add_streetlight(x: float, z: float) -> void:
	_box("Streetlight pole", Vector3(x, 4.0, z), Vector3(0.14, 8.0, 0.14), _material(Color(0.12, 0.14, 0.18), 0.75, 0.3))
	_box("Streetlight arm", Vector3(x + (1.2 if x < 0 else -1.2), 7.8, z), Vector3(2.4, 0.12, 0.12), _material(Color(0.14, 0.16, 0.20), 0.65, 0.3))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(x + (2.2 if x < 0 else -2.2), 7.6, z)
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 1.1
	lamp.omni_range = 18.0
	add_child(lamp)
	street_lights.append(lamp)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	add_child(car)
	_add_player_car_model(car)
	car.position = Vector3(0, 0, 7)

	camera = Camera3D.new()
	camera.position = Vector3(0, 4.2, 10.8)
	camera.rotation_degrees = Vector3(-13.5, 0, 0)
	camera.fov = 78.0
	camera.current = true
	car.add_child(camera)
	var headlight := SpotLight3D.new()
	headlight.position = Vector3(0, 1.0, -1.5)
	headlight.rotation_degrees = Vector3(-5, 0, 0)
	headlight.light_color = Color(0.78, 0.86, 1.0)
	headlight.light_energy = 3.2
	headlight.spot_range = 48.0
	headlight.spot_angle = 34.0
	car.add_child(headlight)

func _add_player_car_model(parent: Node3D) -> void:
	_box_child(parent, "Lower chassis", Vector3(0, 0.62, 0), Vector3(2.05, 0.48, 4.55), _material(Color(0.62, 0.025, 0.018), 0.62, 0.24))
	_box_child(parent, "Sculpted hood", Vector3(0, 0.91, -1.22), Vector3(1.96, 0.20, 1.55), _material(Color(0.78, 0.035, 0.022), 0.72, 0.2))
	_box_child(parent, "Roof", Vector3(0, 1.48, 0.12), Vector3(1.62, 0.65, 1.95), _material(Color(0.56, 0.025, 0.02), 0.65, 0.22))
	_box_child(parent, "Front windscreen", Vector3(0, 1.49, -0.83), Vector3(1.48, 0.48, 0.06), _material(Color(0.025, 0.065, 0.095), 0.25, 0.12))
	_box_child(parent, "Rear glass", Vector3(0, 1.49, 1.08), Vector3(1.48, 0.44, 0.06), _material(Color(0.025, 0.065, 0.095), 0.25, 0.12))
	_box_child(parent, "Front bumper", Vector3(0, 0.47, -2.26), Vector3(2.1, 0.28, 0.28), _material(Color(0.045, 0.05, 0.06), 0.4, 0.28))
	_box_child(parent, "Rear diffuser", Vector3(0, 0.43, 2.27), Vector3(2.05, 0.26, 0.25), _material(Color(0.025, 0.03, 0.04), 0.5, 0.25))
	_box_child(parent, "Front grille", Vector3(0, 0.68, -2.405), Vector3(0.88, 0.22, 0.035), _material(Color(0.012, 0.014, 0.018), 0.3, 0.3))
	for side in [-1, 1]:
		_box_child(parent, "LED headlamp", Vector3(float(side) * 0.69, 0.83, -2.31), Vector3(0.48, 0.18, 0.06), _material(Color(0.72, 0.9, 1.0), 0.1, 0.16, Color(0.62, 0.82, 1.0)))
		_box_child(parent, "Rear tail lamp", Vector3(float(side) * 0.72, 0.82, 2.30), Vector3(0.48, 0.18, 0.06), _material(Color(1.0, 0.025, 0.015), 0.1, 0.2, Color(1.0, 0.015, 0.01)))
		_box_child(parent, "Side skirt", Vector3(float(side) * 1.02, 0.43, 0), Vector3(0.12, 0.18, 2.7), _material(Color(0.035, 0.04, 0.05), 0.45, 0.28))
		for z in [-1.48, 1.48]:
			var wheel := _cylinder_child(parent, "Performance wheel", Vector3(float(side) * 1.05, 0.47, z), 0.43, 0.28, _material(Color(0.018, 0.02, 0.025), 0.15, 0.8))
			wheel.rotation_degrees.z = 90
			wheel_nodes.append(wheel)
			var rim := _cylinder_child(parent, "Alloy rim", Vector3(float(side) * 1.205, 0.47, z), 0.23, 0.035, _material(Color(0.48, 0.52, 0.58), 0.85, 0.22))
			rim.rotation_degrees.z = 90

func _build_police() -> void:
	police_car = Node3D.new()
	police_car.position = Vector3(3.5, 0, -28)
	add_child(police_car)
	_box_child(police_car, "Police sedan body", Vector3(0, 0.65, 0), Vector3(2.08, 0.58, 4.5), _material(Color(0.78, 0.82, 0.86), 0.48, 0.26))
	_box_child(police_car, "Police roof", Vector3(0, 1.35, 0.1), Vector3(1.58, 0.54, 1.85), _material(Color(0.025, 0.04, 0.065), 0.35, 0.18))
	_box_child(police_car, "Police bonnet", Vector3(0, 0.96, -1.35), Vector3(1.98, 0.16, 1.4), _material(Color(0.82, 0.85, 0.89), 0.5, 0.25))
	_box_child(police_car, "Police front grille", Vector3(0, 0.66, -2.28), Vector3(1.05, 0.2, 0.04), _material(Color(0.015, 0.02, 0.03), 0.5, 0.3))
	_box_child(police_car, "Police lightbar", Vector3(0, 1.66, 0.0), Vector3(1.25, 0.14, 0.32), _material(Color(0.08, 0.1, 0.13), 0.35, 0.2))
	police_light_red = OmniLight3D.new()
	police_light_red.position = Vector3(-0.48, 1.78, 0)
	police_light_red.light_color = Color(1.0, 0.02, 0.015)
	police_light_red.light_energy = 0.0
	police_light_red.omni_range = 13.0
	police_car.add_child(police_light_red)
	police_light_blue = OmniLight3D.new()
	police_light_blue.position = Vector3(0.48, 1.78, 0)
	police_light_blue.light_color = Color(0.02, 0.18, 1.0)
	police_light_blue.light_energy = 0.0
	police_light_blue.omni_range = 13.0
	police_car.add_child(police_light_blue)
	for side in [-1, 1]:
		for z in [-1.48, 1.48]:
			var wheel := _cylinder_child(police_car, "Police wheel", Vector3(float(side) * 1.06, 0.45, z), 0.4, 0.25, _material(Color(0.02, 0.02, 0.025), 0.1, 0.8))
			wheel.rotation_degrees.z = 90

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hud)

	var district := Label.new()
	district.text = "JOHANNESBURG  •  M1 HIGHWAY"
	district.position = Vector2(24, 64)
	district.add_theme_font_size_override("font_size", 16)
	district.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	root.add_child(district)

	var music_button := _hud_button(root, "MUSIC ON", Vector2(-250, 18), Vector2(112, 42), true)
	music_button.pressed.connect(_toggle_music.bind(music_button))
	var effects_button := _hud_button(root, "SFX ON", Vector2(-128, 18), Vector2(104, 42), true)
	effects_button.pressed.connect(_toggle_effects.bind(effects_button))

	_hud_button(root, "◀", Vector2(24, -104), Vector2(78, 76), false, true).button_down.connect(func(): touch_left = true)
	_hud_button(root, "◀", Vector2(24, -104), Vector2(78, 76), false, true).button_up.connect(func(): touch_left = false)
	_hud_button(root, "▶", Vector2(112, -104), Vector2(78, 76), false, true).button_down.connect(func(): touch_right = true)
	_hud_button(root, "▶", Vector2(112, -104), Vector2(78, 76), false, true).button_up.connect(func(): touch_right = false)
	var brake := _hud_button(root, "BRAKE", Vector2(-238, -104), Vector2(92, 76), true, true)
	brake.button_down.connect(func(): touch_brake = true)
	brake.button_up.connect(func(): touch_brake = false)
	var gas := _hud_button(root, "GAS", Vector2(-132, -104), Vector2(104, 76), true, true)
	gas.button_down.connect(func(): touch_gas = true)
	gas.button_up.connect(func(): touch_gas = false)

func _hud_button(root: Control, caption: String, offset: Vector2, size: Vector2, right: bool, bottom: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.size = size
	if right:
		button.anchor_left = 1.0
		button.anchor_right = 1.0
	else:
		button.anchor_left = 0.0
		button.anchor_right = 0.0
	if bottom:
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + size.x
	button.offset_bottom = offset.y + size.y
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.05, 0.075, 0.82)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.55, 0.06, 0.035, 0.95)))
	root.add_child(button)
	return button

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.82, 0.84, 0.88, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func _setup_input() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var keys := {
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT]
	}
	for action in keys:
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	var music_stream := AudioStreamGenerator.new()
	music_stream.mix_rate = int(AUDIO_RATE)
	music_stream.buffer_length = 0.35
	music_player.stream = music_stream
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	effects_player = AudioStreamPlayer.new()
	var effects_stream := AudioStreamGenerator.new()
	effects_stream.mix_rate = int(AUDIO_RATE)
	effects_stream.buffer_length = 0.35
	effects_player.stream = effects_stream
	add_child(effects_player)
	effects_player.play()
	effects_playback = effects_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	_fill_music_buffer()
	_fill_effects_buffer()
	if gear_shift_timer > 0.0:
		gear_shift_timer = maxf(0.0, gear_shift_timer - delta)
	if crash_timer > 0.0:
		crash_timer = maxf(0.0, crash_timer - delta)
	if crash_cooldown > 0.0:
		crash_cooldown = maxf(0.0, crash_cooldown - delta)
	var flash := sin(Time.get_ticks_msec() * 0.012) > 0.0
	if police_light_red != null:
		police_light_red.light_energy = 2.6 if flash else 0.15
		police_light_blue.light_energy = 0.15 if flash else 2.6

func _fill_music_buffer() -> void:
	if music_playback == null:
		return
	for i in range(music_playback.get_frames_available()):
		var t := music_clock
		var beat_phase := fposmod(t, 0.5)
		var bar_phase := fposmod(t, 2.0)
		var kick := 0.0
		if beat_phase < 0.13:
			var k := beat_phase / 0.13
			kick = sin((48.0 - 28.0 * k) * TAU * beat_phase) * exp(-k * 5.0) * 0.30
		var bass_note := 55.0 if bar_phase < 1.0 else 65.4
		var bass := sin(TAU * bass_note * t) * 0.09
		var clap := 0.0
		if (bar_phase > 0.48 and bar_phase < 0.57) or (bar_phase > 1.48 and bar_phase < 1.57):
			clap = (sin(TAU * 180.0 * t) + sin(TAU * 263.0 * t)) * 0.04
		var hat_phase := fposmod(t, 0.25)
		var hat := sin(TAU * 6200.0 * t) * (1.0 - hat_phase / 0.018) * 0.02 if hat_phase < 0.018 else 0.0
		var sample := (kick + bass + clap + hat) if music_enabled else 0.0
		music_playback.push_frame(Vector2(sample, sample))
		music_clock += 1.0 / AUDIO_RATE

func _fill_effects_buffer() -> void:
	if effects_playback == null:
		return
	var throttle := Input.is_action_pressed("accelerate") or touch_gas
	var steering := absf(Input.get_axis("steer_left", "steer_right"))
	if touch_left or touch_right:
		steering = 1.0
	var engine_hz := 48.0 + absf(speed) * 2.1 + (18.0 if throttle else 0.0)
	var siren_near := absf(police_car.position.z - car.position.z) < 65.0
	for i in range(effects_playback.get_frames_available()):
		var engine := (sin(engine_phase) + 0.28 * sin(engine_phase * 2.0)) * (0.035 + absf(speed) / 58.0 * 0.12)
		engine_phase = fposmod(engine_phase + TAU * engine_hz / AUDIO_RATE, TAU)
		var siren := 0.0
		if siren_near:
			var siren_hz := 690.0 if sin(TAU * fx_clock * 1.4) > 0.0 else 920.0
			siren = sin(siren_phase) * 0.09
			siren_phase = fposmod(siren_phase + TAU * siren_hz / AUDIO_RATE, TAU)
		var tyre := (sin(TAU * 1750.0 * fx_clock) + sin(TAU * 2310.0 * fx_clock)) * 0.03 if absf(speed) > 20.0 and steering > 0.55 else 0.0
		var gear := sin(TAU * 115.0 * fx_clock) * (gear_shift_timer / 0.22) * 0.18 if gear_shift_timer > 0.0 else 0.0
		var crash := (sin(TAU * 83.0 * fx_clock) + sin(TAU * 137.0 * fx_clock)) * (crash_timer / 0.35) * 0.2 if crash_timer > 0.0 else 0.0
		var sample := (engine + siren + tyre + gear + crash) if effects_enabled else 0.0
		effects_playback.push_frame(Vector2(sample, sample))
		fx_clock += 1.0 / AUDIO_RATE

func _toggle_music(button: Button) -> void:
	music_enabled = not music_enabled
	button.text = "MUSIC ON" if music_enabled else "MUSIC OFF"

func _toggle_effects(button: Button) -> void:
	effects_enabled = not effects_enabled
	button.text = "SFX ON" if effects_enabled else "SFX OFF"

func _physics_process(delta: float) -> void:
	var throttle := Input.is_action_pressed("accelerate") or touch_gas
	var braking := Input.is_action_pressed("brake") or touch_brake
	var steering := Input.get_axis("steer_left", "steer_right")
	if touch_left:
		steering -= 1.0
	if touch_right:
		steering += 1.0
	steering = clampf(steering, -1.0, 1.0)
	if throttle:
		speed = move_toward(speed, 72.0, 27.0 * delta)
	elif braking:
		speed = move_toward(speed, -7.0, 38.0 * delta)
	else:
		speed = move_toward(speed, 0.0, 7.0 * delta)

	var next_x := car.position.x + steering * (4.0 + absf(speed) * 0.075) * delta
	if (next_x < -9.2 or next_x > 9.2) and absf(speed) > 18.0 and crash_cooldown <= 0.0:
		crash_timer = 0.35
		crash_cooldown = 1.2
		speed *= 0.72
	car.position.x = clampf(next_x, -9.4, 9.4)
	car.position.z -= speed * delta
	for wheel in wheel_nodes:
		wheel.rotate_x(delta * speed * 0.9)
	distance_score += absf(speed) * delta
	if car.position.z < -360.0:
		car.position.z = 7.0
		distance_score = 0.0
		reputation += 10
		cash += 500

	police_car.position.z = move_toward(police_car.position.z, car.position.z + 15.0, delta * (13.0 + absf(speed) * 0.16))
	police_car.position.x = move_toward(police_car.position.x, car.position.x + 2.5, delta * 2.5)
	police_car.position.z = maxf(police_car.position.z, car.position.z + 8.0)
	var current_gear := int(absf(speed) / 14.0)
	if current_gear > previous_gear and previous_gear >= 0:
		gear_shift_timer = 0.22
	previous_gear = current_gear
	if distance_score > 850.0:
		distance_score = 0.0
		reputation += 5
		cash += 250
	hud.text = "R %s     REP %s     %03d km/h" % [cash, reputation, int(absf(speed) * 3.6)]

func _box(label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _box_child(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item

func _cylinder(label: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	add_child(item)
	return item

func _cylinder_child(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.5, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow != Color.BLACK:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 1.4
	return material
