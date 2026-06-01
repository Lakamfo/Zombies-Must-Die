extends Node

class_name DelayedSaverManager

var _timers: Dictionary[String, Timer] = { }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func trigger_delayed_call(id: String, delay: float, callback: Callable) -> void:
	if _timers.has(id):
		var timer: Timer = _timers[id]
		timer.stop()
		timer.start(delay)

		timer.timeout.connect(
			func():
				if callback.is_valid():
					callback.call()
				timer.queue_free()
				_timers.erase(id)
		)
	else:
		var timer := Timer.new()
		timer.name = "Timer_%s" % id
		timer.one_shot = true
		timer.timeout.connect(
			func():
				if callback.is_valid():
					callback.call()
				timer.queue_free()
				_timers.erase(id)
		)
		add_child(timer)
		_timers[id] = timer
		timer.start(delay)


func cancel(id: String) -> void:
	if _timers.has(id):
		_timers[id].queue_free()
		_timers.erase(id)


func cancel_all() -> void:
	for timer in _timers.values():
		timer.queue_free()
	_timers.clear()
