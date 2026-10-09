extends GutTest

const SettingsScript: GDScript = preload("res://scripts/autoload/settings.gd")


func test_server_url_from_the_page_query() -> void:
	assert_eq(SettingsScript.url_from_query("?server=wss%3A%2F%2Fbayabas.onrender.com"), "wss://bayabas.onrender.com")
	assert_eq(SettingsScript.url_from_query("?a=1&server=wss://x.fly.dev&b=2"), "wss://x.fly.dev")
	assert_eq(SettingsScript.url_from_query(""), "")
	assert_eq(SettingsScript.url_from_query("?other=1"), "")


func test_addresses_are_normalized_to_websocket_urls() -> void:
	assert_eq(SettingsScript.normalize_url("bayabas.onrender.com"), "wss://bayabas.onrender.com")
	assert_eq(SettingsScript.normalize_url("https://bayabas.onrender.com"), "wss://bayabas.onrender.com")
	assert_eq(SettingsScript.normalize_url("localhost:8080"), "ws://localhost:8080")
	assert_eq(SettingsScript.normalize_url(" ws://192.168.1.5:8080 "), "ws://192.168.1.5:8080")
	assert_eq(SettingsScript.normalize_url(""), "")


func test_the_project_has_a_server_url_setting() -> void:
	assert_true(ProjectSettings.has_setting("bayabas/network/server_url"))
