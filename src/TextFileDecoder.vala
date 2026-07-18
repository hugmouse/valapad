/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.TextFileDecoder : Object {
    public static string decode (
        uint8[] contents,
        out bool has_bom,
        out bool use_crlf,
        out bool repaired
    ) {
        has_bom = contents.length >= 3 &&
            contents[0] == 0xef && contents[1] == 0xbb && contents[2] == 0xbf;

        string raw_text = (string) contents;
        repaired = !raw_text.validate_len (contents.length);
        string text = repaired ? raw_text.make_valid (contents.length) : raw_text;

        if (has_bom) {
            text = text.substring (3);
        }

        use_crlf = "\r\n" in text;
        if (use_crlf) {
            text = text.replace ("\r\n", "\n");
        }

        return text;
    }
}
