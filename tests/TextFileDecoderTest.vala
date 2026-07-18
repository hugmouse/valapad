/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_plain_text () {
    uint8[] contents = "first\r\nsecond".data;
    bool has_bom;
    bool use_crlf;
    bool repaired;

    string text = ValaPad.TextFileDecoder.decode (
        contents,
        out has_bom,
        out use_crlf,
        out repaired
    );

    assert (text == "first\nsecond");
    assert (!has_bom);
    assert (use_crlf);
    assert (!repaired);
}

private void test_utf8_bom () {
    uint8[] contents = { 0xef, 0xbb, 0xbf, 'h', 'i' };
    bool has_bom;
    bool use_crlf;
    bool repaired;

    string text = ValaPad.TextFileDecoder.decode (
        contents,
        out has_bom,
        out use_crlf,
        out repaired
    );

    assert (text == "hi");
    assert (has_bom);
    assert (!use_crlf);
    assert (!repaired);
}

private void test_binary_data () {
    uint8[] contents = { 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0xff };
    bool has_bom;
    bool use_crlf;
    bool repaired;

    string text = ValaPad.TextFileDecoder.decode (
        contents,
        out has_bom,
        out use_crlf,
        out repaired
    );

    assert (text.validate ());
    assert ("PNG" in text);
    assert (!has_bom);
    assert (use_crlf);
    assert (repaired);
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/text-file-decoder/plain-text", test_plain_text);
    Test.add_func ("/text-file-decoder/utf8-bom", test_utf8_bom);
    Test.add_func ("/text-file-decoder/binary-data", test_binary_data);
    return Test.run ();
}
