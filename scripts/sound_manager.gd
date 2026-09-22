class_name SoundManager
extends Node

var volume := 0.7

func play_tone(frequency: float, duration: float = 0.08, strength: float = 0.22) -> void:
	if volume <= 0.01:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = maxf(0.15, duration + 0.05)
	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = linear_to_db(clampf(volume * strength, 0.001, 1.0))
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	var frames := PackedVector2Array()
	var count := int(generator.mix_rate * duration)
	frames.resize(count)
	for index in range(count):
		var t := float(index) / generator.mix_rate
		var envelope := 1.0 - float(index) / maxf(1.0, count)
		var sample := sin(TAU * frequency * t) * envelope
		frames[index] = Vector2(sample, sample)
	playback.push_buffer(frames)
	get_tree().create_timer(duration + 0.08).timeout.connect(player.queue_free)
