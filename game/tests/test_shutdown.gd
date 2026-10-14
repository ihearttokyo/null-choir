extends SceneTree
const Main = preload("res://scripts/main.gd")
func _initialize():
    AudioServer.set_bus_mute(0, true)
    call_deferred("run")
func run():
    var args = OS.get_cmdline_user_args()
    assert(args.size() == 2)
    var game = Main.new()
    game.progress_path = args[1].path_join("progress.json")
    game.settings_path = args[1].path_join("preferences.json")
    root.add_child(game)
    await process_frame
    game.start_campaign(0)
    await create_timer(1).timeout
    game.pause_game()
    game.save_and_title()
    await process_frame
    await game.continue_campaign()
    await create_timer(1).timeout
    assert(game.playing and game.music.player.playing)
    assert(game.music.player.has_stream_playback())
    if args[0] == "discard":
        game.progress_path = args[1].path_join("blocked")
        assert(DirAccess.make_dir_absolute(game.progress_path) == OK)
        assert(not game.quit_game())
        assert(not game.quitting)
        assert(game.music.player.has_stream_playback() and game.music.player.stream_paused)
        var button: Button
        for node in game.menu.get_children():
            if node is Button and node.text == "Quit without saving": button = node
        assert(button != null)
        button.pressed.emit()
    else:
        assert(game.quit_game())
    assert(not game.playing and not game.placement_pending)
    assert(game.quitting)
    assert(game.level == null and game.player == null)
    assert(not game.music.player.playing and game.music.player.stream == null)
    assert(game.effects.players.values().all(func(p): return not p.playing))
    assert(game.quit_game())
    print("PASS native CoreAudio shutdown stops live voices and accepts "+args[0]+" with released playback resources")
