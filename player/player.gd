extends CharacterBody3D

@onready var info_label: Label = $Head/Camera3D/InfoLabel

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 1.0

const FLY_SPEED = 50.0
const FLY_VELOCITY = 25.0

var is_captured := true
var fly_mode := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	
func _process(_delta: float) -> void:
	info_label.text = 'FPS: ' + str(Engine.get_frames_per_second()) + '\nPositon: ' + str(position)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed('ui_up'):
		fly_mode = not fly_mode
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_pressed("jump") and (is_on_floor() or fly_mode):
		velocity.y =  FLY_VELOCITY if fly_mode else JUMP_VELOCITY
	
	if Input.is_action_just_pressed('ui_cancel'):
		if is_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		is_captured = not is_captured

	# Get the input direction and handle the movement/deceleration.wwwwwwww
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * (FLY_SPEED if fly_mode else SPEED)
		velocity.z = direction.z * (FLY_SPEED if fly_mode else SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, FLY_SPEED if fly_mode else SPEED)
		velocity.z = move_toward(velocity.z, 0, FLY_SPEED if fly_mode else SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_captured:
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		$Head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		$Head.rotation.x = clamp($Head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
