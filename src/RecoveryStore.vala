/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// rename(2) cannot atomically replace a non-empty directory, so
// let's use linux 3.15+ renameat2 API which suppose to at least
// try to make it atomic.
//
// Caveats: NFS, WEKA, CephFS, ZFS and some FUSE-based fss
// don't support renameat2 and will fail with ENOSYS.
// So I just hope nobody is using any of these.
#if LINUX
[CCode (cname = "renameat2", cheader_filename = "stdio.h")]
extern int renameat2 (int old_dirfd, string old_path, int new_dirfd, string new_path, uint flags);

#elif MACOS
[CCode (cname = "renameatx_np", cheader_filename = "stdio.h")]
extern int renameatx_np (int old_dirfd, string old_path, int new_dirfd, string new_path, uint flags);

// #elif WINDOWS
// [CCode (cname = "MoveFileExW", cheader_filename = "windows.h")]
// extern bool move_file_ex (string lp_existing_file_name, string lp_new_file_name, uint32 dw_flags);
#endif

// Persists one private recovery directory per document in the user's state
// directory. Text and metadata are loaded at startup.
public class ValaPad.RecoveryStore : Object {
    private const string METADATA_FILE = "metadata.ini";
    private const string CONTENT_FILE = "content.txt";
    private const string GROUP = "Recovery";
    private const int64 MAX_AGE_SECONDS = 60 * 60 * 24 * 30;
    private const string STAGING_SUFFIX = ".tmp";
#if LINUX
    private const int AT_FDCWD = -100;
    private const uint RENAME_EXCHANGE = 2;
#elif MACOS
    private const int AT_FDCWD = -2;
    private const uint RENAME_SWAP = 2;
#endif

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
        File directory = root.get_child (snapshot.id);
        File staging = root.get_child (snapshot.id + STAGING_SUFFIX);

        // If save was interrupted before the previous snapshot was published,
        // the staging directory may still exist.
        // Delete it to ensure a clean slate.
        if (staging.query_exists (cancellable)) {
            yield delete_directory (staging, cancellable);
        }
        ensure_directory (staging);

        yield write_child_file (staging, CONTENT_FILE, snapshot.text.data, cancellable);

        var metadata = new KeyFile ();
        metadata.set_integer (GROUP, "version", RecoverySnapshot.FORMAT_VERSION);
        metadata.set_string (GROUP, "display-name", snapshot.display_name);
        metadata.set_int64 (GROUP, "saved-at", snapshot.saved_at);
        metadata.set_integer (GROUP, "cursor-offset", snapshot.cursor_offset);
        metadata.set_boolean (GROUP, "use-crlf", snapshot.use_crlf);
        metadata.set_string (GROUP, "encoding", snapshot.encoding_name);
        if (snapshot.original_uri != null) {
            metadata.set_string (GROUP, "original-uri", snapshot.original_uri);
        }
        if (snapshot.original_etag != null) {
            metadata.set_string (GROUP, "original-etag", snapshot.original_etag);
        }

        string metadata_text = metadata.to_data ();
        uint8[] metadata_content = metadata_text.data;
        yield write_child_file (staging, METADATA_FILE, metadata_content, cancellable);
        debug ("Recovery snapshot staged: id=%s", snapshot.id);

        // In theory this should actually be atomic and safe. In practice, I can only hope.
        if (directory.query_exists (cancellable)) {
            debug ("Exchanging staged recovery snapshot with current snapshot: id=%s", snapshot.id);
#if LINUX
            if (renameat2 (AT_FDCWD, staging.get_path (), AT_FDCWD, directory.get_path (), RENAME_EXCHANGE) != 0) {
#elif MACOS
            if (renameatx_np (AT_FDCWD, staging.get_path (), AT_FDCWD, directory.get_path (), RENAME_SWAP) != 0) {
#endif
                throw new FileError.FAILED ("atomic snapshot exchange failed. Check if your filesystem supports renameat2/renameatx_np syscalls");
            }
            // The staging directory now holds the superseded snapshot.
            yield delete_directory (staging, cancellable);
        } else {
            debug ("Publishing first recovery snapshot: id=%s", snapshot.id);
            staging.set_display_name (snapshot.id);
        }
        debug ("Recovery snapshot published: id=%s", snapshot.id);
    }

    private async void write_child_file (File directory,
                                         string name,
                                         uint8[] contents,
                                         Cancellable? cancellable) throws Error {
        string? ignored_etag;
        yield directory.get_child (name).replace_contents_async (
                                                                 contents,
                                                                 null,
                                                                 false,
                                                                 FileCreateFlags.REPLACE_DESTINATION
                                                                 | FileCreateFlags.PRIVATE,
                                                                 cancellable,
                                                                 out ignored_etag
        );
    }

    public async RecoverySnapshot[] load_all (Cancellable? cancellable = null) throws Error {
        RecoverySnapshot[] snapshots = {};
        debug ("Scanning recovery store");
        if (!root.query_exists (cancellable)) {
            debug ("Recovery store does not exist yet");
            return snapshots;
        }

        FileEnumerator enumerator = yield root.enumerate_children_async (FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
            FileQueryInfoFlags.NONE,
            Priority.DEFAULT,
            cancellable);

        FileInfo? info;
        while ((info = enumerator.next_file (cancellable)) != null) {
            if (info.get_file_type () != FileType.DIRECTORY) {
                continue;
            }

            File directory = root.get_child (info.get_name ());

            // A staging directory is leftover from an interrupted save before publication.
            // It is stale and should be removed.
            if (info.get_name ().has_suffix (STAGING_SUFFIX)) {
                debug ("Removing stale recovery staging directory: name=%s", info.get_name ());
                yield delete_directory (directory, cancellable);

                continue;
            }

            try {
                // Scanning also removes entries that cannot be safely offered for recovery.
                RecoverySnapshot snapshot = yield load_one (directory, info.get_name (), cancellable);

                if (is_expired (snapshot)) {
                    debug ("Removing expired recovery snapshot: id=%s", snapshot.id);
                    yield delete_directory (directory, cancellable);
                } else {
                    snapshot.original_changed = original_has_changed (snapshot, cancellable);
                    debug (
                           "Recovery snapshot found: id=%s chars=%d original-changed=%s",
                           snapshot.id,
                           (int) snapshot.text.char_count (),
                           snapshot.original_changed.to_string ()
                    );
                    snapshots += snapshot;
                }
            } catch (Error error) {
                debug ("Removing invalid recovery entry: id=%s error=%s", info.get_name (), error.message);
                yield delete_directory (directory, cancellable);
            }
        }

        CompareDataFunc<RecoverySnapshot> by_newest_first = (a, b) => (int) (b.saved_at - a.saved_at);
        GLib.qsort_with_data (snapshots, sizeof (RecoverySnapshot), by_newest_first);
        debug ("Recovery scan completed: count=%d", snapshots.length);
        return snapshots;
    }

    public async void delete (string id, Cancellable? cancellable = null) throws Error {
        File directory = root.get_child (id);
        if (directory.query_exists (cancellable)) {
            yield delete_directory (directory, cancellable);

            debug ("Recovery snapshot deleted: id=%s", id);
        } else {
            debug ("Recovery snapshot already absent: id=%s", id);
        }
    }

    private async RecoverySnapshot load_one (File directory, string id, Cancellable? cancellable) throws Error {
        uint8[] metadata_bytes;
        string? ignored_etag;
        yield directory.get_child (METADATA_FILE).load_contents_async (
                                                                       cancellable,
                                                                       out metadata_bytes,
                                                                       out ignored_etag
        );

        var metadata = new KeyFile ();
        metadata.load_from_data ((string) metadata_bytes, metadata_bytes.length, KeyFileFlags.NONE);
        if (metadata.get_integer (GROUP, "version") != RecoverySnapshot.FORMAT_VERSION) {
            throw new IOError.INVALID_DATA ("Unsupported recovery format");
        }

        uint8[] content;
        yield directory.get_child (CONTENT_FILE).load_contents_async (
                                                                      cancellable,
                                                                      out content,
                                                                      out ignored_etag
        );

        string text = (string) content;
        if (!text.validate ()) {
            throw new IOError.INVALID_DATA ("Recovery content is not UTF-8");
        }

        var snapshot = new RecoverySnapshot (id) {
            text = text,
            display_name = metadata.get_string (GROUP, "display-name"),
            saved_at = metadata.get_int64 (GROUP, "saved-at"),
            cursor_offset = metadata.get_integer (GROUP, "cursor-offset"),
            use_crlf = metadata.get_boolean (GROUP, "use-crlf"),
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

    private async void delete_directory (File directory, Cancellable? cancellable) throws Error {
        string[] child_names = { CONTENT_FILE, METADATA_FILE };
        foreach (string name in child_names) {
            File child = directory.get_child (name);
            if (child.query_exists (cancellable)) {
                yield child.delete_async (Priority.DEFAULT, cancellable);
            }
        }
        yield directory.delete_async (Priority.DEFAULT, cancellable);
    }
}
