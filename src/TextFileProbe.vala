/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Checks that file is not sus.
// Files that are not valid UTF-8 or contain binary markers
// require user confirmation.
//
// See Dialogs/RecoveryDialog.vala
public class ValaPad.TextFileProbe : Object {
    public const int SAMPLE_BYTES = 64 * 1024;

    public static bool is_probably_text (uint8[] sample) {
        if (sample.length == 0) {
            return true;
        }

        int sus = 0;
        foreach (uint8 byte in sample) {
            if (byte == 0) {
                return false;
            }
            if (byte < 0x20 && byte != '\t' && byte != '\n' && byte != '\r' && byte != '\f') {
                sus++;
            }
        }

        string candidate = (string) sample;
        if (!candidate.validate_len (sample.length)) {
            return false;
        }

        return sus * 100 <= sample.length;
    }
}
