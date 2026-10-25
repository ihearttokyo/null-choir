# Descent Map

Open **Descent map** from Pause or a completed campaign's ending. It shows all eight depths as cleared, current or unreached. Unreached depth names stay hidden.

The current objective reflects the Blood and Ivory seals already held. It does not reveal pickup positions, bypass encounters or grant progress. Recovered records can be opened directly; unrecovered record titles and bodies remain hidden.

Use the normal menu controls to focus the map panel. Page Down scrolls to its final entry; Back returns to Pause or the ending. Resume retains the normal gameplay and audio behavior.

The view reads existing campaign fields. It adds no save format, actor state, teleport, difficulty change, reward or network dependency. Viewing the map and records leaves the campaign and saved file unchanged.

Native tests cover isolated overview data, actual Intake startup, pause/back/resume, keyboard scrolling, stale callers, ending navigation and record membership. Completed progress and discoveries in the UI fixtures are arranged test states, not earned-campaign evidence. Physical controller coverage and rendered visual acceptance remain separate checks.


## Illustrated descent (local candidate)

The pause/ending map now adds eight linked chapter illustrations below its existing keyboard-scrollable text overview. The original text remains the accessible progress/record route. The illustrations are conceptual chapter art, not a navigable or geometrically accurate floor plan. Current and cleared chapters reveal their artwork; unreached chapters remain sealed and their textures are not loaded. This screen grants no travel, keys, records or resources.

A gentle current-depth pulse is opt-in through **Animate descent illustration**. Motion is off on every opening; disabling it resets the phase to a still image. All illustrations and processing belong to the disposable menu component, with no retained Main/Campaign reference or preference/save changes.

The eight JPEG derivatives total under 200 KiB, mechanically downsampled from retained native 7680×4320 Blender master candidates. Seven views use the unchanged prototype09 source; the Heart uses its later fang-weight74 source. Masters remain private authoring inputs, outside the runtime. Their existence does not certify final visual quality, complete intro transitions, physical input, or campaign acceptance. Source/UI tests do not certify final rendered appearance.


## Chapter introductions (local candidate, not yet in the public preview)

The existing difficulty-choice screen introduces the Intake; the seven existing earned intermissions introduce the next unlocked chapter. Each uses its rendered chapter artwork as the background, a persistent numbered chapter caption, and a focusable themed briefing. No new mandatory click, timer, save format or campaign grant is introduced. Difficulty/Descend controls retain initial focus and their existing callbacks. Tab reaches the briefing and the outer menu follows focus; current control bounds are checked against the actual scrollbar client.

Menu metadata owns only the transient chapter index and is cleared on unrelated menus. Introductions require paused, no-level, non-playing/non-placement screens: either the actual new-campaign difficulty choice or the current earned RESTORED intermission. Future/invalid/stale introduction requests are rejected. HUD owns at most the currently selected compact chapter texture; normal title/settings return to the cathedral background, while gameplay keeps its existing HUD rendering. This is not a timed cinematic, and it does not establish played pacing, cold-load, full campaign, physical input, listening or final art acceptance.
