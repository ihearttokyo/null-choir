extends SceneTree
const Main = preload("res://scripts/main.gd")
func _initialize() -> void:
 AudioServer.set_bus_mute(0, true)
 call_deferred("run")
func run() -> void:
 var game = Main.new()
 var prefix = "user://chapter_intros_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec())
 game.settings_path = prefix + "_preferences.json"
 game.progress_path = prefix + "_progress.json"
 root.add_child(game)
 if not game.has_method("_show_chapter_intro"):
  game.music.stop()
  game.effects.stop()
  await create_timer(0.15).timeout
  game.free()
  push_error("INTENDED RED: existing campaign-choice/intermission screens need earned chapter introductions")
  call_deferred("quit", 1)
  return
 var title: Texture2D = game.hud.menu_backdrop_texture()
 var before = game.state.to_dict().duplicate(true)
 game.show_difficulty()
 assert(game.menu.get_meta("chapter_intro") == 0)
 assert(game.menu.get_child(1).text == "Merciful" and game.menu.get_child(1).has_focus())
 assert(game.state.to_dict() == before)
 await process_frame
 await process_frame
 var edge: float = game.menu_scroll.global_position.x + game.menu_scroll.size.x - game.menu_scroll.get_v_scroll_bar().size.x
 for child in game.menu.get_children():
  if child is Control: assert(child.global_position.x + child.size.x <= edge + 1)
 var briefing: RichTextLabel = game.menu.get_child(game.menu.get_child_count() - 1)
 assert(briefing.focus_mode == Control.FOCUS_ALL and "Find both seals" in briefing.text)
 for step in range(4):
  var event = InputEventKey.new()
  event.keycode = KEY_TAB
  event.pressed = true
  root.push_input(event)
  event = event.duplicate()
  event.pressed = false
  root.push_input(event)
  await process_frame
 assert(briefing.has_focus() and game.menu_scroll.scroll_vertical > 0)
 for depth in range(1, 8):
  game.state.level_index = depth # Arranged presentation only, not earned traversal.
  before = game.state.to_dict().duplicate(true)
  game._show_menu("PREVIOUS DEPTH RESTORED", [["Descend", game.show_title], ["Return to title", game.show_title]])
  game._show_chapter_intro(depth)
  assert(game.menu.get_meta("chapter_intro") == depth)
  assert(game.menu.get_child(1).text == "Descend" and game.menu.get_child(1).has_focus())
  var art: Texture2D = game.hud.menu_backdrop_texture()
  assert(art != title and art.get_size() == Vector2(640, 360))
  assert(game.state.to_dict() == before and not FileAccess.file_exists(game.progress_path))
  game._show_menu("UNRELATED MENU", [["Back", game.show_title]])
  assert(game.menu.get_meta("chapter_intro", -1) == -1 and game.hud.menu_backdrop_texture() == title)
  game._show_chapter_intro(depth + 1)
  assert(game.menu.get_meta("chapter_intro", -1) == -1)
 game.show_title()
 for invalid in [-1, 0, 7, 8]: game._show_chapter_intro(invalid)
 assert(game.menu.get_meta("chapter_intro", -1) == -1)
 game.music.stop()
 game.effects.stop()
 paused = false
 await create_timer(0.15).timeout
 game.queue_free()
 await process_frame
 await process_frame
 print("PASS native eight chapter-intro presentations: existing choices/focus retained, earned-only art, unrelated/stale reset, unchanged state/no save writes; arranged states, not campaign/coldload/physical proof")
 call_deferred("quit", 0)
