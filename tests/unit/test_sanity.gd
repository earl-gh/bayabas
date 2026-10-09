extends GutTest


func test_sanity() -> void:
	assert_eq(1 + 1, 2, "arithmetic still works")


func test_autoloads_present() -> void:
	assert_not_null(get_node_or_null("/root/Net"), "Net autoload")
	assert_not_null(get_node_or_null("/root/Session"), "Session autoload")
	assert_not_null(get_node_or_null("/root/Settings"), "Settings autoload")
