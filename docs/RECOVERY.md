# Crash recovery system

TLDR version:

Valapad creates temporary files for opened document and stores
them in `~/.local/state/dev.mysh.valapad/recovery/`. In there we have folders
with unique IDs and each folder has `content.txt` and `metadata.ini`.

- `content.txt` is the current text buffer of the currently open document.
- `metadata.ini` is the file that contains basic info about the file, in GLib's KeyFile format.

Looks something like the following:

```bash
<UUID>
├── content.txt    # Current file contents
└── metadata.ini   # GLib KeyFile metadata
```

Example of such ini file:

```ini
[Recovery]
version=1
display-name=notes.txt
saved-at=1785410325
cursor-offset=42
use-crlf=false
encoding=UTF-8
original-uri=file:///home/user/Documents/notes.txt
original-etag=1712157396:5310:531086966
```

## `metadata.ini` fields

| Field           | Purpose                                                          |
| --------------- | ---------------------------------------------------------------- |
| `version`       | Recovery format version, currently `1`                           |
| `display-name`  | Name shown in the recovery list                                  |
| `saved-at`      | Unix timestamp of the snapshot                                   |
| `cursor-offset` | Character offset of the insertion cursor                         |
| `use-crlf`      | Whether an explicit save should produce CRLF endings             |
| `encoding`      | Encoding label shown and restored by ValaPad                     |
| `original-uri`  | URI of the original file, when the document has one              |
| `original-etag` | File identity/version value captured when it was opened or saved |

For an Untitled document, `original-uri` and `original-etag` are omitted.

## Sequence of events

Autosaves are happening after 2 seconds of inactivity and every 15 seconds even
if user is currently writing something.

On every autosave ValaPad does the following:

1. Atomically create/replace `content.txt`
2. Atomically create/replace `metadata.ini`

So for the following events at least the contents should be recoverable (with the
2-15 seconds window and we can also crash in the middle of the both operations):

- The process crashes.
- The computer loses power.
- The OS kills the application.
- Save fails.
- Save As is cancelled.
- The close confirmation is cancelled.
- The recovery dialog is closed without selecting Recover or Discard.

In case such as running out of storage, then we can´t do anything.
One way would be to reserve some space in advance and then write data in there,
but this will require to have some sort of custom save format which is not
currently implemented in ValaPad.

Additionally, ValaPad does not monitor changes to a current document,
so changes made to a file by other software will not be recognised immediately
and may result in a funky state.

## Crash and unsaved changes detection

On each startup, ValaPad scans all recovery folders and reconstructs `RecoverySnapshot`
objects from their content and metadata.

If recoveries exist, ValaPad presents a recover documents window, in there user
can see all recovered documents.

![Recover documents window screenshot](/src/docs/screenshots/recover-documents.webp)

## Basic conflict resolution

For named documents, ValaPad stores the file’s etag when it opens or successfully saves the original file.

During recovery, it queries the current etag and compares it with the stored value.

If they differ, the snapshot is marked with "original file changed".

The recovered editor also displays a non-modal warning:

> The original file changed after this backup was created.
> Use Save As to avoid replacing newer changes.

A missing or inaccessible original file is also treated as changed.

![Conflict resolution window screenshot](/src/docs/screenshots/recover-documents.webp)

## Cleanup rules

During startup scanning, ValaPad automatically removes:

- Recovery entries with malformed metadata.
- Entries with missing or invalid content.
- Entries using an unsupported format version.
- Entries whose text is not valid UTF-8.
- Entries older than 30 days.
- Entries with invalid or missing timestamps.

The current retention period is:

```vala
private const int64 MAX_AGE_SECONDS = 60 * 60 * 24 * 30;
```

