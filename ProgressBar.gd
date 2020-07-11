extends ProgressBar

onready var PCKRequest = get_parent().get_parent().get_node("PCKRequest")

func _ready():
	pass

func _process(delta):
	if get_parent().visible:
		max_value = PCKRequest.get_body_size()
		value = PCKRequest.get_downloaded_bytes()
