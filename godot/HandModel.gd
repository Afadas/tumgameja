extends Node3D

# ตัวแปรสำหรับรับค่าระยะทางของมือจากภายนอก
var hand_distance: float = 0.0

# ช่วงระยะทางของมือที่ต้องการให้โมเดลเคลื่อนที่
@export var min_distance: float = 1.0
@export var max_distance: float = 5.0

# ช่วงตำแหน่งของโมเดลบนแกน Z ที่ต้องการให้โมเดลเคลื่อนที่
@export var min_position: float = -1.0
@export var max_position: float = 1.0

# โหนด MeshInstance3D ที่แสดงโมเดลมือ (เปลี่ยนชื่อเป็น sphere)
@onready var sphere: MeshInstance3D = $sphere

func _ready():
	# ตรวจสอบว่า sphere ถูกโหลดแล้วหรือไม่
	if sphere == null:
		printerr("Error: sphere not found! Please check the node name and scene tree structure.")
	else:
		print("sphere found!")

func _process(_delta: float) -> void:
	# ตรวจสอบว่า sphere ถูกโหลดแล้วหรือไม่
	if sphere == null:
		return

	# แปลงระยะทางของมือเป็นตำแหน่งบนแกน Z ของโมเดล
	var z_position = lerp(min_position, max_position, (hand_distance - min_distance) / (max_distance - min_distance))

	# กำหนดตำแหน่งของโมเดล
	sphere.translation.z = z_position

	# (เพิ่มเติม) หากต้องการปรับสเกลของโมเดลตามระยะทางของมือ
	# var scale_factor = lerp(1.0, 0.5, (hand_distance - min_distance) / (max_distance - min_distance))
	# sphere.scale = Vector3(scale_factor, scale_factor, scale_factor)

func set_hand_distance(distance: float) -> void:
	# ฟังก์ชันสำหรับรับค่าระยะทางของมือจากภายนอก
	hand_distance = distance
