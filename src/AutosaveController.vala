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
    public signal void saved ();
    private signal void pending_save_invalidated ();

    private Gtk.TextBuffer buffer;
    private RecoveryStore store;
    private string recovery_id;
    private Document document = new Document ();
    private uint debounce_source;
    private uint deadline_source;
    private uint debounce_milliseconds;
    private uint deadline_milliseconds;
    private bool suspended;
    private bool dirty;
    private bool saving;
    private string? last_saved_text;
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

    // Points the controller at the document the next snapshot describes.
    // Documents are replaced rather than modified, so keeping the reference is
    // safe.
    public void update_document (Document document) {
        this.document = document;
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
        invalidate_pending ();

        recovery_id = id;
        debug ("Recovery snapshot adopted: id=%s", recovery_id);
    }

    public async void reset () {
        string old_id = recovery_id;
        invalidate_pending ();

        recovery_id = Uuid.string_random ();
        debug ("Recovery controller reset: old-id=%s new-id=%s", old_id, recovery_id);
        try {
            yield store.delete (old_id);
        } catch (Error error) {
            save_failed (error.message);
        }
    }

    public async void clear () {
        string old_id = recovery_id;
        invalidate_pending ();

        // Rotate the id so a save that is still finishing for the old id can
        // never delete a snapshot that a later save writes under this controller.
        recovery_id = Uuid.string_random ();
        debug ("Clearing recovery snapshot: old-id=%s new-id=%s", old_id, recovery_id);
        try {
            yield store.delete (old_id);
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

    public async bool flush () {
        if (suspended) {
            debug ("Recovery flush skipped: id=%s generation=%u reason=suspended", recovery_id, generation);
            return false;
        }
        if (!buffer.get_modified ()) {
            debug ("Recovery flush skipped: id=%s reason=buffer-clean", recovery_id);
            return true;
        }

        uint attempt = 0;
        debug (
            "Recovery flush started: id=%s generation=%u chars=%d",
            recovery_id,
            generation,
            (int) buffer.text.char_count ()
        );
        while (buffer.get_modified ()) {
            if (suspended) {
                debug ("Recovery flush aborted: id=%s generation=%u reason=suspended", recovery_id, generation);
                return false;
            }
            attempt++;
            last_saved_text = null;
            debug (
                "Recovery flush waiting: id=%s generation=%u attempt=%u chars=%d",
                recovery_id,
                generation,
                attempt,
                (int) buffer.text.char_count ()
            );
            if (!(yield wait_for_save ())) {
                debug (
                    "Recovery flush failed: id=%s generation=%u attempt=%u",
                    recovery_id,
                    generation,
                    attempt
                );
                return false;
            }
            if (last_saved_text == buffer.text || !buffer.get_modified ()) {
                debug (
                    "Recovery flush completed: id=%s generation=%u attempt=%u chars=%d",
                    recovery_id,
                    generation,
                    attempt,
                    (int) buffer.text.char_count ()
                );
                return true;
            }
            debug (
                "Recovery flush retrying: id=%s generation=%u attempt=%u saved-chars=%d current-chars=%d",
                recovery_id,
                generation,
                attempt,
                last_saved_text != null ? (int) last_saved_text.char_count () : 0,
                (int) buffer.text.char_count ()
            );
        }
        return true;
    }

    private async bool wait_for_save () {
        SourceFunc callback = wait_for_save.callback;
        bool succeeded = false;
        bool completed = false;
        ulong saved_handler = saved.connect (() => {
            if (!completed) {
                succeeded = true;
                completed = true;
                callback ();
            }
        });
        ulong failed_handler = save_failed.connect ((message) => {
            if (!completed) {
                completed = true;
                callback ();
            }
        });
        ulong invalidated_handler = pending_save_invalidated.connect (() => {
            if (!completed) {
                completed = true;
                callback ();
            }
        });

        schedule_now ();
        yield;

        disconnect (saved_handler);
        disconnect (failed_handler);
        disconnect (invalidated_handler);
        return succeeded;
    }

    public void schedule_cursor_update () {
        if (suspended || !buffer.get_modified ()) {
            return;
        }
        dirty = true;
        if (debounce_source == 0) {
            arm_debounce ();
        }
    }

    private void on_buffer_changed () {
        if (suspended) {
            return;
        }

        dirty = true;
        arm_debounce ();
        arm_deadline ();
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
        File? file = document.file;
        var snapshot = new RecoverySnapshot (recovery_id) {
            text = buffer.text,
            display_name = document.display_name (),
            original_uri = file != null ? file.get_uri () : null,
            original_etag = document.etag,
            saved_at = new DateTime.now_utc ().to_unix (),
            cursor_offset = cursor.get_offset (),
            use_crlf = document.use_crlf,
            has_bom = document.has_bom,
            encoding_name = document.encoding
        };

        bool written = false;
        try {
            yield store.save (snapshot, cancellable);
            written = true;
            debug (
                "Recovery snapshot write completed: id=%s chars=%d cursor=%d",
                snapshot.id,
                (int) snapshot.text.char_count (),
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
        } else {
            if (written) {
                last_saved_text = snapshot.text;
                saved ();
            }
            if (dirty) {
                start_save ();
            }
        }
    }

    private void invalidate_pending () {
        pending_save_invalidated ();
        cancel_timers ();
        generation++;
        dirty = false;
        last_saved_text = null;
        save_cancellable?.cancel ();
    }

    private void arm_debounce () {
        if (debounce_source != 0) {
            Source.remove (debounce_source);
        }
        debounce_source = Timeout.add (debounce_milliseconds, () => {
            debounce_source = 0;
            start_save ();
            return Source.REMOVE;
        });
    }

    private void arm_deadline () {
        if (deadline_source != 0) {
            return;
        }
        deadline_source = Timeout.add (deadline_milliseconds, () => {
            deadline_source = 0;
            start_save ();
            return Source.REMOVE;
        });
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
