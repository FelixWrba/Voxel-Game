extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var mesh: MeshInstance3D = $Mesh
@export var cube_material: Material

const CHUNK_SIZE = Vector3i(16, 128, 16)
const RENDER_DISTANCE = 2

var chunks: Dictionary = {}
var noise = FastNoiseLite.new()

enum Voxel { AIR, GRASS, DIRT, STONE, GRAVEL, SAND, SNOW }

var voxel_colors: Dictionary[Voxel, Color] = {
	Voxel.GRASS: Color.LIME_GREEN,
	Voxel.DIRT: Color.SADDLE_BROWN,
	Voxel.STONE: Color.DIM_GRAY,
	Voxel.GRAVEL: Color.DARK_GRAY,
	Voxel.SAND: Color.LIGHT_YELLOW,
	Voxel.SNOW: Color.SNOW,
}

var c_surface_array: Array = []
var c_vertices = PackedVector3Array()
var c_normals = PackedVector3Array()
var c_colors = PackedColorArray()

var cube_vertices: Array[Vector3] = [
	Vector3(-0.5, -0.5, 0.5),
	Vector3(0.5, -0.5, 0.5),
	Vector3(0.5, -0.5, -0.5),
	Vector3(-0.5, -0.5, -0.5),
	Vector3(-0.5, 0.5, 0.5),
	Vector3(0.5, 0.5, 0.5),
	Vector3(0.5, 0.5, -0.5),
	Vector3(-0.5, 0.5, -0.5),
]

enum Face { BOTTOM, FRONT, RIGHT, TOP, LEFT, BACK }

var face_indices: Dictionary[Face, Array] = {
	Face.FRONT: [[5, 1, 0], [0, 4, 5]],
	Face.BACK: [[2, 7, 3], [2, 6, 7]],
	Face.LEFT: [[3, 7, 4], [3, 4, 0]],
	Face.RIGHT: [[1, 5, 6], [1, 6, 2]],
	Face.BOTTOM: [[0, 1, 2], [0, 2, 3]],
	Face.TOP: [[4, 7, 6], [4, 6, 5]],
}

var face_normals: Dictionary[Face, Vector3] = {
	Face.FRONT: Vector3(0, 0, 1),
	Face.BACK: Vector3(0, 0, -1),
	Face.LEFT: Vector3(-1, 0, 0),
	Face.RIGHT: Vector3(1, 0, 0),
	Face.BOTTOM: Vector3(0, -1, 0),
	Face.TOP: Vector3(0, 1, 0),
}

var face_colors: Dictionary[Face, Color] = {
	Face.FRONT: Color.RED,
	Face.BACK: Color.YELLOW,
	Face.LEFT: Color.RED,
	Face.RIGHT: Color.GREEN,
	Face.BOTTOM: Color.WHITE,
	Face.TOP: Color.BLACK,
}

func _ready() -> void:
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
	noise.seed = 83
	noise.fractal_octaves = 4
	noise.frequency = 0.02

func _process(_delta: float) -> void:
	var chunk_position := Vector3(
		floor((player.position.x) / CHUNK_SIZE.x), 
		floor(player.position.y / CHUNK_SIZE.y),
		floor((player.position.z) / CHUNK_SIZE.z)
	)
	remove_chunks(chunk_position)
	spawn_chunks(chunk_position)
	#create_chunk_mesh(create_chunk_data(Vector3.ZERO), Vector3.ZERO)
	
func remove_chunks(chunk_pos: Vector3):
	var start_x = chunk_pos.x - RENDER_DISTANCE
	var start_z = chunk_pos.z - RENDER_DISTANCE
	var end_x = chunk_pos.x + RENDER_DISTANCE
	var end_z = chunk_pos.z + RENDER_DISTANCE
	
	for chunk_x in chunks:
		for chunk_z in chunks[chunk_x]:
			if chunk_x < start_x or chunk_x > end_x or chunk_z < start_z or chunk_z > end_z:
				chunks[chunk_x][chunk_z].mesh.queue_free()
				chunks[chunk_x].erase(chunk_z)
		if chunks[chunk_x].size() == 0:
			chunks.erase(chunk_x)
	
func spawn_chunks(chunk_pos: Vector3) -> void:
	for x in range(chunk_pos.x - RENDER_DISTANCE, chunk_pos.x + RENDER_DISTANCE + 1):
		if not chunks.has(x):
			chunks[x] = {}
		for z in range(chunk_pos.z - RENDER_DISTANCE, chunk_pos.z + RENDER_DISTANCE + 1):
			if not chunks[x].has(z):
				var new_pos = Vector3(x, 0, z)
				var new_chunk_data := create_chunk_data(new_pos)
				var new_chunk_mesh := create_chunk_mesh(new_chunk_data, new_pos)
				chunks[x][z] = {
					'mesh': new_chunk_mesh,
					'data': new_chunk_data
				}

func create_chunk_data(chunk_pos: Vector3) -> Dictionary[Vector3, Voxel]:
	var chunk: Dictionary[Vector3, Voxel] = {}
	const DIRT_HEIGHT = 4
	const BASE_LEVEL = 32
	const GRASS_LEVEL = 64
	const STONE_LEVEL = 96
	
	for x in range(CHUNK_SIZE.x):
		for y in range(CHUNK_SIZE.y):
			for z in range(CHUNK_SIZE.z):
				var global_x = x + chunk_pos.x * CHUNK_SIZE.x
				var global_z = z + chunk_pos.z * CHUNK_SIZE.z
				var big = noise.get_noise_2d(global_x * 0.2, global_z * 0.2) * 64
				var medium = noise.get_noise_2d(global_x * 0.5, global_z * 0.5) * 16
				var small = noise.get_noise_2d(global_x, global_z) * 8
				var GROUND_LEVEL = clamp(round(pow((big + medium + small + BASE_LEVEL), 1.1)), 4, 128)
				var voxel: Voxel = Voxel.AIR
				
				if y == GROUND_LEVEL:
					if GROUND_LEVEL < (BASE_LEVEL - 2):
						voxel = Voxel.GRAVEL
					elif GROUND_LEVEL < (BASE_LEVEL + 2):
						voxel = Voxel.SAND
					elif GROUND_LEVEL < GRASS_LEVEL:
						voxel = Voxel.GRASS
					elif GROUND_LEVEL < STONE_LEVEL:
						voxel = Voxel.STONE
					else:
						voxel = Voxel.SNOW
				elif y < GROUND_LEVEL:
					if y < (BASE_LEVEL - 2):
						voxel = Voxel.GRAVEL
					elif y < (BASE_LEVEL + 2):
						voxel = Voxel.SAND
					elif y < GRASS_LEVEL and y > (GROUND_LEVEL - DIRT_HEIGHT):
						voxel = Voxel.DIRT
					else:
						voxel = Voxel.STONE
				chunk[Vector3(x, y, z)] = voxel
	return chunk

func create_chunk_mesh(chunk_data: Dictionary[Vector3, Voxel], chunk_pos: Vector3) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	
	for pos in chunk_data:
		var voxel: Voxel = chunk_data[pos]
		if voxel == Voxel.AIR:
			continue
		
		var world_pos = Vector3(
			chunk_pos.x * CHUNK_SIZE.x + pos.x,
			pos.y,
			chunk_pos.z * CHUNK_SIZE.z + pos.z,
		)
		
		if is_air(chunk_data, pos + Vector3.UP):
			add_face_to_arrays(Face.TOP, world_pos, vertices, normals, colors, voxel_colors[voxel])
		if is_air(chunk_data, pos + Vector3.DOWN):
			add_face_to_arrays(Face.BOTTOM, world_pos, vertices, normals, colors, voxel_colors[voxel])
		if is_air(chunk_data, pos + Vector3.LEFT):
			add_face_to_arrays(Face.LEFT, world_pos, vertices, normals, colors, voxel_colors[voxel])
		if is_air(chunk_data, pos + Vector3.RIGHT):
			add_face_to_arrays(Face.RIGHT, world_pos, vertices, normals, colors, voxel_colors[voxel])
		if is_air(chunk_data, pos + Vector3.BACK):
			add_face_to_arrays(Face.FRONT, world_pos, vertices, normals, colors, voxel_colors[voxel])
		if is_air(chunk_data, pos + Vector3.FORWARD):
			add_face_to_arrays(Face.BACK, world_pos, vertices, normals, colors, voxel_colors[voxel])
	
	var surface_array := []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	array_mesh.surface_set_material(0, cube_material)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = array_mesh.create_trimesh_shape()
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	add_child(static_body)
	
	return mesh_instance

func is_air(chunk_data: Dictionary[Vector3, Voxel], pos: Vector3) -> bool:
	if not chunk_data.has(pos):
		return true
	
	return chunk_data[pos] == Voxel.AIR

func add_face_to_arrays(
	face: Face,
	face_position: Vector3,
	vertices: PackedVector3Array, 
	normals: PackedVector3Array, 
	colors: PackedColorArray,
	face_color: Color,
) -> void:
	var indices := face_indices[face]
	for triangle in indices:
		for index in triangle:
			vertices.append(cube_vertices[index] + face_position)
			normals.append(face_normals[face])
			colors.append(face_color)
