extends AudioStreamPlayer

# Loops the ambient drone for atmosphere ("the Black").

func _ready() -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # frames (16-bit mono)
	play()
