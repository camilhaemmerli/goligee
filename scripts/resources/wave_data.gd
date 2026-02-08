class_name WaveData
extends Resource

@export var wave_number: int = 1
@export var wave_type: Enums.WaveType = Enums.WaveType.NORMAL
@export var spawn_sequences: Array[SpawnSequenceData] = []
@export var gold_bonus: int = 0
@export var pre_wave_delay: float = 5.0
