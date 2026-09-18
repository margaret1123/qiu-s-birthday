extends SceneTree

func _init() -> void:
	assert(ProjectSettings.get_setting("display/window/size/viewport_width", 0) == 640)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height", 0) == 360)
	assert(ProjectSettings.get_setting("rendering/renderer/rendering_method", "") == "gl_compatibility")
	assert(ProjectSettings.has_setting("application/run/main_scene"))
	print("PASS: bootstrap")
	quit()
