/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Persists one private recovery file per document in the user's state
// directory. Text and metadata are loaded at startup.
// In version 1 (1.0.0-1.2.0) it was 2 files in a folder, see
// RECOVERY.md for details.
public class ValaPad.RecoveryStore : Object {
    private const string GROUP = "Recovery";
    private const int64 MAX_AGE_SECONDS = 60 * 60 * 24 * 30;
    private const string STAGING_SUFFIX = ".tmp";

    // Container layout:
    //
    // - 8 byte "VALAPADR" signature ,
    // - uint32 format version,
    // - uint32 metadata size,
    // - the KeyFile metadata,
    // - document text with a NUL byte at the end
    //
    // The NUL byte keeps the text usable as a C string once the
    // container is read. See docs/RECOVERY.md for the full table.
    private const string MAGIC = "VALAPADR";
    private const int HEADER_SIZE = 16;

    // Format version 1 kept content.txt and metadata.ini inside a directory per
    // snapshot. Those directories are migrated when they are loaded.
    private const int LEGACY_FORMAT_VERSION = 1;
    private const string LEGACY_METADATA_FILE = "metadata.ini";
    private const string LEGACY_CONTENT_FILE = "content.txt";

    private File root;

    public RecoveryStore (string? directory = null) {
        string path = directory ?? Path.build_filename (
                                                        Environment.get_user_state_dir (),
                                                        Build.PROJECT_NAME,
                                                        "recovery"
        );
        root = File.new_for_path (path);
    }

    public async void save (RecoverySnapshot snapshot, Cancellable? cancellable = null) throws Error {
        debug ("Writing recovery snapshot: id=%s bytes=%zu", snapshot.id, snapshot.text.data.length);

        ensure_directory (root);

        yield publish (snapshot, cancellable);

        debug ("Recovery snapshot published: id=%s", snapshot.id);
    }

    public async RecoverySnapshot[] load_all (Cancellable? cancellable = null) throws Error {
        RecoverySnapshot[] snapshots = {};
        debug ("Scanning recovery store");
        if (!root.query_exists (cancellable)) {
            debug ("Recovery store does not exist yet");
            return snapshots;
        }

        yield publish_interrupted_saves (cancellable);

        foreach (string name in yield list_entries (cancellable)) {
            if (name.has_suffix (STAGING_SUFFIX)) {
                continue;
            }

            File entry = root.get_child (name);
            FileType type = query_type (entry, cancellable);
            if (type != FileType.DIRECTORY && type != FileType.REGULAR) {
                continue;
            }

            RecoverySnapshot? snapshot = yield load_entry (entry, name, type, cancellable);

            if (snapshot != null) {
                snapshots += snapshot;
            }
        }

        CompareDataFunc<RecoverySnapshot> by_newest_first = (a, b) => (int) (b.saved_at - a.saved_at);
        GLib.qsort_with_data (snapshots, sizeof (RecoverySnapshot), by_newest_first);
        debug ("Recovery scan completed: count=%d", snapshots.length);
        return snapshots;
    }

    public async void delete (string id, Cancellable? cancellable = null) throws Error {
        // A staging file can hold a copy that is newer than the published
        // snapshot, so it is discarded as well. Otherwise the next start would
        // publish the very snapshot that was just dropped.
        File staging = root.get_child (id + STAGING_SUFFIX);
        if (staging.query_exists (cancellable)) {
            yield delete_entry (staging, cancellable);
        }

        File entry = root.get_child (id);
        if (entry.query_exists (cancellable)) {
            yield delete_entry (entry, cancellable);

            debug ("Recovery snapshot deleted: id=%s", id);
        } else {
            debug ("Recovery snapshot already absent: id=%s", id);
        }
    }

    // Writes the snapshot next to its final name and then publishes it with
    // rename(2), which atomically replaces the previous snapshot file. A format
    // version 1 directory cannot be replaced by rename(2), so it is removed
    // first. If interrupted, the complete staging file holds the new
    // snapshot and is published on the next start instead.
    //
    // See RECOVERY.md for details upon why.
    private async void publish (RecoverySnapshot snapshot, Cancellable? cancellable) throws Error {
        File target = root.get_child (snapshot.id);
        File staging = root.get_child (snapshot.id + STAGING_SUFFIX);
        string? ignored_etag;

        // A leftover format version 1 staging directory cannot be replaced by a
        // file write, so remove it first.
        if (is_directory (staging, cancellable)) {
            yield delete_directory (staging, cancellable);
        }

        uint8[] container = container_for (snapshot);
        yield staging.replace_contents_async (container,
            null,
            false,
            FileCreateFlags.REPLACE_DESTINATION | FileCreateFlags.PRIVATE,
            cancellable,
            out ignored_etag);

        debug ("Recovery snapshot staged: id=%s", snapshot.id);

        if (is_directory (target, cancellable)) {
            debug ("Replacing legacy recovery snapshot directory: id=%s", snapshot.id);
            yield delete_directory (target, cancellable);
        }
        if (GLib.FileUtils.rename (staging.get_path (), target.get_path ()) != 0) {
            throw new FileError.FAILED ("unable to rename recovery snapshot into place");
        }
    }

    // Loads one store entry and returns the snapshot it holds, or null when the
    // entry is not, or no longer, offered for recovery.
    private async RecoverySnapshot ? load_entry (File entry,
                                                 string id,
                                                 FileType type,
                                                 Cancellable? cancellable) throws Error {
        RecoverySnapshot snapshot;
        try {
            switch (type) {
            case FileType.DIRECTORY :
                snapshot = yield load_legacy (entry, id, cancellable);

                break;
            case FileType.REGULAR :
                snapshot = yield load_container (entry, id, cancellable);

                break;
                default :
                return null;
            }
        } catch (Error error) {
            debug ("Removing invalid recovery entry: id=%s error=%s", id, error.message);
            yield delete_entry (entry, cancellable);

            return null;
        }

        if (is_expired (snapshot)) {
            debug ("Removing expired recovery snapshot: id=%s", snapshot.id);
            yield delete_entry (entry, cancellable);

            return null;
        }

        if (type == FileType.DIRECTORY) {
            // Rewrite the legacy directory as a single file, so that the next start already uses the new layout.
            try {
                yield publish (snapshot, cancellable);

                debug ("Migrated recovery snapshot to the single file format: id=%s", snapshot.id);
            } catch (Error error) {
                debug ("Unable to migrate recovery snapshot: id=%s error=%s", id, error.message);
            }
        }

        snapshot.original_changed = original_has_changed (snapshot, cancellable);
        debug (
               "Recovery snapshot found: id=%s chars=%d original-changed=%s",
               snapshot.id,
               (int) snapshot.text.char_count (),
               snapshot.original_changed.to_string ()
        );
        return snapshot;
    }

    private async RecoverySnapshot load_container (File file, string id, Cancellable? cancellable) throws Error {
        uint8[] contents;
        string? ignored_etag;
        yield file.load_contents_async (cancellable, out contents, out ignored_etag);

        return parse_container (contents, id);
    }

    // Reads a format version 1 snapshot directory.
    private async RecoverySnapshot load_legacy (File directory, string id, Cancellable? cancellable) throws Error {
        uint8[] metadata_bytes;
        string? ignored_etag;
        yield directory.get_child (LEGACY_METADATA_FILE).load_contents_async (
                                                                              cancellable,
                                                                              out metadata_bytes,
                                                                              out ignored_etag
        );

        var metadata = new KeyFile ();
        metadata.load_from_data ((string) metadata_bytes, metadata_bytes.length, KeyFileFlags.NONE);
        if (metadata.get_integer (GROUP, "version") != LEGACY_FORMAT_VERSION) {
            throw new IOError.INVALID_DATA ("Unsupported recovery format version");
        }

        uint8[] content;
        yield directory.get_child (LEGACY_CONTENT_FILE).load_contents_async (
                                                                             cancellable,
                                                                             out content,
                                                                             out ignored_etag
        );

        string text = (string) content;
        if (!text.validate ()) {
            throw new IOError.INVALID_DATA ("Recovery content is not UTF-8");
        }
        return snapshot_from_metadata (metadata, text, id);
    }

    private static RecoverySnapshot parse_container (uint8[] bytes, string id) throws Error {
        if (bytes.length < HEADER_SIZE) {
            throw new IOError.INVALID_DATA ("Recovery snapshot is truncated");
        }

        var input = new DataInputStream (new MemoryInputStream.from_data (bytes, null));
        input.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

        uint8[] magic = new uint8[MAGIC.length];
        input.read (magic, null);
        for (int i = 0; i < MAGIC.length; i++) {
            if (magic[i] != MAGIC.data[i]) {
                throw new IOError.INVALID_DATA ("Recovery snapshot has an unknown signature");
            }
        }

        uint32 version = input.read_uint32 (null);
        if (version != (uint32) RecoverySnapshot.FORMAT_VERSION) {
            throw new IOError.INVALID_DATA ("Unsupported recovery format version %u".printf (version));
        }

        // The metadata is followed by at least the NUL byte that ends the text.
        int metadata_size = (int) input.read_uint32 (null);
        if (metadata_size < 0 || metadata_size > bytes.length - HEADER_SIZE - 1) {
            throw new IOError.INVALID_DATA ("Recovery snapshot is truncated");
        }
        if (bytes[bytes.length - 1] != 0) {
            throw new IOError.INVALID_DATA ("Recovery snapshot is truncated");
        }

        uint8[] metadata_bytes = bytes[HEADER_SIZE : HEADER_SIZE + metadata_size];
        var metadata = new KeyFile ();
        metadata.load_from_data ((string) metadata_bytes, metadata_bytes.length, KeyFileFlags.NONE);

        // Include the trailing NUL byte so that the text is a valid C string.
        uint8[] content = bytes[HEADER_SIZE + metadata_size : bytes.length];
        string text = (string) content;
        if (!text.validate ()) {
            throw new IOError.INVALID_DATA ("Recovery content is not UTF-8");
        }
        return snapshot_from_metadata (metadata, text, id);
    }

    // A staging entry only survives a crash between writing a snapshot and
    // publishing it with rename(2).
    //
    // A staging file that parses is complete and is newer than
    // the published snapshot, so it is published rather than thrown away.
    private async void publish_interrupted_saves (Cancellable? cancellable) throws Error {
        string[] names = yield list_entries (cancellable);

        foreach (string name in names) {
            if (!name.has_suffix (STAGING_SUFFIX)) {
                continue;
            }

            File staging = root.get_child (name);
            string id = name.substring (0, name.length - STAGING_SUFFIX.length);
            bool complete = false;
            if (query_type (staging, cancellable) == FileType.REGULAR) {
                complete = yield is_complete_container (staging, id, cancellable);
            }

            if (complete) {
                File target = root.get_child (id);
                if (is_directory (target, cancellable)) {
                    yield delete_directory (target, cancellable);
                }
                if (GLib.FileUtils.rename (staging.get_path (), target.get_path ()) == 0) {
                    debug ("Published interrupted recovery snapshot: id=%s", id);
                    continue;
                }
            }

            debug ("Removing stale recovery staging entry: name=%s", name);
            yield delete_entry (staging, cancellable);
        }
    }

    private async bool is_complete_container (File file, string id, Cancellable? cancellable) {
        try {
            uint8[] contents;
            string? ignored_etag;
            yield file.load_contents_async (cancellable, out contents, out ignored_etag);

            parse_container (contents, id);
            return true;
        } catch (Error error) {
            return false;
        }
    }

    // Lists the store entries up front. Loading mutates the directory, which
    // must not happen while it is still being enumerated.
    private async string[] list_entries (Cancellable? cancellable) throws Error {
        string[] names = {};
        FileEnumerator enumerator = yield root.enumerate_children_async (FileAttribute.STANDARD_NAME,
            FileQueryInfoFlags.NONE,
            Priority.DEFAULT,
            cancellable);

        FileInfo? info;
        while ((info = enumerator.next_file (cancellable)) != null) {
            names += info.get_name ();
        }
        yield enumerator.close_async (Priority.DEFAULT, cancellable);

        return names;
    }

    private static RecoverySnapshot snapshot_from_metadata (KeyFile metadata, string text, string id) throws Error {
        var snapshot = new RecoverySnapshot (id) {
            text = text,
            display_name = metadata.get_string (GROUP, "display-name"),
            saved_at = metadata.get_int64 (GROUP, "saved-at"),
            cursor_offset = metadata.get_integer (GROUP, "cursor-offset"),
            use_crlf = metadata.get_boolean (GROUP, "use-crlf"),
            // Snapshots written before the BOM was restored on save have no key.
            has_bom = metadata.has_key (GROUP, "use-bom") && metadata.get_boolean (GROUP, "use-bom"),
            encoding_name = metadata.get_string (GROUP, "encoding")
        };
        if (metadata.has_key (GROUP, "original-uri")) {
            snapshot.original_uri = metadata.get_string (GROUP, "original-uri");
        }
        if (metadata.has_key (GROUP, "original-etag")) {
            snapshot.original_etag = metadata.get_string (GROUP, "original-etag");
        }
        return snapshot;
    }

    private static string metadata_for (RecoverySnapshot snapshot) {
        var metadata = new KeyFile ();
        metadata.set_string (GROUP, "display-name", snapshot.display_name);
        metadata.set_int64 (GROUP, "saved-at", snapshot.saved_at);
        metadata.set_integer (GROUP, "cursor-offset", snapshot.cursor_offset);
        metadata.set_boolean (GROUP, "use-crlf", snapshot.use_crlf);
        metadata.set_boolean (GROUP, "use-bom", snapshot.has_bom);
        metadata.set_string (GROUP, "encoding", snapshot.encoding_name);
        if (snapshot.original_uri != null) {
            metadata.set_string (GROUP, "original-uri", snapshot.original_uri);
        }
        if (snapshot.original_etag != null) {
            metadata.set_string (GROUP, "original-etag", snapshot.original_etag);
        }
        return metadata.to_data ();
    }

    private static uint8[] container_for (RecoverySnapshot snapshot) throws Error {
        string metadata = metadata_for (snapshot);
        var stream = new MemoryOutputStream.resizable ();
        var output = new DataOutputStream (stream);
        output.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);
        output.write (MAGIC.data);
        output.put_uint32 ((uint32) RecoverySnapshot.FORMAT_VERSION);
        output.put_uint32 ((uint32) metadata.data.length);
        output.write (metadata.data);
        output.write (snapshot.text.data);
        output.write (new uint8[] { 0 });
        output.close (null);
        return Bytes.unref_to_data (stream.steal_as_bytes ());
    }

    private bool original_has_changed (RecoverySnapshot snapshot, Cancellable? cancellable) {
        if (snapshot.original_uri == null || snapshot.original_etag == null) {
            return false;
        }
        try {
            FileInfo info = File.new_for_uri (snapshot.original_uri).query_info (
                                                                                 FileAttribute.ETAG_VALUE,
                                                                                 FileQueryInfoFlags.NONE,
                                                                                 cancellable
            );
            return info.get_etag () != snapshot.original_etag;
        } catch (Error error) {
            return true;
        }
    }

    private bool is_expired (RecoverySnapshot snapshot) {
        int64 now = new DateTime.now_utc ().to_unix ();
        return snapshot.saved_at <= 0 || now - snapshot.saved_at > MAX_AGE_SECONDS;
    }

    private void ensure_directory (File directory) throws Error {
        try {
            directory.make_directory_with_parents (null);
        } catch (IOError.EXISTS error) {
        }
    }

    private static FileType query_type (File file, Cancellable? cancellable) {
        try {
            FileInfo info = file.query_info (
                                             FileAttribute.STANDARD_TYPE,
                                             FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                             cancellable
            );
            return info.get_file_type ();
        } catch (Error error) {
            return FileType.UNKNOWN;
        }
    }

    private static bool is_directory (File file, Cancellable? cancellable) {
        return query_type (file, cancellable) == FileType.DIRECTORY;
    }

    private async void delete_entry (File entry, Cancellable? cancellable) throws Error {
        if (is_directory (entry, cancellable)) {
            yield delete_directory (entry, cancellable);
        } else {
            yield entry.delete_async (Priority.DEFAULT, cancellable);
        }
    }

    private async void delete_directory (File directory, Cancellable? cancellable) throws Error {
        string[] names = {};
        FileEnumerator enumerator = yield directory.enumerate_children_async (FileAttribute.STANDARD_NAME,
            FileQueryInfoFlags.NONE,
            Priority.DEFAULT,
            cancellable);

        FileInfo? info;
        while ((info = enumerator.next_file (cancellable)) != null) {
            names += info.get_name ();
        }
        yield enumerator.close_async (Priority.DEFAULT, cancellable);

        foreach (string name in names) {
            yield delete_entry (directory.get_child (name), cancellable);
        }
        yield directory.delete_async (Priority.DEFAULT, cancellable);
    }
}
