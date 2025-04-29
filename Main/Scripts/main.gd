extends Control

@export var save_file_name : String = "LastFile"

@onready var controls = $Controls
@onready var file_path_input = $FilePath/MarginContainer/Control/FilePathInput
@onready var timer = $Timer
@onready var time_slider = $Controls/Control/TimeSlider
@onready var time_slider_label = $Controls/Control/Label
@onready var time_left_label = $TomatoTime/Control/RichTextLabel
@onready var time_left_bar = $TomatoTime/Control/ProgressBar
@onready var grid_container = %BodyGridContainer

const MAX_TIME_S : int = 18000



var session_started : bool = false
var last_csv : String = ""

func _ready():
	last_csv = retrieve_path(save_file_name)
	file_path_input.text = last_csv
	populate_grid_from_csv_excel_style(last_csv)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if controls.visible:
		time_slider_label.text = format_time((time_slider.value/100)*MAX_TIME_S)
	if session_started:
		time_left_label.text = "[color=white] [p align=center]" + format_time(timer.time_left)
		time_left_bar.value = (timer.time_left/timer.wait_time)*100

func format_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h = seconds / 3600
	@warning_ignore("integer_division")
	var m = (seconds % 3600) / 60
	var s = seconds % 60
	return str(h) + "h " + str(m) + "m " + str(s) + "s"

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





func populate_grid_from_csv_excel_style(file_path: String) -> void:
	var dimensions = get_csv_dimensions(file_path)
	var _rows = int(dimensions.x)
	var columns = int(dimensions.y)
	
	grid_container.columns = columns + 1  # +1 per indice numerico
	
	# Pulisce la griglia prima
	for child in grid_container.get_children():
		child.queue_free()
	
	var data = read_csv_as_dict(file_path)
	
	# PRIMA RIGA: intestazioni
	grid_container.add_child(create_bordered_label(""))  # Vuoto in alto a sinistra
	
	var headers = []
	if data.size() > 0:
		headers = data[0].keys()
		for header in headers:
			var header_label = create_bordered_label(header)
			var label_node = header_label.get_child(0)
			label_node.add_theme_color_override("font_color", Color(0.2, 0.6, 1))  # Testo blu
			grid_container.add_child(header_label)
	
	# RIGHE DATI
	for i in range(data.size()):
		var row_label = create_bordered_label(str(i + 1))
		var label_node = row_label.get_child(0)
		label_node.add_theme_color_override("font_color", Color(0.8, 0.4, 0.2))  # Indice colorato
		grid_container.add_child(row_label)
		
		for key in headers:
			var data_label = create_bordered_label(data[i][key])
			grid_container.add_child(data_label)


func _on_start_button_pressed():
	if FileAccess.file_exists(file_path_input.text):
		session_started = true
		timer.wait_time = (time_slider.value/100)*MAX_TIME_S # gets the time chosen by the user
		timer.start()
		controls.hide() # Removes the ability to start another timer.
		file_path_input.editable = false  # Removes the ability to change the file
		print("INFO | TIME STARTED WITH ",timer.wait_time," SECONDS")
	else:
		push_warning("WARNING | NO FILE \""+file_path_input.text+"\" FOUND!")

func _on_timer_timeout():
	controls.show() # Re-gives the ability to see the controls
	file_path_input.editable = true # Allows the user to edit the csv file
	print("INFO | TIME ENDED AFTER "+str(timer.wait_time)+" SECONDS!")


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

