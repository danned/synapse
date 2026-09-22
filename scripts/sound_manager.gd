class_name SoundManager
extends Node

const MUSIC := {
	&"ambient": preload("res://assets/audio/music/airy.ogg"),
	&"combat": preload("res://assets/audio/music/pulse.ogg"),
	&"boss": preload("res://assets/audio/music/urgent.ogg")
}
const SFX := {
	&"click": preload("res://assets/audio/sfx/click.ogg"),
	&"launch": preload("res://assets/audio/sfx/launch.ogg"),
	&"wave_complete": preload("res://assets/audio/sfx/wave_complete.ogg"),
	&"unlock": preload("res://assets/audio/sfx/unlock.ogg"),
	&"draft": preload("res://assets/audio/sfx/draft.ogg"),
	&"rewire": preload("res://assets/audio/sfx/rewire.ogg"),
	&"recycle": preload("res://assets/audio/sfx/recycle.ogg"),
	&"error": preload("res://assets/audio/sfx/error.ogg"),
	&"place": preload("res://assets/audio/sfx/place.ogg"),
	&"cryo": preload("res://assets/audio/sfx/cryo.ogg"),
	&"arc": preload("res://assets/audio/sfx/arc.ogg"),
	&"lance": preload("res://assets/audio/sfx/lance.ogg"),
	&"enemy_down": preload("res://assets/audio/sfx/enemy_down.ogg"),
	&"leak": preload("res://assets/audio/sfx/leak.ogg"),
	&"sever": preload("res://assets/audio/sfx/sever.ogg"),
	&"victory": preload("res://assets/audio/sfx/victory.ogg")
}
const COOLDOWNS := {&"arc": 75, &"cryo": 100, &"lance": 120, &"enemy_down": 90, &"leak": 180, &"sever": 300}
const MAX_EFFECTS := 12

var volume := 0.7
var music_volume := 0.45
var music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _music_tween: Tween
var current_music: StringName = &""
var _effect_players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}

func _ready() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		add_child(player)
		music_players.append(player)
	_update_music_volume()

func set_sound_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_update_music_volume()

func _update_music_volume() -> void:
	if music_players.is_empty():
		return
	var target_db := linear_to_db(maxf(music_volume * 0.55, 0.0001))
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	for index in range(music_players.size()):
		music_players[index].volume_db = target_db if index == _active_music_index else -60.0
		if index != _active_music_index:
			music_players[index].stop()

func play_music(music_id: StringName) -> void:
	if current_music == music_id or not MUSIC.has(music_id):
		return
	current_music = music_id
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	var old_player := music_players[_active_music_index]
	_active_music_index = 1 - _active_music_index
	var next_player := music_players[_active_music_index]
	next_player.stop()
	var stream: AudioStreamOggVorbis = MUSIC[music_id]
	stream.loop = true
	next_player.stream = stream
	next_player.volume_db = -60.0 if old_player.playing else linear_to_db(maxf(music_volume * 0.55, 0.0001))
	next_player.play()
	if old_player.playing:
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(old_player, "volume_db", -60.0, 0.35)
		_music_tween.tween_property(next_player, "volume_db", linear_to_db(maxf(music_volume * 0.55, 0.0001)), 0.35)
		_music_tween.finished.connect(old_player.stop)

func play_sfx(event: StringName) -> void:
	if volume <= 0.01 or not SFX.has(event):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(event, -10000)) < int(COOLDOWNS.get(event, 0)):
		return
	if _effect_players.size() >= MAX_EFFECTS:
		return
	_last_played[event] = now
	var player := AudioStreamPlayer.new()
	player.stream = SFX[event]
	player.volume_db = linear_to_db(maxf(volume * 0.65, 0.0001))
	add_child(player)
	_effect_players.append(player)
	player.finished.connect(func():
		_effect_players.erase(player)
		player.queue_free()
	)
	player.play()
