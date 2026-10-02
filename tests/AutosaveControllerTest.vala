/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private async void wait_for_saved (ValaPad.AutosaveController controller) {
    SourceFunc callback = wait_for_saved.callback;
    ulong handler = controller.saved.connect (() => callback ());
    yield;
    controller.disconnect (handler);
}

private async ValaPad.RecoverySnapshot[] load_all (ValaPad.RecoveryStore store) {
    ValaPad.RecoverySnapshot[] snapshots = {};
    try {
        snapshots = yield store.load_all ();
    } catch (Error error) {
        assert_not_reached ();
    }
    return snapshots;
}

private async void run_clear_rotates_recovery_id (string temp_dir) {
    var store = new ValaPad.RecoveryStore (temp_dir);
    var buffer = new Gtk.TextBuffer (null);
    var controller = new ValaPad.AutosaveController (buffer, store);

    buffer.text = "first";
    buffer.set_modified (true);
    assert (yield controller.flush ());
    ValaPad.RecoverySnapshot[] first = yield load_all (store);
    assert (first.length == 1);
    assert (first[0].text == "first");

    yield controller.clear ();
    ValaPad.RecoverySnapshot[] cleared = yield load_all (store);
    assert (cleared.length == 0);

    buffer.text = "second";
    buffer.set_modified (true);
    controller.schedule_now ();
    yield wait_for_saved (controller);
    ValaPad.RecoverySnapshot[] second = yield load_all (store);
    assert (second.length == 1);
    assert (second[0].text == "second");
    assert (second[0].id != first[0].id);
}

private void test_clear_rotates_recovery_id () {
    string temp_dir;
    try {
        temp_dir = DirUtils.make_tmp ("valapad-autosave-test-XXXXXX");
    } catch (FileError error) {
        assert_not_reached ();
    }

    MainLoop loop = new MainLoop ();
    run_clear_rotates_recovery_id.begin (temp_dir, (obj, res) => {
        run_clear_rotates_recovery_id.end (res);
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
            var enumerator = file.enumerate_children (
                FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? child_info;
            while ((child_info = enumerator.next_file ()) != null) {
                delete_recursively (file.get_child (child_info.get_name ()));
            }
        }
        file.delete ();
    } catch (Error error) {
    }
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/autosave-controller/clear-rotates-recovery-id", test_clear_rotates_recovery_id);
    return Test.run ();
}
