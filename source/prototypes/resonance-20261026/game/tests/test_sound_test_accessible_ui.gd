extends SceneTree
## Actual isolated Control events/transport, not Mac input or a listening test.
const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var music = Music.new()
 root.add_child(music)
 var bus := AudioServer.get_bus_index("Music")
 var old_mute := AudioServer.is_bus_mute(bus)
 AudioServer.set_bus_mute(bus,true)
 var initial_effects := AudioServer.get_bus_effect_count(bus)
 var viewport := SubViewport.new()
 viewport.size = Vector2i(640,360)
 root.add_child(viewport)
 var screen = SoundTest.new()
 var preference_edits: Array = []
 screen.reduced_motion_changed.connect(func(enabled: bool): preference_edits.append(enabled))
 screen.set_reduced_motion(true) # Main initializes before add_child.
 screen.bind_music(music)
 viewport.add_child(screen)
 screen.set_process(false)
 for frame in range(5): await process_frame
 check(screen._motion.button_pressed and preference_edits.is_empty(),"Silent pre-ready reduced-motion initialization")
 check(screen._art.size.x >= 400 and screen._art.size.y >= 210,"640 viewport retains a substantial art field")
 print("SOUND_UI_LAYOUT ",JSON.stringify({"screen":str(screen.size),"content_min":str(screen._content.get_combined_minimum_size()),"content_size":str(screen._content.size),"body_min":str(screen._body.get_combined_minimum_size()),"body":str(screen._body.size),"art":str(screen._art.size),"transport_min":str(screen._content.get_child(1).get_combined_minimum_size()),"footer_children":screen._content.get_child(1).get_child(0).get_children().map(func(child): return [child.get_class(),str(child.get_combined_minimum_size()),str(child.size)])}))
 check(screen._content.get_combined_minimum_size().y <= 360.5,"Normal 640x360 controls fit without whole-screen overflow")
 check(screen._progress is HSlider and screen._progress.focus_mode == Control.FOCUS_ALL,"Seek is keyboard-focusable")
 check(screen._style.focus_mode == Control.FOCUS_ALL and screen._volume.focus_mode == Control.FOCUS_ALL,"Style and volume retain keyboard controls")
 check(screen.play_track(8),"Actual selected title recording starts")
 var recording_refs: Array[WeakRef] = [weakref(music.player.stream)]
 check(screen._art_material.get_shader_parameter("track_id") == 2,"Title reprises actual Processional motif, not a ninth composition")
 check(AudioServer.get_bus_effect_count(bus) == initial_effects+1,"One owned passive analyzer")
 screen.focus_selected_track()
 for frame in range(4): await process_frame
 var selected: Button = screen._track_buttons[8]
 var selected_rect: Rect2 = selected.get_global_rect()
 var scroll_rect: Rect2 = screen._track_scroll.get_global_rect()
 check(selected.has_focus() and screen._track_scroll.scroll_vertical > 0,"Last selected track receives real Control focus/scroll")
 check(selected_rect.position.y >= scroll_rect.position.y-0.5 and selected_rect.end.y <= scroll_rect.end.y+0.5,"Selected last track is fully visible inside actual scroll area")
 check(selected.button_pressed,"Selected state is visible independently of keyboard focus")
 var heading_rect: Rect2 = screen._sidebar_heading.get_global_rect()
 check(screen._sidebar_heading.is_visible_in_tree() and heading_rect.position.y >= screen._panel.get_global_rect().position.y and heading_rect.end.y <= scroll_rect.position.y,"Static Resonance heading stays visible above last-selected track scroll")
 check(not screen._track_scroll.is_ancestor_of(screen._sidebar_heading),"Sidebar identity is outside the scrolling button list")
 var stream: AudioStream = music.player.stream
 var duration: float = stream.get_length()
 screen.toggle_playback()
 check(music.player.stream_paused,"Actual transport paused")
 screen._progress.value = 0.25 # Actual slider signal, not a direct player mutation.
 for frame in range(3): await process_frame
 check(music.player.stream == stream and music.player.stream_paused and screen._owns_preview(),"Seek retains stream identity/ownership/pause")
 print("SOUND_UI_SEEK ",JSON.stringify({"duration":duration,"actual_position":music.player.get_playback_position(),"expected_position":duration*0.25,"slider":screen._progress.value,"playing":music.player.playing,"paused":music.player.stream_paused,"owned":screen._owns_preview()}))
 check(absf(music.player.get_playback_position()-duration*0.25) <= 1.0,"Actual native seek follows normalized slider")
 screen._next.grab_focus()
 screen.step_track(1)
 recording_refs.append(weakref(music.player.stream))
 for frame in range(3): await process_frame
 check(screen._selected == 0 and screen._next.has_focus(),"Next wraps selection without stealing transport keyboard focus")
 check(screen._track_scroll.scroll_vertical == 0,"Programmatic new selection scrolls back into view")
 screen._motion.button_pressed = false # USER Control toggle signal.
 check(preference_edits == [false],"Only the CheckButton edit emits reduced-motion preference")
 screen.set_reduced_motion(true)
 check(preference_edits == [false] and screen._motion.button_pressed,"Programmatic update remains silent")
 for control in [screen._progress,screen._previous,screen._play,screen._next,screen._volume,screen._style,screen._motion,screen._back]:
  check(control.get_node(control.focus_next) != null and control.get_node(control.focus_previous) != null,"Complete actual focus cycle")
 music.play_level(0) # External same-stream request must revoke preview ownership.
 recording_refs.append(weakref(music.player.stream))
 screen._sync_transport()
 var before: float = music.player.get_playback_position()
 screen._seek_to_fraction(0.75)
 check(not screen._progress.editable and not screen._owns_preview(),"External owner makes preview seek unavailable")
 check(absf(music.player.get_playback_position()-before) <= 0.1,"Seek cannot alter external playback")
 check(AudioServer.get_bus_effect_count(bus) == initial_effects,"Ownership transfer removes only this analyzer")
 stream = null
 screen.close()
 screen.free()
 viewport.free()
 music.stop()
 music.free()
 var deadline := Time.get_ticks_usec()+2000000
 while not recordings_released(recording_refs) and Time.get_ticks_usec() < deadline:
  OS.delay_msec(2)
  await process_frame
 check(recordings_released(recording_refs),"Owned native recordings drained within bounded teardown")
 AudioServer.set_bus_mute(bus,old_mute)
 if failures == 0: print("PASS actual SoundTest UI: 640 art/transport bounds, selected scroll/focus, owned native seek, keyboard cycle, silent preference init and analyzer cleanup; no physical/listening proof")
 quit(0 if failures == 0 else 1)
func recordings_released(references: Array[WeakRef]) -> bool:
 for reference in references:
  if reference.get_ref() != null: return false
 return true
