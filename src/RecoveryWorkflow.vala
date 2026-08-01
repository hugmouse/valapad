/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public enum ValaPad.RecoveryDocumentOutcome {
    SAVE_SUCCEEDED,
    SAVE_FAILED,
    SAVE_AS_CANCELLED,
    CLOSE_CANCELLED,
    DONT_SAVE
}

public class ValaPad.RecoveryWorkflow : Object {
    public static bool should_delete_snapshot (RecoveryDocumentOutcome outcome) {
        return outcome == RecoveryDocumentOutcome.SAVE_SUCCEEDED
            || outcome == RecoveryDocumentOutcome.DONT_SAVE;
    }

    public static RecoverySnapshot[] selected_snapshots (
        RecoverySnapshot[] snapshots,
        bool[] selected
    ) {
        RecoverySnapshot[] result = {};
        int count = int.min (snapshots.length, selected.length);
        for (int i = 0; i < count; i++) {
            if (selected[i]) {
                result += snapshots[i];
            }
        }
        return result;
    }

    public static string dialog_details (
        RecoverySnapshot snapshot,
        string date,
        string changed_format
    ) {
        return snapshot.original_changed ? changed_format.printf (date) : date;
    }

    public static string? conflict_warning (
        RecoverySnapshot snapshot,
        string warning
    ) {
        return snapshot.original_changed ? warning : null;
    }
}
