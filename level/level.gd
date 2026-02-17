extends Node3D

@onready var player: CharacterBody3D = $Player

const CHUNK_SIZE = Vector3i(8, 8, 8)
const RENDER_DISTANCE = 16

enum VOXEL {
	GRASS,
	DIRT,
	STONE,
}

var chunks: Dictionary = {}

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	var chunk_position := Vector3(
		round(player.position.x / CHUNK_SIZE.x), 
		round(player.position.y / CHUNK_SIZE.y),
		round(player.position.z / CHUNK_SIZE.z)
	)
	delete_chunks(chunk_position)
	create_chunks(chunk_position)
	
func delete_chunks(chunk_pos: Vector3):
	var start_x = chunk_pos.x - RENDER_DISTANCE
	var start_z = chunk_pos.z - RENDER_DISTANCE
	var end_x = chunk_pos.x + RENDER_DISTANCE
	var end_z = chunk_pos.z + RENDER_DISTANCE
	
	for chunk_x in chunks:
		for chunk_z in chunks[chunk_x]:
			if chunk_x != clamp(chunk_x, start_x, end_x) or chunk_z != clamp(chunk_z, start_z, end_z):
				chunks[chunk_x].erase(chunk_z)
		if chunks[chunk_x].size() == 0:
			chunks.erase(chunk_x)
	
func create_chunks(chunk_pos: Vector3):
	for x in range(chunk_pos.x - RENDER_DISTANCE, chunk_pos.x + RENDER_DISTANCE):
		if not chunks.has(x):
			chunks[x] = {}
		for z in range(chunk_pos.z - RENDER_DISTANCE, chunk_pos.z + RENDER_DISTANCE):
			if not chunks[x].has(z):
				chunks[x][z] = create_chunk(chunk_pos)

func create_chunk(_chunk_pos: Vector3) -> Dictionary[Vector3, VOXEL]:
	var chunk := {}
	
	
	return chunk
