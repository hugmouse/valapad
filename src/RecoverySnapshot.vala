/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Complete editor state saved for crash recovery. The ID remains the same while
// one document is open so newer snapshots replace its previous recovery copy.
public class ValaPad.RecoverySnapshot : Object {
    // Version of the snapshot container written by RecoveryStore.
    // Version 1 kept the metadata and the content as two files in a directory.
    // See RECOVERY.md for details.
    public const int FORMAT_VERSION = 2;

    public string id { get; set; }
    public string text { get; set; default = ""; }
    public string display_name { get; set; default = "Untitled"; }
    public string? original_uri { get; set; }
    public string? original_etag { get; set; }
    public int64 saved_at { get; set; }
    public int cursor_offset { get; set; }
    public bool use_crlf { get; set; }
    public bool has_bom { get; set; }
    public string encoding_name { get; set; default = "UTF-8"; }
    public bool original_changed { get; set; default = false; }

    public RecoverySnapshot (string id) {
        Object (id: id);
    }
}
