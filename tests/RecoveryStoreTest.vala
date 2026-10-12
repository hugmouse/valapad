/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private async ValaPad.RecoverySnapshot[] load_all (ValaPad.RecoveryStore store) {
    ValaPad.RecoverySnapshot[] snapshots = {};
    try {
        snapshots = yield store.load_all ();
    } catch (Error error) {
        assert_not_reached ();
    }
    return snapshots;
}

private async void save (ValaPad.RecoveryStore store, ValaPad.RecoverySnapshot snapshot) {
    try {
        yield store.save (snapshot);
    } catch (Error error) {
        assert_not_reached ();
    }
}

private async void delete (ValaPad.RecoveryStore store, string id) {
    try {
        yield store.delete (id);
    } catch (Error error) {
        assert_not_reached ();
    }
}

private ValaPad.RecoverySnapshot snapshot_for (string id, string text) {
    return new ValaPad.RecoverySnapshot (id) {
               text = text,
               display_name = "notes.txt",
               saved_at = new DateTime.now_utc ().to_unix (),
               cursor_offset = 3,
               use_crlf = true,
               has_bom = true,
               encoding_name = "UTF-8-BOM"
    };
}

private FileType entry_type (string path) {
    try {
        return File.new_for_path (path).query_info (
                                                    FileAttribute.STANDARD_TYPE,
                                                    FileQueryInfoFlags.NONE,
                                                    null
        ).get_file_type ();
    } catch (Error error) {
        return FileType.UNKNOWN;
    }
}

private string entry_path (string temp_dir, string name) {
    return Path.build_filename (temp_dir, name);
}

private void seed_legacy_snapshot (string directory, string text, int64 saved_at) throws Error {
    try {
        File.new_for_path (directory).make_directory_with_parents (null);
    } catch (IOError.EXISTS error) {
    }
    FileUtils.set_contents (Path.build_filename (directory, "content.txt"), text);

    var metadata = new KeyFile ();
    metadata.set_integer ("Recovery", "version", 1);
    metadata.set_string ("Recovery", "display-name", "legacy.txt");
    metadata.set_int64 ("Recovery", "saved-at", saved_at);
    metadata.set_integer ("Recovery", "cursor-offset", 0);
    metadata.set_boolean ("Recovery", "use-crlf", false);
    metadata.set_string ("Recovery", "encoding", "UTF-8");
    FileUtils.set_contents (Path.build_filename (directory, "metadata.ini"), metadata.to_data ());
}

private int64 now () {
    return new DateTime.now_utc ().to_unix ();
}

private async void run_round_trip (string temp_dir) {
    var store = new ValaPad.RecoveryStore (temp_dir);
    yield save (store, snapshot_for ("round-trip", "hello\nworld"));

    // The snapshot is a single file, not a directory.
    assert (entry_type (entry_path (temp_dir, "round-trip")) == FileType.REGULAR);

    ValaPad.RecoverySnapshot[] snapshots = yield load_all (store);

    assert (snapshots.length == 1);
    assert (snapshots[0].id == "round-trip");
    assert (snapshots[0].text == "hello\nworld");
    assert (snapshots[0].display_name == "notes.txt");
    assert (snapshots[0].cursor_offset == 3);
    assert (snapshots[0].use_crlf);
    assert (snapshots[0].has_bom);
    assert (snapshots[0].encoding_name == "UTF-8-BOM");
}

private void test_round_trip () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_round_trip.begin (temp_dir, (obj, res) => {
        run_round_trip.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private async void run_legacy_migration (string temp_dir) {
    try {
        seed_legacy_snapshot (entry_path (temp_dir, "legacy"), "legacy text", now ());
    } catch (Error error) {
        assert_not_reached ();
    }

    var store = new ValaPad.RecoveryStore (temp_dir);
    ValaPad.RecoverySnapshot[] snapshots = yield load_all (store);

    assert (snapshots.length == 1);
    assert (snapshots[0].id == "legacy");
    assert (snapshots[0].text == "legacy text");
    assert (snapshots[0].display_name == "legacy.txt");

    // The directory is rewritten in place as a single file.
    assert (entry_type (entry_path (temp_dir, "legacy")) == FileType.REGULAR);
    assert (!File.new_for_path (entry_path (temp_dir, "legacy.tmp")).query_exists ());

    ValaPad.RecoverySnapshot[] again = yield load_all (store);

    assert (again.length == 1);
    assert (again[0].text == "legacy text");
}

private void test_legacy_migration () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_legacy_migration.begin (temp_dir, (obj, res) => {
        run_legacy_migration.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private async void run_save_replaces_legacy_directory (string temp_dir) {
    try {
        seed_legacy_snapshot (entry_path (temp_dir, "same-id"), "legacy text", now ());
    } catch (Error error) {
        assert_not_reached ();
    }

    var store = new ValaPad.RecoveryStore (temp_dir);
    yield save (store, snapshot_for ("same-id", "new text"));

    assert (entry_type (entry_path (temp_dir, "same-id")) == FileType.REGULAR);

    ValaPad.RecoverySnapshot[] snapshots = yield load_all (store);

    assert (snapshots.length == 1);
    assert (snapshots[0].text == "new text");
}

private void test_save_replaces_legacy_directory () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_save_replaces_legacy_directory.begin (temp_dir, (obj, res) => {
        run_save_replaces_legacy_directory.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private async void run_delete_removes_legacy_directory (string temp_dir) {
    try {
        seed_legacy_snapshot (entry_path (temp_dir, "legacy"), "legacy text", now ());
    } catch (Error error) {
        assert_not_reached ();
    }

    var store = new ValaPad.RecoveryStore (temp_dir);
    yield delete (store, "legacy");
    assert (!File.new_for_path (entry_path (temp_dir, "legacy")).query_exists ());
    assert ((yield load_all (store)).length == 0);
}

private void test_delete_removes_legacy_directory () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_delete_removes_legacy_directory.begin (temp_dir, (obj, res) => {
        run_delete_removes_legacy_directory.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private async void run_expired_legacy_is_removed (string temp_dir) {
    try {
        seed_legacy_snapshot (entry_path (temp_dir, "expired"), "expired text", 1);
    } catch (Error error) {
        assert_not_reached ();
    }

    var store = new ValaPad.RecoveryStore (temp_dir);
    assert ((yield load_all (store)).length == 0);
    assert (!File.new_for_path (entry_path (temp_dir, "expired")).query_exists ());
}

private void test_expired_legacy_is_removed () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_expired_legacy_is_removed.begin (temp_dir, (obj, res) => {
        run_expired_legacy_is_removed.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private async void run_unreadable_entry_is_kept (string temp_dir) {
    var store = new ValaPad.RecoveryStore (temp_dir);
    yield save (store, snapshot_for ("unreadable", "unsaved edit"));

    string path = entry_path (temp_dir, "unreadable");
    FileUtils.chmod (path, 0);

    try {
        string contents;
        FileUtils.get_contents (path, out contents);
        Test.skip ("file permissions are not enforced for this user");
        return;
    } catch (FileError error) {
    }

    assert ((yield load_all (store)).length == 0);
    assert (File.new_for_path (path).query_exists ());

    FileUtils.chmod (path, 0600);
    ValaPad.RecoverySnapshot[] snapshots = yield load_all (store);

    assert (snapshots.length == 1);
    assert (snapshots[0].text == "unsaved edit");
}

private void test_unreadable_entry_is_kept () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-recovery-store-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_unreadable_entry_is_kept.begin (temp_dir, (obj, res) => {
        run_unreadable_entry_is_kept.end (res);
        delete_recursively (File.new_for_path (temp_dir));
        loop.quit ();
    });
    loop.run ();
}

private void delete_recursively (File file) {
    try {
        FileInfo info = file.query_info (
                                         FileAttribute.STANDARD_TYPE,
                                         FileQueryInfoFlags.NOFOLLOW_SYMLINKS
        );
        if (info.get_file_type () == FileType.DIRECTORY) {
            FileEnumerator enumerator = file.enumerate_children (
                                                                 FileAttribute.STANDARD_NAME,
                                                                 FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? child;
            while ((child = enumerator.next_file ()) != null) {
                delete_recursively (file.get_child (child.get_name ()));
            }
        }
        file.delete ();
    } catch (Error error) {
    }
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/recovery-store/round-trip", test_round_trip);
    Test.add_func ("/recovery-store/legacy-migration", test_legacy_migration);
    Test.add_func ("/recovery-store/save-replaces-legacy-directory", test_save_replaces_legacy_directory);
    Test.add_func ("/recovery-store/delete-removes-legacy-directory", test_delete_removes_legacy_directory);
    Test.add_func ("/recovery-store/expired-legacy-is-removed", test_expired_legacy_is_removed);
    Test.add_func ("/recovery-store/unreadable-entry-is-kept", test_unreadable_entry_is_kept);
    return Test.run ();
}
