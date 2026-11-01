@tool
extends EditorPlugin
class_name PublicProperties


const PUBLIC_PROPERTIES_META: StringName = "public_properties"
const EDITOR_SETTINGS_PROPERTY_INFO: Dictionary = { name = "PublicProperties/inspector_plugin_enabled", type = TYPE_BOOL }


var _inspector_plugin: EditorInspectorPlugin:
	set(new):
		if _inspector_plugin: remove_inspector_plugin(_inspector_plugin)
		if new: add_inspector_plugin(new)
		_inspector_plugin = new


func _scene_clear_invalid_meta(root: Node) -> void:
	if not root: return
	
	for node in root.find_children("*"):
		if not node.has_meta(PUBLIC_PROPERTIES_META): continue
		
		var meta_value: PackedStringArray = node.get_meta(PUBLIC_PROPERTIES_META)
		var valid_properties: PackedStringArray
		
		for property: String in Arrays.unique(meta_value):
			if property in node: valid_properties.append(property)
		
		valid_properties.sort()
		
		if valid_properties: node.set_meta(PUBLIC_PROPERTIES_META, valid_properties)
		else: node.remove_meta(PUBLIC_PROPERTIES_META)


func _apply_changes() -> void:
	_scene_clear_invalid_meta(EditorInterface.get_edited_scene_root())


func _enter_tree() -> void:
	_add_context_plugin()
	_init_inspector_plugin()


func _exit_tree() -> void: _inspector_plugin = null


func _init_inspector_plugin() -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	Signals.connect_signal_until(editor_settings.settings_changed, _update_inspector_plugin, tree_exiting)
	
	if not editor_settings.has_setting(EDITOR_SETTINGS_PROPERTY_INFO.name):
		editor_settings.add_property_info(EDITOR_SETTINGS_PROPERTY_INFO)
		editor_settings.set_setting(EDITOR_SETTINGS_PROPERTY_INFO.name, true)
	
	_update_inspector_plugin()


func _update_inspector_plugin() -> void:
	var editor_settings_value: Variant = EditorInterface.get_editor_settings().get_setting(EDITOR_SETTINGS_PROPERTY_INFO.name)
	_inspector_plugin = load(Utils.script_path_join(get_script(), "inspector_plugin.gd")).new() if editor_settings_value == true else null
	update_editor_inspector()


# HACK:
static func update_editor_inspector() -> void:
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var inspected_object: Object = inspector.get_edited_object()
	if inspected_object:
		inspector.edit(null)
		inspector.edit(inspected_object)


func _add_context_plugin() -> void:
	var plugin: EditorContextMenuPlugin = load(Utils.script_path_join(get_script(), "inspector_property_context_plugin.gd")).new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_INSPECTOR_PROPERTY, plugin)
	tree_exiting.connect(remove_context_menu_plugin.bind(plugin), CONNECT_ONE_SHOT)


static func is_public_property(object: Object, property_name: StringName) -> bool:
	return object.has_meta(PUBLIC_PROPERTIES_META) and property_name in object.get_meta(PUBLIC_PROPERTIES_META, [])

static func _object_get_public_property_names_immediate(object: Object) -> PackedStringArray:
	return object.get_meta(PUBLIC_PROPERTIES_META, []) if object.has_meta(PUBLIC_PROPERTIES_META) else []

static func object_get_public_property_names(object: Object, local: bool = true) -> PackedStringArray:
	return _object_get_public_property_names_immediate(object).duplicate()

static func object_get_public_property_list(object: Object) -> Array[Dictionary]:
	return object.get_property_list().filter(Operator.at.bind("name", _object_get_public_property_names_immediate(object).has))




static func publish_property(object: Object, property_name: StringName) -> void:
	var property_names: PackedStringArray = _object_get_public_property_names_immediate(object)
	if property_names:
		property_names.append(property_name)
		object.notify_property_list_changed()
	else: object.set_meta(PUBLIC_PROPERTIES_META, PackedStringArray([property_name]))

static func unpublish_property(object: Object, property_name: StringName) -> void:
	var property_names: PackedStringArray = _object_get_public_property_names_immediate(object)
	property_names.erase(String(property_name))
	if property_names: object.notify_property_list_changed()
	else: object.remove_meta(PUBLIC_PROPERTIES_META)




#func node_get_child_property(parent: Node, property: StringName, property_prefix: String = DEFAULT_INSPECTOR_PREFIX) -> Variant:
#	return Utils.object_get_indexed(parent, property_prefix.path_join(property))

#func node_set_child_property(parent: Node, property: StringName, new: Variant, prefix: String = DEFAULT_INSPECTOR_PREFIX) -> bool:
#	Utils.object_set_indexed(parent, prefix.path_join(property), new)
#	return false







const DEFAULT_INSPECTOR_PREFIX: String = "children_properties"


static func find_public_children(parent: Node) -> Array[Node]:
	return parent.find_children("*", "", true, true).filter(func(child: Node) -> bool: return child.owner == parent)


static func node_get_children_property_list(parent: Node, property_prefix: String = DEFAULT_INSPECTOR_PREFIX) -> Array[Dictionary]:
	var property_list: Array[Dictionary]
	for child in find_public_children(parent):
		var object_property_list: Array[Dictionary] = object_get_public_property_list(child)
		for property: Dictionary in object_property_list:
			var p: String = parent.get_path_to(child)
			property.name = "/".join([property_prefix, p, property.name] if property_prefix else [p, property.name])
		property_list.append_array(object_property_list)
	return property_list


static func node_get(parent: Node, children_properties: Dictionary[NodePath, Variant], property: StringName, property_prefix: String = DEFAULT_INSPECTOR_PREFIX) -> Variant:
	if property.begins_with(str(property_prefix, "/")):
		var slices: PackedStringArray = property.split("/", false)
		var node_path: String = "/".join(slices.slice(1, -1))
		var node_proeprty: String = slices[-1]
		var path: NodePath = node_path + ":" + node_proeprty
		return children_properties[path] if path in children_properties else Utils.object_get_indexed(parent, path)
	return null


static func node_set(parent: Node, children_properties: Dictionary[NodePath, Variant], property: StringName, new: Variant, property_prefix: String = DEFAULT_INSPECTOR_PREFIX) -> bool:
	if property.begins_with(str(property_prefix, "/")):
		var slices: PackedStringArray = property.split("/", false)
		var node_path: String = "/".join(slices.slice(1, -1))
		var node_proeprty: String = slices[-1]
		var path: NodePath = node_path + ":" + node_proeprty
		children_properties[path] = new
		Utils.object_set_indexed(parent, path, new)
	return false


static func node_notification(parent: Node, children_properties: Dictionary[NodePath, Variant], what: int) -> void:
	if what == Node.NOTIFICATION_EDITOR_PRE_SAVE: Dicts.filter_keys(children_properties, parent.has_node)


static func node_ready(parent: Node, children_properties: Dictionary[NodePath, Variant]) -> void:
	for path in children_properties: Utils.object_set_indexed(parent, path, children_properties[path])
	
	if Engine.is_editor_hint(): return
	children_properties.clear()
	for child in PublicProperties.find_public_children(parent):
		child.remove_meta(PUBLIC_PROPERTIES_META)
