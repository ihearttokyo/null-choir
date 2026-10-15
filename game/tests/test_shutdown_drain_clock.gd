extends SceneTree

func _initialize() -> void:
    AudioServer.set_bus_mute(0,true)
    call_deferred("run")

func run() -> void:
    var game = load("res://scripts/main.gd").new()
    game.progress_path = "user://shutdown_clock_"+str(OS.get_process_id())+".json"
    game.settings_path = "user://shutdown_clock_"+str(OS.get_process_id())+"_preferences.json"
    root.add_child(game)
    game.start_campaign(1)
    for frame in range(4): await physics_frame
    if not game.playing or not game.music.player.playing or not game.music.player.stream is AudioStreamMP3:
        push_error("shutdown clock setup requires live current Suno playback")
        game._finish_quit()
        return
    # A long frame must not consume a timer created only at its end.
    OS.delay_msec(250)
    var started: int = Time.get_ticks_usec()
    game._finish_quit()
    game._finish_quit()
    var stopped: bool = game.quitting and not game.playing and not game.music.player.playing and game.music.player.stream == null
    root.tree_exiting.connect(func():
        var elapsed: int = Time.get_ticks_usec()-started
        print("SHUTDOWN_REAL_USEC ",elapsed)
        if stopped and elapsed >= 100000: print("PASS current Suno shutdown retains100ms actual mixer drain and idempotent title stop")
        else: push_error("NATIVE RED shutdown requires stopped audio and100ms actual mixer drain"))
