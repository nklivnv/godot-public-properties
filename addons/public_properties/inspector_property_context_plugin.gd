@tool
extends EditorContextMenuPlugin



func _get_menu_options(data: Dictionary[StringName, Variant]) -> void:
	if PublicProperties.is_public_property(data.object, data.property_name):
		add_context_menu_item("Unublish Property", PublicProperties.unpublish_property.bind(data.object, data.property_name).unbind(1))
	else:
		add_context_menu_item("Publish Property", PublicProperties.publish_property.bind(data.object, data.property_name).unbind(1))
