extends Panel

const RECORD_CONTAINER = preload("uid://c5mogkio0hycl")
@onready var h_box_container = $margin_container/scroll_container/h_box_container


func _ready():
	ServerRequests.getted_leaderboard.connect(
		func build(data : Dictionary):
			if not data:
				return
			if not data.get('response'):
				return
			
			var count: int = 0
			for dict in data.response:
				var instance = RECORD_CONTAINER.instantiate()
				instance.find_child('wave').text = str(int(dict.max_wave))
				instance.find_child('username').text = str(dict.login)
				instance.find_child('score').text = str(int(dict.max_score))
				instance.find_child('duration').text = seconds_to_hms_string(dict.max_lifetime)
				instance.find_child('location').text = str(dict.location)
				instance.find_child('date').text = str(dict.date) if not dict.date == null else "-"
				
				#if TranslationServer.get_locale() == "ru":
				#	instance.find_child('date').text = str(dict.date) if not dict.date == null else "-"
				#else:
					#instance.find_child('date').text = str(dict.date_raw) if not dict.date_raw == null else "-"

				h_box_container.add_child(instance)

				count += 1
				if count >= 30:
					break
	)
	ServerRequests.get_leaderboard()


func seconds_to_hms_string(seconds: int) -> String:
	var hours: int = floor(seconds) / 3600.0
	var minutes: int = floor(seconds % 3600) / 60
	var secs = seconds % 60

	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2) + ":" + str(secs).pad_zeros(2)
