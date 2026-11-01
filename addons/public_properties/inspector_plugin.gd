@tool
extends EditorInspectorPlugin


const THEME: Theme = preload("inspector_plugin.theme")


func _can_handle(object: Object) -> bool: return object is Node


func _parse_begin(object: Object) -> void:
	var parent: Node = object
	
	var main_container := FoldableContainer.new()
	main_container.title = "Editable Children Properties"
	main_container.theme = THEME
	main_container.folded = not (
		EditorInterface.get_edited_scene_root().is_ancestor_of(parent) and
		EditorInterface.get_edited_scene_root().is_editable_instance(parent))
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(main_vbox)
	
	var any_properties_found = false 
	
	for child: Node in parent.find_children("*", "", true):
		if child.owner != parent: continue
		
		var child_path: NodePath = parent.get_path_to(child)
		
		var child_container := FoldableContainer.new()
		child_container.title = parent.get_path_to(child)
		
		var child_vbox := VBoxContainer.new()
		child_container.add_child(child_vbox)
		
		var has_properties = false 
		
		for property: Dictionary in PublicProperties.object_get_public_property_list(child):
			var property_path: String = String(child_path) + ":" + property.name
			var property_value: Variant = Utils.object_get_indexed(parent, property_path)
			var editor: Control
			
			match property.type:
				TYPE_BOOL:
					editor = CheckBox.new()
					editor.button_pressed = property_value
					editor.text = "On"
					editor.toggled.connect(_on_value_changed.bind(parent, property_path))
				
				TYPE_FLOAT, TYPE_INT:        editor = _create_number_editor(property, parent, property_path)
				TYPE_VECTOR2, TYPE_VECTOR2I: editor = _create_vector_editor(property, parent, property_path, 2)
				TYPE_VECTOR3, TYPE_VECTOR3I: editor = _create_vector_editor(property, parent, property_path, 3)
				TYPE_VECTOR4, TYPE_VECTOR4I: editor = _create_vector_editor(property, parent, property_path, 4)
				
				TYPE_STRING, TYPE_STRING_NAME:
					editor = LineEdit.new()
					editor.text = property_value
					editor.text_changed.connect(_on_value_changed.bind(parent, property_path))
				
				TYPE_OBJECT when property.hint == PROPERTY_HINT_RESOURCE_TYPE:
					editor = EditorResourcePicker.new()
					editor.edited_resource = property_value
					editor.base_type = property.hint_string
					editor.resource_changed.connect(_on_value_changed.bind(parent, property_path))
			
			if editor:
				var editor_property := EditorProperty.new()
				editor_property.label = property.name.capitalize()
				editor_property.add_child(editor)
				
				child_vbox.add_child(editor_property)
				has_properties = true

		if has_properties:
			main_vbox.add_child(child_container)
			any_properties_found = true
	
	if any_properties_found:
		add_custom_control(main_container)


static func _create_slider_editor(property: Dictionary) -> EditorSpinSlider:
	var slider := EditorSpinSlider.new()
	if property.hint == PROPERTY_HINT_RANGE:
		slider.min_value = (property.hint_string).get_slice(",", 0).to_float()
		slider.max_value = property.hint_string.get_slice(",", 1).to_float()
		slider.step = property.hint_string.get_slice(",", 2).to_float()
		slider.suffix = Maybe.optional(RegEx.create_from_string("suffix:([^,]+)").search(property.hint_string)).call_from("get_string", 1).unwrap("")
		slider.allow_lesser = "or_less" in property.hint_string
		slider.allow_greater = "or_greater" in property.hint_string
	return slider


static func _get_slider_suffix(hint_string: String) -> String:
	return Maybe.optional(RegEx.create_from_string("suffix:([^,]+)").search(hint_string)).call_from("get_string", 1).unwrap("")


func _create_number_editor(property: Dictionary, parent: Node, property_path: NodePath) -> EditorSpinSlider:
	var slider: EditorSpinSlider = _create_slider_editor(property)
	slider.value = Utils.object_get_indexed(parent, property_path)
	slider.editing_integer = property.type == TYPE_INT
	slider.value_changed.connect(_on_value_changed.bind(parent, property_path))
	return slider


func _create_vector_editor(property: Dictionary, parent: Node, property_path: NodePath, size: int) -> BoxContainer:
	var container := VBoxContainer.new()
	for i in size:
		var slider: EditorSpinSlider = _create_slider_editor(property)
		slider.label = "xyzw"[i]
		slider.value = Utils.object_get_indexed(parent, property_path)[i]
		slider.editing_integer = property.type in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I]
		slider.value_changed.connect(_on_value_changed.bind(parent, str(property_path, ":", slider.label)))
		container.add_child(slider)
	return container


func _on_value_changed(new: Variant, parent: Node, property_path: NodePath) -> void:
	var old: Variant = Utils.object_get_indexed(parent, property_path)
	if old == new: return
	
	if EditorInterface.get_edited_scene_root().is_ancestor_of(parent):
		EditorInterface.get_edited_scene_root().set_editable_instance(parent, true)
	
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set %s" % property_path)
	undo_redo.add_do_method(Utils, "object_set_indexed", parent, property_path, new)
	undo_redo.add_undo_method(Utils, "object_set_indexed", parent, property_path, old)
	undo_redo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
