extends Control

#region Exports
@export var save_file_name : String = "LastFile"
@export var notifier_path : String = "res://Main/Scripts/Powershell/notify.ps1"
@export var notification_x_offset : int = 100
@export var CharSize : int = 10
@export var Frasi : Array[String] = [
	"Vai a bere un bicchiere d'acqua bro",
	"Alzati e fai stretching",
	"Fatti un giretto di 2 minuti",
	"Controlla se hai bisogno di mangiare",
	"Sbircia fuori dalla finestra per sgranchire gli occhi",
	"Respira profondo, ricarica la mente.",
	"Stai spaccando. Continua così.",
	"Pausa meritata, boss!",
	"Anche i razzi hanno bisogno di rifornimento. 🔥",
	"Stacca un attimo gli occhi dallo schermo 👀",
	"Fatti due passi, poi torni più forte.",
	"Un break intelligente vale più di 10 minuti a vuoto.",
	"Stretch it out! 💪",
	"Idratati bro. Acqua = cervello turbo. 🧠💧",
	"Sei a un passo dal next level, respira e vai!",
	"Pausa tattica → ritorno epico garantito."]
@export var MAX_TIME_S : int = 6000
@export var tomato_time_s : int = 25*60
@export var break_time_s : int = 5*60
#endregion


#region ONREADYs
@onready var debug_button = load("res://Main/Scenes/DebugButton.tscn")

@onready var file_path_input = $FilePath/MarginContainer/Control/FilePathInput
@onready var file_button = $FilePath/MarginContainer/Control/Button
@onready var file_dialog = $FileDialog

@onready var controls = $Controls

@onready var timer = $TomatoTime/Timer
@onready var break_timer = $TomatoTime/BreakTimer
@onready var time_slider = $Controls/Control/TimeSlider
@onready var time_slider_label = $Controls/Control/Label

@onready var time_left_label = $TomatoTime/Control/RichTextLabel
@onready var time_left_bar = $TomatoTime/Control/ProgressBar
@onready var audio_stream_player = $TomatoTime/AudioStreamPlayer

@onready var grid_container = %BodyGridContainer

@onready var popup_panel : PanelContainer = $PopupPanel
@onready var popup_title = $PopupPanel/MarginContainer/VBoxContainer/Control/Title
@onready var popup_body = $PopupPanel/MarginContainer/VBoxContainer/Control3/Body



@onready var time_left_s : int = 0

@onready var notif_pos : Vector2 = Vector2()
#endregion


var session_started : bool = false
var last_csv : String = ""

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if !session_started:
			get_tree().quit()


func _ready():
	randomize()
	notif_pos = popup_panel.position
	popup_panel.position.x=popup_panel.position.x+popup_panel.size.x
	last_csv = retrieve_path(save_file_name)
	file_path_input.text = last_csv
	file_dialog.current_dir = last_csv.get_base_dir()
	populate_grid_from_csv_excel_style(last_csv)
	debug_btn()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if controls.visible:
		time_slider_label.text = format_tomato_time((time_slider.value / 100.0) * MAX_TIME_S)

	if session_started:
		get_tree().auto_accept_quit = false
		time_left_label.text = "[color=" + get_timer_color_hex(time_left_bar.value / 100.0) + "] [p align=center]" + format_time(timer.time_left)
		time_left_bar.value = (timer.time_left / timer.wait_time) * 100

		var style = time_left_bar.get_theme_stylebox("fill", "ProgressBar")
		if style is StyleBoxFlat:
			style.bg_color = Color(get_timer_color_hex(time_left_bar.value / 100.0))
			time_left_bar.add_theme_stylebox_override("fill", style)
	elif break_timer.is_stopped() == false:
		# Durante la pausa
		time_left_label.text = "[color=#66CCFF][p align=center]Pausa: " + format_time(break_timer.time_left) + "[/p][/color]"
		time_left_bar.value = (break_timer.time_left / break_timer.wait_time) * 100

		var style = time_left_bar.get_theme_stylebox("fill", "ProgressBar")
		if style is StyleBoxFlat:
			style.bg_color = Color("#66CCFF")  # Colore azzurro "pausa"
			time_left_bar.add_theme_stylebox_override("fill", style)
	else:
		get_tree().auto_accept_quit = true
		time_left_label.text = "[center]0h 0m 0s[/center]"
		time_left_bar.value = 0



func format_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h = seconds / 3600
	@warning_ignore("integer_division")
	var m = (seconds % 3600) / 60
	var s = seconds % 60
	return str(h) + "h " + str(m) + "m " + str(s) + "s"


func format_tomato_time(seconds: float) -> String:
	var m := seconds / 60.0
	var tnum = round(m / 25.0)  # Arrotonda al pomodoro più vicino
	var label := str(tnum) + (" pomodoro" if (tnum == 1) else " pomodori")
	label += " (" + str(round(m)) + " min.)"
	return label


func get_timer_color_hex(progress: float) -> String:
	# Se siamo sopra al 30% → bianco puro
	if progress > 0.3:
		return "#FFFFFF"

	# Calcola quanto "rosso" diventare da 30% a 0%
	var factor = clamp(progress / 0.3, 0.0, 1.0)
	factor = 1.0 - factor  # progress: 0.3 → 0.0 → factor: 0 → 1

	var green_blue = int(clamp(255.0 * (1.0 - factor), 0, 255))  # da 255 a 0

	var r = 255
	var g = green_blue
	var b = green_blue

	return "#%02X%02X%02X" % [r, g, b]


func create_bordered_label(text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.custom_minimum_size = Vector2(160, 30)  # aumenta un po' la larghezza
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.tooltip_text = text
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	
	var label = Label.new()
	label.text = text
	label.tooltip_text = text  # Tooltip to display if text is truncated
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF  # DISABLE WRAPPING
	label.clip_text = true  # Enforce truncation
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	panel.add_child(label)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0)
	style.border_color = Color(0, 0, 0)
	style.border_width_top = 1  # 1px bordo
	style.border_width_bottom = 1  # 1px bordo
	style.border_width_left = 1  # 1px bordo
	style.border_width_right = 1  # 1px bordo
	panel.add_theme_stylebox_override("panel", style)

	return panel


# Funzione helper interna per creare cella scalata
func create_scaled_label(text: String, width_multiplier: int, color : String = "white") -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	
	# Stima: 10px a carattere + margine
	var width = width_multiplier * CharSize + 20
	panel.custom_minimum_size = Vector2(width, 30)

	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var label = RichTextLabel.new()
	
	if color != "white" or color !="#FFFFFF":
		text = "[color="+color+"]"+text+"[/color]"
	label.text = "[p align=center]"+text+"[/p]"
	label.threaded = true
	label.bbcode_enabled = true
	label.tooltip_text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_STOP

	panel.add_child(label)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.8, 0.8, 0)
	style.border_color = Color(0, 0, 0)
	style.border_width_top = 1  # 1px bordo
	style.border_width_bottom = 1  # 1px bordo
	style.border_width_left = 1  # 1px bordo
	style.border_width_right = 1  # 1px bordo
	panel.add_theme_stylebox_override("panel", style)

	return panel


func populate_grid_from_csv_excel_style(file_path: String) -> void:
	var dimensions = get_csv_dimensions(file_path)
	var _rows = int(dimensions.x)
	var columns = int(dimensions.y)

	grid_container.columns = columns + 1  # +1 per la colonna indici

	# Pulisce la griglia prima
	for child in grid_container.get_children():
		child.queue_free()

	var data = read_csv_as_dict(file_path)

	# Prima cosa: calcolo la larghezza ideale per ogni colonna
	var max_char_per_column = {}  # dizionario header -> max chars

	if data.size() > 0:
		@warning_ignore("confusable_local_declaration")
		var headers = data[0].keys()

		# Inizializza max per header
		for header in headers:
			max_char_per_column[header] = header.length()

		# Gira su tutti i record
		for row in data:
			for key in headers:
				var text_length = row[key].length()
				if text_length > max_char_per_column[key]:
					max_char_per_column[key] = text_length

	# -- costruiamo la griglia --

	# Prima riga: intestazioni
	grid_container.add_child(create_scaled_label("", 3))  # cella vuota in alto a sinistra

	var headers = []
	if data.size() > 0:
		headers = data[0].keys()
		for header in headers:
			grid_container.add_child(create_scaled_label(header, max_char_per_column[header], "#3399FF"))

	# Righe dati
	for i in range(data.size()):
		grid_container.add_child(create_scaled_label(str(i + 1), 3, "#CC6633"))  # Indice numerico fisso

		for key in headers:
			grid_container.add_child(create_scaled_label(data[i][key], max_char_per_column[key]))


# OLD WAY - KEPT FOR COMPARISONS. IGNORE PLEASE
#func populate_grid_from_csv_excel_style(file_path: String) -> void:
#	var dimensions = get_csv_dimensions(file_path)
#	var _rows = int(dimensions.x)
#	var columns = int(dimensions.y)
#	var columns = int(dimensions.y)
#	
#	grid_container.columns = columns + 1  # +1 per indice numerico
#	
#	# Pulisce la griglia prima
#	for child in grid_container.get_children():
#		child.queue_free()
#	
#	var data = read_csv_as_dict(file_path)
#	
#	
#	
#	# PRIMA RIGA: intestazioni
#	grid_container.add_child(create_bordered_label(""))  # Vuoto in alto a sinistra
#	
#	var headers = []
#	if data.size() > 0:
#		headers = data[0].keys()
#		for header in headers:
#			var header_label = create_bordered_label(header)
#			var label_node = header_label.get_child(0)
#			label_node.add_theme_color_override("font_color", Color(0.2, 0.6, 1))  # Testo blu
#			grid_container.add_child(header_label)
#	
#	# RIGHE DATI
#	for i in range(data.size()):
#		var row_label = create_bordered_label(str(i + 1))
#		var label_node = row_label.get_child(0)
#		label_node.add_theme_color_override("font_color", Color(0.8, 0.4, 0.2))  # Indice colorato
#		grid_container.add_child(row_label)
#		
#		for key in headers:
#			var data_label = create_bordered_label(data[i][key])
#			grid_container.add_child(data_label)


func push_notification(title : String, message : String, time_s : float = 3) -> int:
	var ease_time : float = 0.5
	print_debug("A notification has been pushed!\nTitle: %s\nMessage: %s\nFor %ss"%[title,message,str(time_s)])
	popup_title.text = "[center]"+title+"[/center]"
	popup_body.text = "[center]"+message+"[/center]"
	popup_panel.position = Vector2(notif_pos.x+popup_panel.size.x+notification_x_offset,notif_pos.y)
	var modulate_tweener : Tween = create_tween()
	modulate_tweener.set_ease(Tween.EASE_IN_OUT)
	modulate_tweener.tween_property(popup_panel,"position",notif_pos,ease_time)
	await modulate_tweener.finished
	await get_tree().create_timer(time_s).timeout
	var modulate_tweener_back : Tween = create_tween()
	modulate_tweener_back.set_ease(Tween.EASE_IN_OUT)
	modulate_tweener_back.tween_property(popup_panel,"position",Vector2(notif_pos.x+popup_panel.size.x+notification_x_offset,notif_pos.y), ease_time)
	await modulate_tweener_back.finished
	return 0 


func _on_start_button_pressed():
	time_left_s = (time_slider.value / 100.0) * MAX_TIME_S
	if FileAccess.file_exists(file_path_input.text):
		session_started = true
		timer.start(tomato_time_s)
		controls.hide() # Removes the ability to start another timer.
		file_path_input.editable = false  # Removes the ability to change the file
		file_button.disabled = true
		await push_notification("🍅 Pomodoro iniziato! ⏲️","Tempo impostato a: %s"%format_time(timer.wait_time),1)
		print_debug("INFO | TIME STARTED WITH ",timer.wait_time," SECONDS")
	else:
		session_started = false
		push_notification("⚠️ FILE NON TROVATO ⚠️","| NO FILE \""+file_path_input.text+"\" FOUND!",6)
		push_warning("WARNING | NO FILE \""+file_path_input.text+"\" FOUND!")


func _on_timer_timeout():
	time_left_s -= tomato_time_s
	print("TIME_LEFT_S =" + str(time_left_s))
	if time_left_s <= 0:
		session_started = false
		controls.show() # Re-gives the ability to see the controls
		file_path_input.editable = true # Allows the user to edit the csv file
		file_button.disabled = false
		audio_stream_player.play()
		DisplayServer.window_request_attention()
		get_window().grab_focus()
		await push_notification("🎉 Sessione terminata!", Frasi.pick_random())
	else:
		session_started = false
		await push_notification("⏲️ Pomodoro terminato!", Frasi.pick_random())
		start_break(break_time_s)
	print("INFO | TIME ENDED AFTER "+str(timer.wait_time)+" SECONDS!")


func start_break(break_time : int = 5*60):
	break_timer.wait_time = break_time
	break_timer.start()
	await push_notification("⌚ Pausa iniziata!", "Prenditi una pausa!")


func _on_break_timer_timeout():
	audio_stream_player.play()
	await push_notification("🔥 Pausa terminata!","Crush that work!")
	session_started = true 
	if time_left_s > 0:
		timer.start(tomato_time_s)
	else:
		await push_notification("Sessione terminata!","Ottimo lavoro")


func _on_time_slider_drag_ended(value_changed : bool):
	if value_changed: # value_changed is a bool used to check if the previous time_slider.value is the same as the new one
		time_left_s = (time_slider.value/100.0)*MAX_TIME_S

func _on_file_path_input_text_changed():
	if FileAccess.file_exists(file_path_input.text):
		save_path(save_file_name,file_path_input.text)
		populate_grid_from_csv_excel_style(file_path_input.text)


func save_path(file_name: String, txt: String) -> void:
	var file = FileAccess.open("user://"+file_name, FileAccess.WRITE)
	if file:
		file.store_string(txt)
		file.close()


func retrieve_path(file_name: String) -> String:
	if FileAccess.file_exists("user://"+file_name):
		var file = FileAccess.open("user://"+file_name, FileAccess.READ)
		var txt = file.get_as_text()
		file.close()
		return txt
	else:
		return ""  # File non trovato, restituisce stringa vuota


func get_csv_dimensions(file_path: String) -> Vector2:
	var row_count = 0
	var column_count = 0
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		while not file.eof_reached():
			var line = file.get_line()
			if line.strip_edges() != "":
				var fields = line.split(",")
				if row_count == 0:
					column_count = fields.size()
				row_count += 1
		file.close()
	return Vector2(row_count, column_count)  # x = rows, y = columns


func read_csv_as_dict(file_path: String) -> Array:
	var data = []
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file.eof_reached():
			var header_line = file.get_line()
			var headers = header_line.strip_edges().split(",")
			
			while not file.eof_reached():
				var line = file.get_line()
				if line.strip_edges() != "":
					var fields = line.split(",")
					var record = {}
					for i in range(headers.size()):
						record[headers[i]] = fields[i]
					data.append(record)
		file.close()
	return data


func _on_button_pressed():
	print_debug("File Button pressed!")
	file_dialog.popup()


func _on_file_dialog_file_selected(path):
	print_debug("File Chosen!")
	file_path_input.text = path


func _on_file_path_input_text_set():
	if FileAccess.file_exists(file_path_input.text):
		save_path(save_file_name,file_path_input.text)
		populate_grid_from_csv_excel_style(file_path_input.text)


func debug_btn() -> void:
	# Pulsante DEBUG per saltare pomodoro
	var button_instance = (debug_button as PackedScene).instantiate()
	add_child(button_instance)

	button_instance.pressed.connect(func():
		if session_started:
			print_debug("DEBUG | Pomodoro saltato manualmente")
			_on_timer_timeout()
		else:
			print_debug("DEBUG | Nessuna sessione attiva.\nDEBUG | Tento di skippare la pausa.")
			_on_break_timer_timeout()
			)

