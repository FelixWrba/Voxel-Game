extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var mesh: MeshInstance3D = $Mesh
@export var cube_material: Material

const CHUNK_SIZE = Vector3i(16, 64, 16)
const RENDER_DISTANCE = 2

var chunks: Dictionary = {}

enum Voxel { AIR, GRASS, DIRT, STONE }

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
	Face.BACK: Color.ORANGE,
	Face.LEFT: Color.YELLOW,
	Face.RIGHT: Color.GREEN,
	Face.BOTTOM: Color.BLUE,
	Face.TOP: Color.PURPLE,
}

func _ready() -> void:
	c_surface_array.resize(Mesh.ARRAY_MAX)
	generate_mesh()
	
func generate_mesh() -> void:
	add_face(Face.FRONT, Vector3.ZERO)
	add_face(Face.BACK, Vector3.ZERO)
	add_face(Face.LEFT, Vector3.ZERO)
	add_face(Face.RIGHT, Vector3.ZERO)
	add_face(Face.TOP, Vector3.ZERO)
	add_face(Face.BOTTOM, Vector3.ZERO)
	commit_mesh()

func add_face(face: Face, position: Vector3) -> void:
	var indices := face_indices[face]
	for triangle in indices:
		for index in triangle:
			c_vertices.append(cube_vertices[index] + position)
			c_normals.append(face_normals[face])
			c_colors.append(face_colors[face])

func commit_mesh() -> void:
	c_surface_array[Mesh.ARRAY_VERTEX] = c_vertices
	c_surface_array[Mesh.ARRAY_NORMAL] = c_normals
	c_surface_array[Mesh.ARRAY_COLOR] = c_colors
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c_surface_array)
	mesh.mesh.surface_set_material(0, cube_material)

func _process(_delta: float) -> void:
	var chunk_position := Vector3(
		round(player.position.x / CHUNK_SIZE.x), 
		round(player.position.y / CHUNK_SIZE.y),
		round(player.position.z / CHUNK_SIZE.z)
	)
	remove_chunks(chunk_position)
	spawn_chunks(chunk_position)
	
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
	for x in range(chunk_pos.x - RENDER_DISTANCE, chunk_pos.x + RENDER_DISTANCE):
		if not chunks.has(x):
			chunks[x] = {}
		for z in range(chunk_pos.z - RENDER_DISTANCE, chunk_pos.z + RENDER_DISTANCE):
			if not chunks[x].has(z):
				var new_chunk_data := create_chunk_data(chunk_pos)
				var new_chunk_mesh := create_chunk_mesh(new_chunk_data, chunk_pos)
				chunks[x][z] = {
					'mesh': new_chunk_mesh, 
					'data': new_chunk_data
				}

func create_chunk_data(_chunk_pos: Vector3) -> Dictionary[Vector3, Voxel]:
	var chunk: Dictionary[Vector3, Voxel] = {}
	const GROUND_LEVEL = 10
	const DIRT_HEIGHT = 4
	
	for x in range(CHUNK_SIZE.x):
		for y in range(CHUNK_SIZE.y):
			for z in range(CHUNK_SIZE.z):
				if y > GROUND_LEVEL:
					chunk[Vector3(x, y, z)] = Voxel.AIR
				elif y == GROUND_LEVEL:
					chunk[Vector3(x, y, z)] = Voxel.GRASS
				elif y > GROUND_LEVEL - DIRT_HEIGHT:
					chunk[Vector3(x, y, z)] = Voxel.DIRT
				else:
					chunk[Vector3(x, y, z)] = Voxel.STONE
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
			add_face_to_arrays(Face.TOP, world_pos, vertices, normals, colors)
		if is_air(chunk_data, pos + Vector3.DOWN):
			add_face_to_arrays(Face.BOTTOM, world_pos, vertices, normals, colors)
		if is_air(chunk_data, pos + Vector3.LEFT):
			add_face_to_arrays(Face.LEFT, world_pos, vertices, normals, colors)
		if is_air(chunk_data, pos + Vector3.RIGHT):
			add_face_to_arrays(Face.RIGHT, world_pos, vertices, normals, colors)
		if is_air(chunk_data, pos + Vector3.FORWARD):
			add_face_to_arrays(Face.FRONT, world_pos, vertices, normals, colors)
		if is_air(chunk_data, pos + Vector3.BACK):
			add_face_to_arrays(Face.BACK, world_pos, vertices, normals, colors)
	
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
	add_child(mesh_instance)
	
	return mesh_instance

func is_air(chunk_data: Dictionary[Vector3, Voxel], position: Vector3) -> bool:
	if not chunk_data.has(position):
		return true
	
	return chunk_data[position] == Voxel.AIR

func add_face_to_arrays(
	face: Face, 
	face_position: Vector3,
	vertices: PackedVector3Array, 
	normals: PackedVector3Array, 
	colors: PackedColorArray,
) -> void:
	var indices := face_indices[face]
	for triangle in indices:
		for index in triangle:
			vertices.append(cube_vertices[index] + face_position)
			normals.append(face_normals[face])
			colors.append(face_colors[face])
