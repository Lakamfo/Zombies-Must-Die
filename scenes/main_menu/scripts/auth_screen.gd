extends Panel

@onready var login_line: LineEdit = $margin_container/v_box_container/h_box_container/login_line
@onready var password_line: LineEdit = $margin_container/v_box_container/h_box_container2/password_line

@onready var label_message: Label = $margin_container/v_box_container/label_message

const Secret = preload("res://classes/secret/secret.gd")
const CLIENT_SECRET = Secret.CLIENT_SECRET
var sha256_password: PackedByteArray = (OS.get_unique_id() + OS.get_user_data_dir() + Secret.CLIENT_SECRET).sha256_buffer()
var save_path: String = OS.get_user_data_dir() + "/" + "user_data" + "." + "bin"


func _ready() -> void:
	load_data()


func save_data():
	var config_file = ConfigFile.new()

	config_file.set_value("player_data", "login", login_line.text)
	config_file.set_value("player_data", "password", password_line.text)

	config_file.save_encrypted(save_path, sha256_password)


func load_data():
	var config_file = ConfigFile.new()
	config_file.load_encrypted(save_path, sha256_password)

	var _login = config_file.get_value("player_data", "login", login_line.text)
	var _password = config_file.get_value("player_data", "password", password_line.text)

	login_line.text = _login
	password_line.text = _password

	if not ServerRequests.is_logged:
		login()


func login():
	ServerRequests.login_player(login_line.text.strip_edges(), password_line.text)

	ServerRequests.player_logged.connect(
		func x(logged: bool, _error: String):
			if logged:
				label_message.text = tr("KEY_LOGIN_SUC") % [login_line.text.strip_edges()]
				save_data()
			else:
				label_message.text = tr("KEY_LOGIN_PASSWORD_OR_LOGIN")
	)


func reg():
	if login_line.text == "" or password_line.text == "":
		label_message.text = tr("KEY_REG_ERROR")
	else:
		var error
		
		ServerRequests.register_player(login_line.text.strip_edges(), password_line.text)
		ServerRequests.player_registred.connect(
			func(success: bool, reg_error: String):
				if not success:
					error = reg_error
		)
		await ServerRequests.player_registred
		
		if error:
			label_message.text = tr("KEY_REG_ERROR_USER_EXISTS")
		else:
			label_message.text = tr("KEY_REG_SUC") % [login_line.text.strip_edges()]
			login()


func _on_bt_login_pressed() -> void:
	login()


func _on_bt_reg_pressed() -> void:
	var regex = RegEx.new()
	regex.compile('^[a-zA-Z0-9_]{4,16}$')
	
	var result = regex.search(login_line.text)
	
	if result:
		login_line.text = result.get_string()
		reg()
	else:
		DebugOutput.print_error("Login doesn`t match RegEx pattern")
		label_message.text = tr('KEY_REG_REGEX')
