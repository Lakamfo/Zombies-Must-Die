extends Node

var URL : String = "https://debian-n100.taila0bfdd.ts.net/"

const Secret = preload("res://classes/secret/secret.gd")
const CLIENT_SECRET = Secret.CLIENT_SECRET


var local_player_id: int = -1
var is_logged: bool = false

var session_token: String = ""
var session_hmac_secret: String = ""

var current_run_id: String = ""
var current_run_secret: String = ""

var crypto := Crypto.new()

signal response_failed(error: String)

signal getted_record(result, location)
signal getted_leaderboard(result)
signal getted_game_version(version: String)

signal player_registred(success: bool, error: String)
signal player_logged(success: bool, error: String)
signal player_stats_getted(result: Dictionary)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var args = OS.get_cmdline_args()
	var is_custom_ip = "--ip" in args

	if is_custom_ip:
		var arg_index : int = args.find("--ip")

		if args.size() > arg_index:
			var custom_ip_or_url : String = args[arg_index + 1]

			if custom_ip_or_url.contains("https://") or custom_ip_or_url.contains("http://"):
				URL = custom_ip_or_url
			else:
				URL = "http://%s" % custom_ip_or_url

	set_physics_process(false)
	set_process(false)
	set_process_input(false)


#region Helpers

func get_current_date() -> String:
	var date = Time.get_datetime_dict_from_system()

	return "%d-%02d-%02d" % [
		date.year,
		date.month,
		date.day
	]


func _auth_headers(include_json: bool = false) -> Array:
	var headers: Array = []

	if include_json:
		headers.append("Content-Type: application/json")

	if session_token != "":
		headers.append("X-Session-Token: " + session_token)

	return headers


func _json_canonical(data: Dictionary) -> String:
	var keys = data.keys()
	keys.sort()

	var ordered := {}

	for k in keys:
		ordered[k] = data[k]

	return JSON.stringify(ordered, "", false)


func _generate_nonce() -> String:
	var random_bytes = crypto.generate_random_bytes(16)
	return random_bytes.hex_encode()


func _get_timestamp() -> int:
	return int(Time.get_unix_time_from_system())


func _prepare_signed_payload(data: Dictionary) -> Dictionary:
	var final_data := data.duplicate(true)

	final_data["timestamp"] = _get_timestamp()
	final_data["nonce"] = _generate_nonce()

	return final_data


func _client_signature(method: String, path: String, body: String) -> String:
	var payload = (method + ":" + path + ":" + body).to_utf8_buffer()
	var secret = CLIENT_SECRET.to_utf8_buffer()
	var sig = crypto.hmac_digest(HashingContext.HASH_SHA256, secret, payload)
	return sig.hex_encode()


func _hmac_signature(data: Dictionary, secret: String) -> String:
	if secret == "":
		return ""

	var payload: String = _json_canonical(data)

	var signature_bytes = crypto.hmac_digest(
		HashingContext.HASH_SHA256,
		secret.to_utf8_buffer(),
		payload.to_utf8_buffer()
	)

	return signature_bytes.hex_encode()


func _signed_headers(
	data: Dictionary,
	include_json: bool = false,
	method: String = "POST",
	path: String = "",
	body: String = ""
) -> Array:
	var headers = _auth_headers(include_json)

	var signature = _hmac_signature(data, session_hmac_secret)
	if signature != "":
		headers.append("X-Signature: " + signature)

	if path != "":
		headers.append("X-Client-Signature: " + _client_signature(method, path, body))

	return headers


func _create_request(callback: Callable, timeout : float = 10.0) -> HTTPRequest:
	var req := HTTPRequest.new()

	add_child(req)

	req.timeout = timeout

	req.request_completed.connect(callback)

	req.request_completed.connect(
		func(_r, _rc, _h, _b):
			req.queue_free()
	)

	return req


func _is_ok(response_code: int, body: PackedByteArray = []) -> bool:
	if response_code != 200:
		DebugOutput.print_error(
			"Server Request failed with code: " + str(response_code)
		)

		response_failed.emit("http_" + str(response_code))
		if body.get_string_from_utf8():
			var _response = JSON.parse_string(body.get_string_from_utf8())
			if _response:
				var error_message := str(_response.get("error", "unknown"))

				DebugOutput.print_error(
					"Server error: " + error_message
				)
		return false

	if body.is_empty():
		return true

	var response = JSON.parse_string(body.get_string_from_utf8())

	if response == null:
		DebugOutput.print_error("Invalid JSON response")

		response_failed.emit("invalid_json")

		return false

	if response.has("success") and not response.success:
		var error_message := str(response.get("error", "unknown"))

		DebugOutput.print_error(
			"Server error: " + error_message
		)

		response_failed.emit(error_message)

		return false

	return true
#endregion

#region Auth

func register_player(login: String, password: String):
	var http_request = _create_request(_on_reg_request_completed)
	var endpoint : String = "/register"

	var data = _prepare_signed_payload({
		"login": login,
		"password": password,
	})
	var json_data = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json_data)

	http_request.request(
		URL + endpoint,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)


func login_player(login: String, password: String):
	var http_request = _create_request(_on_log_request_completed)
	var endpoint: String = "/login"

	var data = _prepare_signed_payload({
		"login": login,
		"password": password
	})
	var json_data = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json_data)

	http_request.request(URL + endpoint, headers, HTTPClient.METHOD_POST, json_data)


func logout():
	if session_token == "":
		return

	var http_request = _create_request(
		func(_result, response_code, _headers, body):
			if not _is_ok(response_code, body):
				return

			session_token = ""
			session_hmac_secret = ""
			is_logged = false
	)
	var endpoint : String = "/logout"

	http_request.request(
		URL + endpoint,
		_signed_headers({}, false, "POST", endpoint, ""),
		HTTPClient.METHOD_POST
	)
#endregion

#region Records

func save_record(
	_player_id: int,
	wave: int,
	score: int,
	lifetime: int,
	location: String
):
	var http_request = _create_request(_on_save_rec_request_completed)
	var endpoint : String = "/save_record"

	if Global.wave_logic:
		_update_stats(
			score,
			Global.wave_logic.get_enemies_kill_count() as int
		)

	var data = _prepare_signed_payload({
		"max_wave": wave,
		"max_score": score,
		"max_lifetime": lifetime,
		"location": location,
	})

	var json_data = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json_data)

	http_request.request(
		URL + endpoint,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)


func start_run(location: String):
	var http = _create_request(func(_r, code, _h, body):
		if not _is_ok(code, body):
			return
		var res = JSON.parse_string(body.get_string_from_utf8())
		current_run_id = res.run_id
		current_run_secret = res.run_secret
	)

	var endpoint: String = "/start_run"
	var data = {"location": location}
	var json = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json)
	http.request(URL + endpoint, headers, HTTPClient.METHOD_POST, json)


func finish_run(wave: int, score: int, lifetime: int, location: String):
	if current_run_id == "" or current_run_secret == "":
		return

	var http = _create_request(_on_finish_run)
	var endpoint: String = "/finish_run"

	if Global.wave_logic:
		_update_stats(score, Global.wave_logic.get_enemies_kill_count() as int)

	var data = {
		"max_wave": wave,
		"max_score": score,
		"max_lifetime": lifetime,
		"location": location
	}

	var json = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json)
	headers.append("X-Run-ID: " + current_run_id)
	headers.append("X-Run-Signature: " + _hmac_signature(data, current_run_secret))

	http.request(URL + endpoint, headers, HTTPClient.METHOD_POST, json)


func get_record(
	_player_id: int = local_player_id,
	location: String = ''
):
	var http_request = _create_request(
		_on_get_rec_request_completed.bind(location)
	)
	var endpoint : String = "/get_record"
	var query_string : String = "?location=" + location
	var path : String = endpoint + query_string


	var headers = _signed_headers({}, false, "GET", path, "")

	http_request.request(
		URL + "/get_record" + query_string,
		headers
	)


func get_leaderboard():
	var http_request = _create_request(
		on_get_leadearboard_request_completed
	)
	#var headers = _signed_headers({}, false, "GET", "/get_leaderboard", "")
	http_request.request(URL + "/get_leaderboard")
#endregion

#region Stats

func get_stats():
	var http_request = _create_request(
		_on_get_stats_request_completed
	)
	var endpoint : String = "/get_stats"

	var headers = _signed_headers({}, false, "GET", endpoint, "")

	http_request.request(
		URL + endpoint,
		headers
	)


func _update_stats(score: int = 0, kills: int = 0):
	var http_request = _create_request(
		_on_save_rec_request_completed
	)
	var endpoint : String = "/update_stats"
	var data = _prepare_signed_payload({
		"kills": kills,
		"score": score,
	})

	var json_data = _json_canonical(data)

	var headers = _signed_headers(data, true, "POST", endpoint, json_data)

	http_request.request(
		URL + endpoint,
		headers,
		HTTPClient.METHOD_POST,
		json_data
	)
#endregion

#region Version

func get_version():
	var http_request := _create_request(
		func(_result, response_code, _headers, body):
			if not _is_ok(response_code, body):
				getted_game_version.emit("")
				return

			var response = JSON.parse_string(
				body.get_string_from_utf8()
			)

			getted_game_version.emit(
				str(response.version)
			)
	)

	http_request.request(URL + "/game_version")
#endregion

#region Callbacks

func on_get_leadearboard_request_completed(
	_result,
	response_code,
	_headers,
	body
):
	if not _is_ok(response_code, body):
		getted_leaderboard.emit({})
		return

	var response = JSON.parse_string(
		body.get_string_from_utf8()
	)

	getted_leaderboard.emit(response)


func _on_get_rec_request_completed(
	_result,
	response_code,
	_headers,
	body,
	location
):
	if not _is_ok(response_code, body):
		getted_record.emit({}, location)
		return

	var response = JSON.parse_string(
		body.get_string_from_utf8()
	)

	getted_record.emit(response, location)


func _on_save_rec_request_completed(
	_result,
	response_code,
	_headers,
	body
):
	if not _is_ok(response_code, body):
		return


func _on_finish_run(_r, code, _h, body):
	if not _is_ok(code, body):
		return

	current_run_id = ""
	current_run_secret = ""


func _on_log_request_completed(
	_result,
	response_code,
	_headers,
	body
):
	if not _is_ok(response_code, body):
		player_logged.emit(false, "request_failed")
		return

	var response = JSON.parse_string(
		body.get_string_from_utf8()
	)

	session_token = str(response.token)
	session_hmac_secret = str(response.hmac_secret)

	is_logged = true

	player_logged.emit(true, "")


func _on_reg_request_completed(
	_result,
	response_code,
	_headers,
	body
):
	if not _is_ok(response_code, body):
		player_registred.emit(false, "request_failed")
		return

	player_registred.emit(true, "")


func _on_get_stats_request_completed(
	_result,
	response_code,
	_headers,
	body
):
	if not _is_ok(response_code, body):
		player_stats_getted.emit({})
		return

	var response = JSON.parse_string(
		body.get_string_from_utf8()
	)

	player_stats_getted.emit(response)
#endregion
