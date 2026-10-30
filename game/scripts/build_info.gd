extends RefCounted
## Public display identity only. Keep project config/name and bundle ID stable:
## changing them can strand the existing user://campaign.json save directory.
const BUILD_ITERATION = 97
const VERSION = "0.097"
const DISPLAY_NAME = "Null Choir v0.097"
const APP_NAME = DISPLAY_NAME
const ARCHIVE_NAME = "Null-Choir-v0.097.zip"

static func display_name() -> String:
	return DISPLAY_NAME
