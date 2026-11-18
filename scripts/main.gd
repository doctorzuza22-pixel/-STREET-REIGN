extends Node3D

const ROAD_LENGTH := 240.0
var car: CharacterBody3D
var camera: Camera3D
var speed := 0.0
var cash := 2500
var reputation := 0
var police_timer := 0.0
var police_car: Node3D
var hud: Label
var touch_left := false
var touch_right := false
var touch_gas := false
var touch_brake := false

func _ready() -> void:
	_build_world()
	_build_car()
	_build_police()
	_build_hud()
	_setup_input()

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

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.82)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.15
	add_child(sun)

	_box("Road", Vector3(0, -0.12, -80), Vector3(18, 0.2, ROAD_LENGTH), Color(0.09, 0.1, 0.12))
	_box("Left shoulder", Vector3(-10, -0.08, -80), Vector3(2, 0.18, ROAD_LENGTH), Color(0.32, 0.31, 0.28))
	_box("Right shoulder", Vector3(10, -0.08, -80), Vector3(2, 0.18, ROAD_LENGTH), Color(0.32, 0.31, 0.28))
	for z in range(-195, 40, 12):
		_box("Lane marking", Vector3(0, 0.005, z), Vector3(0.18, 0.025, 5), Color(0.95, 0.88, 0.56))
		_box("Left line", Vector3(-8.7, 0.01, z), Vector3(0.12, 0.025, 7), Color(0.9, 0.9, 0.85))
		_box("Right line", Vector3(8.7, 0.01, z), Vector3(0.12, 0.025, 7), Color(0.9, 0.9, 0.85))

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in [-1, 1]:
		for i in range(18):
			var h := rng.randf_range(7.0, 27.0)
			var w := rng.randf_range(5.0, 10.0)
			var depth := rng.randf_range(7.0, 13.0)
			var z := -i * 13.0 - 8.0
			var x := side * rng.randf_range(17.0, 27.0)
			var shade := rng.randf_range(0.12, 0.32)
			_box("City building", Vector3(x, h / 2.0, z), Vector3(w, h, depth), Color(shade, shade * 1.15, shade * 1.3))
			for floor_i in range(1, int(h / 3.5)):
				_box("Window strip", Vector3(x, floor_i * 3.5, z + depth / 2.0 + 0.02), Vector3(w * 0.72, 0.65, 0.06), Color(0.65, 0.72, 0.78))

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	add_child(car)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.65, 4.0)
	body.mesh = mesh
	body.position.y = 0.75
	body.material_override = _mat(Color(0.72, 0.08, 0.045))
	car.add_child(body)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.55, 0.62, 1.85)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.35, 0.1)
	cabin.material_override = _mat(Color(0.07, 0.12, 0.17))
	car.add_child(cabin)

	for x: float in [-1.02, 1.02]:
		for z in [-1.25, 1.25]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.38
			wheel_mesh.bottom_radius = 0.38
			wheel_mesh.height = 0.22
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees.z = 90
			wheel.position = Vector3(x, 0.42, z)
			wheel.material_override = _mat(Color(0.025, 0.025, 0.03))
			car.add_child(wheel)

	car.position = Vector3(0, 0, 5)

	camera = Camera3D.new()
	camera.position = Vector3(0, 6.5, 12)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.current = true
	car.add_child(camera)

func _build_police() -> void:
	police_car = Node3D.new()
	police_car.position = Vector3(3.8, 0, -30)
	add_child(police_car)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.7, 4.0)
	body.mesh = mesh
	body.position.y = 0.75
	body.material_override = _mat(Color(0.82, 0.84, 0.86))
	police_car.add_child(body)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.2, 0.18, 0.3)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 1.22, 0)
	roof.material_override = _mat(Color(0.8, 0.04, 0.03))
	police_car.add_child(roof)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(hud)

	var title := Label.new()
	title.text = "STREET REIGN  |  SOUTH AFRICA"
	title.position = Vector2(24, 88)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22))
	layer.add_child(title)

	_add_touch_button(layer, "◀", Vector2(30, 570), "left")
	_add_touch_button(layer, "▶", Vector2(125, 570), "right")
	_add_touch_button(layer, "BRAKE", Vector2(920, 570), "brake")
	_add_touch_button(layer, "GAS", Vector2(1080, 570), "gas")

func _add_touch_button(layer: CanvasLayer, caption: String, pos: Vector2, kind: String) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = Vector2(82, 70)
	button.add_theme_font_size_override("font_size", 19)
	button.modulate = Color(1, 1, 1, 0.78)
	layer.add_child(button)
	button.button_down.connect(func(): _set_touch(kind, true))
	button.button_up.connect(func(): _set_touch(kind, false))

func _set_touch(kind: String, pressed: bool) -> void:
	match kind:
		"left": touch_left = pressed
		"right": touch_right = pressed
		"gas": touch_gas = pressed
		"brake": touch_brake = pressed

func _physics_process(delta: float) -> void:
	var throttle := Input.is_action_pressed("accelerate") or touch_gas
	var braking := Input.is_action_pressed("brake") or touch_brake
	var steering := Input.get_axis("steer_left", "steer_right")
	if touch_left: steering -= 1.0
	if touch_right: steering += 1.0
	if throttle:
		speed = move_toward(speed, 58.0, 24.0 * delta)
	elif braking:
		speed = move_toward(speed, -8.0, 34.0 * delta)
	else:
		speed = move_toward(speed, 0.0, 8.0 * delta)
	car.position.x = clampf(car.position.x + steering * (4.5 + absf(speed) * 0.06) * delta, -7.0, 7.0)
	car.position.z -= speed * delta
	if car.position.z < -170:
		car.position.z = 5
		reputation += 10
		cash += 500
	police_car.position.z = move_toward(police_car.position.z, car.position.z + 17.0, delta * (12.0 + absf(speed) * 0.12))
	police_car.position.x = move_toward(police_car.position.x, car.position.x + 2.6, delta * 2.0)
	police_timer += delta
	if police_timer > 20.0:
		police_timer = 0.0
		cash += 250
		reputation += 5
	hud.text = "R " + str(cash) + "     REP " + str(reputation) + "     SPEED " + str(int(absf(speed) * 3.6)) + " km/h"

func _box(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var item := StaticBody3D.new()
	item.name = label
	item.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color)
	item.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	item.add_child(collision)
	add_child(item)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
