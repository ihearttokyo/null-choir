extends SceneTree
const Main = preload("res://scripts/main.gd")
const Chart = preload("res://scripts/descent_chart.gd")
const EXPECTED_ART_FILES = ["intake.jpg", "foundry-pro-v2.jpg", "processional-pro-v2.jpg", "reliquary.jpg", "nursery.jpg", "ossuary-pro-v2.jpg", "inversion-pro-v2.jpg", "heart-pro-v2.jpg"]
func _initialize() -> void:
 AudioServer.set_bus_mute(0, true)
 call_deferred("run")
func run() -> void:
 var game = Main.new()
 var prefix = "user://restored_route_" + str(OS.get_process_id())
 game.settings_path = prefix + "_preferences.json"
 game.progress_path = prefix + "_progress.json"
 root.add_child(game)
 assert(Chart.VIEWS == ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"])
 assert(Chart.ART_FILES == EXPECTED_ART_FILES and Chart.ART_FILES.size() == 8)
 for index in range(8):
  assert(Chart.art_path(index) == "res://assets/art/descent/" + EXPECTED_ART_FILES[index])
 assert(Chart.art_path(-1) == "" and Chart.art_path(8) == "")
 assert(game.hud.menu_backdrop_texture().resource_path == "res://assets/art/title/pro-series-v2.jpg")
 var recording_refs: Array[WeakRef] = [weakref(game.music.player.stream)]
 for depth in range(1, 8):
  game.state.level_index = depth # Arranged UI evidence, not earned traversal.
  var before = game.state.to_dict().duplicate(true)
  game._show_menu("PREVIOUS DEPTH RESTORED", [["Descend", game.show_title], ["Return to title", game.show_title]])
  var descend = game.menu.get_child(1)
  var connections: Array = descend.get_signal_connection_list("pressed")
  game._show_descent_intermission()
  recording_refs.append(weakref(game.music.player.stream))
  assert(game.menu.get_meta("descent_intermission"))
  assert(descend == game.menu.get_child(1) and descend.has_focus())
  assert(descend.text == "Descend" and descend.get_signal_connection_list("pressed") == connections)
  var route = game.intermission_route
  assert(route.rows.size() == 8 and route.textures.size() == depth)
  assert(route.rows[depth].status == "CURRENT" and not route.textures.has(depth))
  for index in range(8):
   assert(route.rows[index].status == ("CLEARED" if index < depth else ("CURRENT" if index == depth else "UNREACHED")))
  assert(route.backdrop != null and route.size == Vector2(640, 360))
  assert(route.get_index() < game.menu_scroll.get_index()) # Painting cannot cover the controls.
  # Geography replaces the old grid: eight unique, bounded, separated markers,
  # connected in chapter order; labels stay within the 420px map margin.
  var visited: Array = []
  for index in range(8):
   var point: Vector2 = route.point(index)
   assert(Rect2(18, 45, 345, 292).has_point(point))
   assert(not visited.has(point))
   var label: Vector2 = route.label_position(index)
   assert(label.x >= 0 and label.x + 100 <= 420 and label.y + 13 < 350)
   for previous in visited: assert(point.distance_to(previous) >= 45)
   visited.append(point)
  for index in range(7):
   var length: float = route.point(index).distance_to(route.point(index + 1))
   assert(length >= 45 and length <= 160)
  # Actual accessible control opens only the latest completed chapter, never
  # the CURRENT next depth. This calls HUD's actual resource consumer.
  var illustration_toggle: Button = game.menu.get_child(3)
  assert(illustration_toggle.text == "Chapter illustration" and illustration_toggle.focus_mode == Control.FOCUS_ALL)
  assert(route.visible and game.menu.get_meta("chapter_intro", -1) == -1)
  var playing_stream: AudioStream = game.music.player.stream
  var music_context: String = game.music.playback_context
  illustration_toggle.pressed.emit()
  assert(not route.visible and illustration_toggle.text == "Descent chart")
  assert(game.menu_scroll.position == Vector2(8, 245) and game.menu_scroll.size == Vector2(624, 82))
  assert(not game.menu.get_child(0).visible and not game.menu.get_child(2).visible)
  assert(not game.menu.get_child(game.menu.get_child_count() - 1).visible)
  assert(descend.visible and illustration_toggle.visible and descend.has_focus())
  assert(game.menu.get_child(1) == descend and game.menu.get_child(3) == illustration_toggle)
  assert(descend.text == "Descend" and descend.get_signal_connection_list("pressed") == connections)
  assert(descend.custom_minimum_size.y == 34 and illustration_toggle.custom_minimum_size.y == 34)
  assert(game.menu.get_meta("chapter_intro") == depth - 1)
  var completed_art: Texture2D = game.hud.menu_backdrop_texture()
  assert(completed_art == route.textures[depth - 1])
  assert(completed_art.resource_path == "res://assets/art/descent/" + EXPECTED_ART_FILES[depth - 1])
  assert(game.hud._menu_chapter == depth - 1 and not route.textures.has(depth))
  game._toggle_restored_illustration(illustration_toggle, depth) # Forged future request cannot reveal art.
  assert(game.menu.get_meta("chapter_intro") == depth - 1 and not route.visible)
  illustration_toggle.pressed.emit()
  assert(route.visible and illustration_toggle.text == "Chapter illustration")
  assert(game.menu_scroll.position == Vector2(430, 45) and game.menu_scroll.size == Vector2(198, 275))
  for restored_child in game.menu.get_children(): assert(restored_child.visible)
  assert(game.menu.get_child(1) == descend and game.menu.get_child(3) == illustration_toggle)
  assert(not game.menu.has_meta("chapter_intro"))
  game.hud.menu_backdrop_texture()
  assert(game.hud._menu_chapter == -1)
  assert(descend == game.menu.get_child(1) and descend.has_focus())
  assert(descend.text == "Descend" and descend.get_signal_connection_list("pressed") == connections)
  assert(game.music.player.stream == playing_stream and game.music.playback_context == music_context)
  completed_art = null
  playing_stream = null
  assert(game.state.to_dict() == before and not FileAccess.file_exists(game.progress_path))
  game.show_title()
  recording_refs.append(weakref(game.music.player.stream))
  assert(game.intermission_route == null and game.menu_scroll.position == Vector2(18, 45))
  assert(game.menu_scroll.size == Vector2(220, 275))
  assert(game.menu.get_child(0).get_theme_font_size("font_size") == 28)
  assert(not game.menu.get_meta("descent_intermission"))
  game.show_settings()
  assert(game.menu_scroll.position == Vector2(150, 45) and game.menu_scroll.size == Vector2(340, 275))
  assert(game.menu.get_child(0).get_theme_font_size("font_size") == 32)
  game.show_title()
  assert(game.menu_scroll.position == Vector2(18, 45) and game.menu_scroll.size == Vector2(220, 275))
 # The actual ending consumer reveals Heart only after all eight depths.
 for ending_depth in [7, 8]:
  game.state.level_index = ending_depth
  var ending_before: Dictionary = game.state.to_dict().duplicate(true)
  game.show_ending()
  recording_refs.append(weakref(game.music.player.stream))
  var ending_art: Texture2D = game.hud.menu_backdrop_texture()
  if ending_depth == 8:
   assert(game.menu.get_meta("chapter_intro", -1) == 7 and game.hud._menu_chapter == 7)
   assert(ending_art.resource_path == "res://assets/art/descent/heart-pro-v2.jpg")
  else:
   assert(game.menu.get_meta("chapter_intro", -1) == -1 and game.hud._menu_chapter == -1)
   assert(ending_art.resource_path != "res://assets/art/descent/heart-pro-v2.jpg")
  assert(game.menu_scroll.position == Vector2(422, 32) and game.menu_scroll.size == Vector2(202, 290))
  assert(game.menu.get_child(0).get_theme_font_size("font_size") == 16)
  assert(game.menu.get_child(0).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
  assert(game.menu.get_child(0).get_theme_stylebox("normal").get("bg_color").a >= 0.9)
  var expected_revelation: String = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if game.state.discoveries.size() == 8 else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"
  assert(game.menu.get_child(0).text == expected_revelation)
  assert(game.menu.get_child(1).text == "New campaign" and game.menu.get_child(1).has_focus())
  assert(game.menu.get_child(2).text == "Return to title")
  assert(game.menu.get_child(3).text == "Recovered records" and game.menu.get_child(4).text == "Descent map")
  assert(game.music.playback_context == "interlude")
  assert(game.state.to_dict() == ending_before and not FileAccess.file_exists(game.progress_path))
  for action_index in range(1, 5):
   assert(game.menu.get_child(action_index).custom_minimum_size.y >= 34)
  ending_art = null
  game.show_title()
  recording_refs.append(weakref(game.music.player.stream))
  assert(game.menu_scroll.position == Vector2(18, 45) and game.menu_scroll.size == Vector2(220, 275))
  assert(game.menu.get_child(0).get_theme_font_size("font_size") == 28)
  game.show_settings()
  assert(game.menu_scroll.position == Vector2(150, 45) and game.menu_scroll.size == Vector2(340, 275))
  assert(game.menu.get_child(0).get_theme_font_size("font_size") == 32)
 game.music.stop()
 game.effects.stop()
 paused = false
 game.queue_free()
 await process_frame
 # Rapid arranged context switches retain native MP3 mixer playbacks briefly.
 # Bound cleanup by actual resource release, not a blind delay or ignored warning.
 var deadline: int = Time.get_ticks_usec() + 2000000
 while not _recordings_released(recording_refs) and Time.get_ticks_usec() < deadline:
  OS.delay_msec(2)
  await process_frame
 assert(_recordings_released(recording_refs), "Native mixer must release every tested title/interlude recording")
 print("PASS arranged RESTORED route: eight connected depths, cleared-only art, completed-art/chart toggle and guarded actual HUD texture, next/current and sealed states, same focused Descend callback, unchanged campaign/save and title reset; no earned/physical/rendered proof")
 quit(0)

func _recordings_released(recordings: Array[WeakRef]) -> bool:
 for recording in recordings:
  if recording.get_ref() != null: return false
 return true
