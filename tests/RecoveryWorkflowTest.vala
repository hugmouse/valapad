/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_snapshot_removal () {
    assert (ValaPad.RecoveryWorkflow.should_delete_snapshot (ValaPad.RecoveryDocumentOutcome.SAVE_SUCCEEDED));
    assert (ValaPad.RecoveryWorkflow.should_delete_snapshot (ValaPad.RecoveryDocumentOutcome.DONT_SAVE));
    assert (!ValaPad.RecoveryWorkflow.should_delete_snapshot (ValaPad.RecoveryDocumentOutcome.SAVE_FAILED));
    assert (!ValaPad.RecoveryWorkflow.should_delete_snapshot (ValaPad.RecoveryDocumentOutcome.CLOSE_CANCELLED));
}

private void test_selected_snapshots () {
    ValaPad.RecoverySnapshot[] snapshots = {
        new ValaPad.RecoverySnapshot ("a"),
        new ValaPad.RecoverySnapshot ("b"),
        new ValaPad.RecoverySnapshot ("c")
    };

    var some = ValaPad.RecoveryWorkflow.selected_snapshots (snapshots, { true, false, true });
    assert (some.length == 2);
    assert (some[0].id == "a");
    assert (some[1].id == "c");

    var none = ValaPad.RecoveryWorkflow.selected_snapshots (snapshots, { false, false, false });
    assert (none.length == 0);

    var all = ValaPad.RecoveryWorkflow.selected_snapshots (snapshots, { true, true, true });
    assert (all.length == 3);
}

private void test_selection_mismatch () {
    ValaPad.RecoverySnapshot[] snapshots = {
        new ValaPad.RecoverySnapshot ("a"),
        new ValaPad.RecoverySnapshot ("b")
    };

    // Only paired entries count
    var shorter_selection = ValaPad.RecoveryWorkflow.selected_snapshots (snapshots, { true });
    assert (shorter_selection.length == 1);
    assert (shorter_selection[0].id == "a");

    var shorter_snapshots = ValaPad.RecoveryWorkflow.selected_snapshots (
        { new ValaPad.RecoverySnapshot ("a") },
        { true, true }
    );
    assert (shorter_snapshots.length == 1);
}

private void test_details_and_conflict_warning () {
    var unchanged = new ValaPad.RecoverySnapshot ("a");
    var changed = new ValaPad.RecoverySnapshot ("b") {
        original_changed = true
    };

    const string CHANGED_FORMAT = "%s — original file changed";
    assert (ValaPad.RecoveryWorkflow.dialog_details (unchanged, "yesterday", CHANGED_FORMAT) == "yesterday");
    assert (
        ValaPad.RecoveryWorkflow.dialog_details (changed, "yesterday", CHANGED_FORMAT) ==
        "yesterday — original file changed"
    );

    assert (ValaPad.RecoveryWorkflow.conflict_warning (unchanged, "changed on disk") == null);
    assert (ValaPad.RecoveryWorkflow.conflict_warning (changed, "changed on disk") == "changed on disk");
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/recovery-workflow/snapshot-removal", test_snapshot_removal);
    Test.add_func ("/recovery-workflow/selected-snapshots", test_selected_snapshots);
    Test.add_func ("/recovery-workflow/selection-mismatch", test_selection_mismatch);
    Test.add_func ("/recovery-workflow/details-and-conflict-warning", test_details_and_conflict_warning);
    return Test.run ();
}
