/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// One document as it was read from or written to a file: its contents plus the
// encoding facts the status bar, the recovery snapshots and the save path need.
// What was read is written back the same way, BOM and line endings included. The
// live, possibly modified contents stay in the editor buffer.
public class ValaPad.Document : Object {
    public File? file { get; set; }
    public string? etag { get; set; }
    public string text { get; set; default = ""; }
    public bool use_crlf { get; set; }
    public bool has_bom { get; set; }
    public string encoding { get; set; default = "UTF-8"; }

    public static Document untitled () {
        return new Document ();
    }

    // Reads file contents the way the editor shows them: the BOM is stripped,
    // CRLF is normalised to LF, and invalid UTF-8 is replaced.
    public static Document from_bytes (File? file, string? etag, uint8[] contents) {
        bool bom;
        bool crlf;
        bool repaired;
        string text = TextFileDecoder.decode (contents, out bom, out crlf, out repaired);

        return new Document () {
            file = file,
            etag = etag,
            text = text,
            use_crlf = crlf,
            has_bom = bom,
            encoding = encoding_label (bom, repaired)
        };
    }

    // The same document after it has been written to a file: the file identity
    // and the contents change, the encoding facts stay.
    public Document saved_as (File file, string? etag, string saved_text) {
        return new Document () {
            file = file,
            etag = etag,
            text = saved_text,
            use_crlf = use_crlf,
            has_bom = has_bom,
            encoding = encoding
        };
    }

    // The name shown in the title bar, the recovery snapshots and the prompts
    // that ask about unsaved changes.
    public string display_name () {
        File? open_file = file;
        if (open_file == null) {
            return _("Untitled");
        }
        return open_file.get_basename ();
    }

    // The contents as they go back to the file, as a string: a UTF-8 BOM when the
    // document was read with one, and CRLF when it was read with Windows line
    // endings, so mixed line endings become CRLF. Text is a parameter because the
    // buffer can hold edits newer than this document.
    public string to_file_text (string text) {
        string encoded = use_crlf ? text.replace ("\n", "\r\n") : text;
        if (!has_bom) {
            return encoded;
        }
        return "\uFEFF" + encoded;
    }

    // How the file was read, for the status bar and the recovery snapshots. The
    // label names both the BOM and the replaced bytes when the file had both.
    private static string encoding_label (bool has_bom, bool repaired) {
        if (repaired) {
            return has_bom
                ? _("UTF-8-BOM (invalid bytes replaced)")
                : _("UTF-8 (invalid bytes replaced)");
        }
        return has_bom ? "UTF-8-BOM" : "UTF-8";
    }
}
