class_name Touch
## Shared helpers for finger gestures, so swiping between pages and dragging lists behave the same way.

## True while a pretend release is being sent, which every gesture handler ignores.
static var cancelling := false
## True while a card is held and being moved, which stops lists scrolling and pages swiping under the finger.
static var holding := false


## Lets go of whatever button the finger started on, far off screen, which means that button neither fires
## nor stays looking pressed once the touch has turned into a swipe or a scroll.
static func cancel_press(viewport: Viewport) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-10000, -10000)
	release.global_position = release.position
	cancelling = true
	viewport.push_input(release)
	cancelling = false


## True when something is open on top, such as a card's details, and this node is not part of it.
## Gestures underneath an open view are ignored.
static func blocked(node: Node) -> bool:
	for modal in node.get_tree().get_nodes_in_group(Pager.MODAL_GROUP):
		if not modal.is_ancestor_of(node):
			return true
	return false
