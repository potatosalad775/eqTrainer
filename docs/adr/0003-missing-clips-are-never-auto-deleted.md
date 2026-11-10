# A clip whose file is missing is never deleted automatically

The app does not delete a clip's record because its file cannot be found. "Missing" is derived by looking at the disk when asked and is never saved in `audio_clips.json`. A session skips missing clips. The playlist shows them as not found, with preview and the enable toggle disabled, and only the user can delete them.

Starting a session used to delete the record of any enabled clip whose file was missing, from inside a method named as a read. That turns one failed existence check into permanent loss of the record. `ClipFormatMigration` already refused to do the same. A saved flag was rejected because it would go stale and would change the file format that older versions read after a downgrade.

## Consequences

Missing clips can accumulate until the user removes them. If no enabled clip is playable, the session shows the existing empty-playlist state.
