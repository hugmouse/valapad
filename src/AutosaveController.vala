/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Watches one editor buffer and periodically updates its recovery snapshot.
public class ValaPad.AutosaveController : Object {
    // Save after typing pauses, but also cap the delay during continuous typing
    // e.g. if user types continuously for 15 seconds, we just save anyway.
    // and if user didn't type anything for the last 2 seconds, we save too.

    public signal void save_failed (string message);

    private Gtk.TextBuffer buffer;
    private RecoveryStore store;
    private string recovery_id;
    private string display_name = "Untitled";
    private string? original_uri;
    private string? original_etag;
    private bool use_crlf;
    private string encoding_name = "UTF-8";
    private uint debounce_source;
    private uint deadline_source;
    private uint debounce_milliseconds;
    private uint deadline_milliseconds;
    private bool suspended;
    private bool dirty;
    private bool saving;
    private uint generation;
    private Cancellable? save_cancellable;

    public AutosaveController (Gtk.TextBuffer buffer,
                               RecoveryStore store,
                               uint debounce_milliseconds = 2 * 1000,
                               uint deadline_milliseconds = 15 * 1000) {
        this.buffer = buffer;
        this.store = store;
        this.debounce_milliseconds = debounce_milliseconds;
        this.deadline_milliseconds = deadline_milliseconds;
        recovery_id = Uuid.string_random ();
        debug ("Recovery controller created: id=%s", recovery_id);
        buffer.changed.connect (on_buffer_changed);
    }

    public void update_document (string display_name,
                                 File? original_file,
                                 string? original_etag,
                                 bool use_crlf,
                                 string encoding_name) {
        this.display_name = display_name;
        this.original_uri = original_file != null? original_file.get_uri () : null;

        this.original_etag = original_etag;
        this.use_crlf = use_crlf;
        this.encoding_name = encoding_name;
    }

    // Buffer changes such as opening or restoring a file must not
    // be mistaken for user edits.
    public void suspend () {
        suspended = true;
    }

    public void resume () {
        suspended = false;
    }

    public void adopt_recovery (string id) {
        cancel_timers ();
        generation++;
        dirty = false;
        save_cancellable?.cancel ();

        recovery_id = id;
        debug ("Recovery snapshot adopted: id=%s", recovery_id);
    }

    public async void reset () {
        string old_id = recovery_id;
        cancel_timers ();
        generation++;
        dirty = false;
        save_cancellable?.cancel ();

        recovery_id = Uuid.string_random ();
        debug ("Recovery controller reset: old-id=%s new-id=%s", old_id, recovery_id);
        try {
            yield store.delete (old_id);
        } catch (Error error) {
            save_failed (error.message);
        }
    }

    public async void clear () {
        cancel_timers ();
        generation++;
        dirty = false;
        save_cancellable?.cancel ();

        debug ("Clearing recovery snapshot: id=%s", recovery_id);
        try {
            yield store.delete (recovery_id);
        } catch (Error error) {
            save_failed (error.message);
        }
    }

    public void schedule_now () {
        if (!suspended && buffer.get_modified ()) {
            dirty = true;
            start_save ();
        }
    }

    public void schedule_cursor_update () {
        if (suspended || !buffer.get_modified ()) {
            return;
        }
        dirty = true;
        if (debounce_source == 0) {
            debounce_source = Timeout.add (debounce_milliseconds, () => {
                debounce_source = 0;
                start_save ();
                return Source.REMOVE;
            });
        }
    }

    private void on_buffer_changed () {
        if (suspended) {
            return;
        }

        dirty = true;
        if (debounce_source != 0) {
            Source.remove (debounce_source);
        }
        debounce_source = Timeout.add (debounce_milliseconds, () => {
            debounce_source = 0;
            start_save ();
            return Source.REMOVE;
        });

        if (deadline_source == 0) {
            deadline_source = Timeout.add (deadline_milliseconds, () => {
                deadline_source = 0;
                start_save ();
                return Source.REMOVE;
            });
        }
    }

    private void start_save () {
        if (!dirty || suspended || !buffer.get_modified ()) {
            return;
        }
        if (saving) {
            return;
        }

        cancel_timers ();
        dirty = false;
        saving = true;
        uint save_generation = generation;
        save_cancellable = new Cancellable ();
        debug ("Recovery snapshot scheduled for writing: id=%s generation=%u", recovery_id, save_generation);
        save_snapshot.begin (save_generation, save_cancellable);
    }

    private async void save_snapshot (uint save_generation, Cancellable cancellable) {
        Gtk.TextIter cursor;
        buffer.get_iter_at_offset (out cursor, buffer.cursor_position);
        var snapshot = new RecoverySnapshot (recovery_id) {
            text = buffer.text,
            display_name = display_name,
            original_uri = original_uri,
            original_etag = original_etag,
            saved_at = new DateTime.now_utc ().to_unix (),
            cursor_offset = cursor.get_offset (),
            use_crlf = use_crlf,
            encoding_name = encoding_name
        };

        try {
            yield store.save (snapshot, cancellable);
            debug (
                "Recovery snapshot write completed: id=%s chars=%d cursor=%d",
                snapshot.id,
                snapshot.text.char_count (),
                snapshot.cursor_offset
            );
        } catch (IOError.CANCELLED error) {
            debug ("Recovery snapshot write cancelled: id=%s", snapshot.id);
        } catch (Error error) {
            debug ("Recovery snapshot write failed: id=%s error=%s", snapshot.id, error.message);
            save_failed (error.message);
        }

        saving = false;
        save_cancellable = null;
        // A reset may happen while an async write is finishing.
        // Remove that stale snapshot instead of attaching it to the next document.
        if (save_generation != generation) {
            try {
                yield store.delete (snapshot.id);
            } catch (Error error) {
            }
        } else if (dirty) {
            start_save ();
        }
    }

    private void cancel_timers () {
        if (debounce_source != 0) {
            Source.remove (debounce_source);
            debounce_source = 0;
        }
        if (deadline_source != 0) {
            Source.remove (deadline_source);
            deadline_source = 0;
        }
    }
}
