extends Node
var last_rider_hit: Dictionary = {}
var rider_hit_count = 0
var engine: AudioStreamPlayer
var airflow: AudioStreamPlayer
var siren: AudioStreamPlayer
var crowd: AudioStreamPlayer
var music: AudioStreamPlayer
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index = 0
var muted = false
var music_enabled = true
var master_volume = 0.8
var siren_gain = 0.0
var siren_pitch = 1.0

func _ready() -> void:
	AudioServer.set_bus_layout(load("res://assets/default_bus_layout.tres"))
	if DisplayServer.get_name()=="headless": return
	for key in ["hit","crash","swing","nitro","click","count","go","pickup","finish","defeat","landing","pain0","pain1","pain2","whip"]:
		sounds[key] = load("res://assets/audio/"+key+".wav")
	for i in 12:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		voices.append(p)
	engine = _loop("engine","SFX",-20)
	music = _loop("music","Music",-7)
	siren = _loop("siren","SFX",-80)
	crowd = _loop("crowd","SFX",-80)
	airflow = _loop("airflow","SFX",-80)

func _loop(key: String, bus_name: String, volume: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/"+key+".wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	p.stream = stream
	p.bus = bus_name
	p.volume_db = volume
	add_child(p)
	p.play()
	return p

func sfx(key: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	if DisplayServer.get_name()=="headless": return
	if not sounds.has(key): return
	var p = voices[voice_index%voices.size()]
	voice_index += 1
	p.stream = sounds[key]
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()

func update_audio(dt: float, speed: float, boost: bool, racing: bool) -> void:
	if not engine: return
	engine.pitch_scale = lerpf(engine.pitch_scale,0.65+speed/40.0,1-exp(-dt*5))
	engine.volume_db = lerpf(engine.volume_db,(-14.0 if boost else -19.0) if racing else -34.0,dt*4)
	music.volume_db = lerpf(music.volume_db,-8.0 if racing else -13.0,dt*3)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),not music_enabled)
	AudioServer.set_bus_mute(0,muted)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,master_volume))-4.0)

func shutdown() -> void:
	for p in [siren,crowd,airflow]:
		if p:
			p.stop()
			p.stream=null
	for p in voices:
		p.stop()
		p.stream = null
	if engine:
		engine.stop()
		engine.stream = null
	if music:
		music.stop()
		music.stream = null
	sounds.clear()

func _exit_tree() -> void:
	shutdown()

func update_world_audio(remaining: float, pursuit: float, racing: bool, dt: float = 0.016667, pitch: float = 1.0) -> void:
	var smoothing=1-exp(-dt*8)
	siren_gain=lerpf(siren_gain,clampf(pursuit,0,1) if racing else 0.0,smoothing)
	siren_pitch=lerpf(siren_pitch,clampf(pitch,0.78,1.28) if racing else 1.0,smoothing)
	if not siren: return
	siren.volume_db=linear_to_db(maxf(0.0001,siren_gain*0.6))
	siren.pitch_scale=siren_pitch
	crowd.volume_db=linear_to_db(maxf(0.0001,(1-clampf(absf(remaining)/300,0,1))*0.75)) if racing else -80

func update_air_audio(dt: float, speed: float, airborne: bool) -> void:
	if not airflow: return
	var gain=clampf(speed/130.0,0,1)*0.75 if airborne else 0.0
	airflow.volume_linear=lerpf(airflow.volume_linear,gain,1-exp(-dt*5))
	airflow.pitch_scale=0.85+speed/300.0

func rider_hit(id: int, separation: float = 0.0, heavy: bool = false) -> void:
	if separation>90: return
	var voice=posmod(id,3) if id>=0 else 0
	var pitch=0.86+posmod(id,5)*0.065 if id>=0 else 1.04
	if heavy: pitch*=0.92
	var gain=1-clampf(separation/100.0,0,0.9)
	last_rider_hit={"id":id,"sound":"pain%d"%voice,"pitch":pitch,"heavy":heavy,"gain":gain}
	rider_hit_count+=1
	sfx(last_rider_hit.sound,-5.0+linear_to_db(maxf(0.1,gain)),pitch)
