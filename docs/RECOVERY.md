# Crash recovery system

TLDR version:

Valapad creates a temporary file for each opened document and stores
them in `~/.local/state/dev.mysh.valapad/recovery/`. Every snapshot is a
single self-contained file named after a UUID.

The file starts with a small header (VALAPADR) then the GLib KeyFile metadata, and last the content of the currently open document:

Container layout:

| Offset         | Size | Field                         |
| -------------- | ---- | ----------------------------- |
| 0              | 8    | Magic signature `VALAPADR`    |
| 8              | 4    | Format version, currently `2` |
| 12             | 4    | Size of the metadata section  |
| 16             | `n`  | GLib KeyFile metadata         |
| 16 + `n`       | `m`  | Document contents as UTF-8    |
| 16 + `n` + `m` | 1    | NUL                           |

The text follows the metadata with a NUL byte after it.

Example of the metadata section:

```ini
[Recovery]
display-name=notes.txt
saved-at=1785410325
cursor-offset=42
use-crlf=false
use-bom=false
encoding=UTF-8
original-uri=file:///home/user/Documents/notes.txt
original-etag=1712157396:5310:531086966
```

## Metadata fields

| Field           | Purpose                                                          |
| --------------- | ---------------------------------------------------------------- |
| `display-name`  | Name shown in the recovery list                                  |
| `saved-at`      | Unix timestamp of the snapshot                                   |
| `cursor-offset` | Character offset of the insertion cursor                         |
| `use-crlf`      | Whether an explicit save should produce CRLF endings             |
| `use-bom`       | Whether an explicit save should write a UTF-8 BOM                |
| `encoding`      | Encoding label shown and restored by ValaPad                     |
| `original-uri`  | URI of the original file, when the document has one              |
| `original-etag` | File identity/version value captured when it was opened or saved |

For an Untitled document, `original-uri` and `original-etag` are omitted.

## Sequence of events

Autosaves are happening after 2 seconds of inactivity and every 15 seconds even
if user is currently writing something.

On every autosave ValaPad does the following:

1. Writes the complete snapshot to `<UUID>.tmp`.
2. Publishes it by renaming `<UUID>.tmp` over `<UUID>`.

So for the following events at least the contents should be recoverable (with the 2-15 seconds window):

- The process crashes.
- The computer loses power.
- The OS kills the application.
- Save fails.
- Save As is cancelled.
- The close confirmation is cancelled.
- The recovery dialog is closed without selecting Recover or Discard.

In a case such as running out of storage there is not much we can do: when the
staging write fails there is nothing to publish, so the previous snapshot stays
in place but the newest changes are lost. Reserving space in advance so the
snapshot always fits could help, but I don't know how to approach that.

## Migration from version 1 to version 2

Format version 1 stored each snapshot as a directory with separate
`content.txt` and `metadata.ini` files. Those directories are still read: when a
legacy directory is loaded it is rewritten in place as a single version 2 file,
so the next start already uses the new layout. A legacy directory that is
overwritten by a save is removed before the rename.

Migration from v1 to v2 is one-way. 

Version 1 only scanned recovery dirs and ignored regular files, so once a
snapshot has been rewritten as a version 2 file an older build no longer sees it.
The file stays on disk, but downgrading ValaPad effectively hides the snapshots
that were already migrated.

Additionally, ValaPad does not monitor changes to a current document,
so changes made to a file by other software will not be recognised immediately
and may result in a funky state.

## Crash and unsaved changes detection

On each startup, ValaPad scans all recovery files and reconstructs `RecoverySnapshot`
objects from their content and metadata.

If recoveries exist, ValaPad presents a recover documents window, in there user
can see all recovered documents.

![Recover documents window screenshot](screenshots/recover-documents.webp)

## Basic conflict resolution

For named documents, ValaPad stores the file’s etag when it opens or successfully saves the original file.

During recovery, it queries the current etag and compares it with the stored value.

If they differ, the snapshot is marked with "original file changed".

The recovered editor also displays a non-modal warning:

> The original file changed after this backup was created.
> Use Save As to avoid replacing newer changes.

A missing or inaccessible original file is also treated as changed.

![Conflict resolution window screenshot](screenshots/original-file-changed.webp)

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
