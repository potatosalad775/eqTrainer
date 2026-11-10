# eqTrainer

An ear-training app. Users listen to audio processed through a parametric EQ and identify which frequency band was boosted or cut, using clips they import.

## Language

### Clips

**Clip**:
An app-owned copy of a piece of audio the user imported, made of a record and a file.
_Avoid_: Track, sample, audio file

**Record**:
A clip's entry in the library: its id, file name, name, duration, enabled flag and position.

**Clip file**:
The audio file behind a clip, in the app's clips directory. Its basename is the clip's id; its extension can change.

**Clip id**:
What identifies a clip. For anything imported now it is the file's basename, which a rewrite preserves.

**Clip library**:
All clips, records and files together, and the module that owns both. It used to mean only `audio_clips.json`, which is now just where the records are stored.

**Rewrite**:
Replacing a clip's file with the same audio in another format while keeping its record and id. It is committed by repointing the record before the old file is removed.

**Library-rewrite pass**:
A background job that rewrites many clips. There are two: the format migration (automatic, legacy formats) and the recompress (user-triggered, WAV to FLAC).

**Import**:
One pass from picking a file to saving a clip. It converts the file if the format policy says to, lets the user trim it, and ends in a clip or in nothing. It is owned by `ClipImport`.
_Avoid_: Import session ("session" is a training run)

**Missing clip**:
A clip whose record exists but whose file cannot be found. It is derived and never saved. See ADR 0003.
_Avoid_: Dangling record, orphan (an orphan is the reverse: a file with no record)

**Orphan file**:
A file in the clips directory that no record points at.

### Audio

**Output selection**:
The Android backend and the output device the engine opens, and the module that owns them. There is one for the whole app. A player reads the device at each launch and the backend when the engine starts.
_Avoid_: Audio state

### Training

**Session**:
One run of training, from Start until the user leaves.

**Round**:
One question within a session: one graph to identify as the one being applied to the audio.

**Band**:
One of the frequency bands a round can ask about. The band count belongs to the session: it starts at the configured value and moves along the band ladder.

**Graph**:
One selectable curve in a round. In peak-and-dip mode each band has two, a peak and a dip.

**Queue**:
The enabled clips a session plays, in library order, fixed when the session starts.
_Avoid_: playlist (the playlist is the screen that manages the library)

**Points**:
The running score within a session that moves the band count: plus one for a correct answer and minus one for a wrong one.

**Band ladder**:
The rule that raises the band count when the points reach the threshold and lowers it when they reach minus the threshold, between 2 and 25 bands.
