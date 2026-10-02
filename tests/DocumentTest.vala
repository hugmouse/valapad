/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_untitled () {
    var document = ValaPad.Document.untitled ();

    assert (document.file == null);
    assert (document.etag == null);
    assert (document.text == "");
    assert (!document.use_crlf);
    assert (!document.has_bom);
    assert (document.encoding == "UTF-8");
    assert (document.display_name () == "Untitled");
    assert (document.to_file_text (document.text) == "");
}

private void test_plain_file () {
    var file = File.new_for_path ("/tmp/valapad-notes.txt");
    var document = ValaPad.Document.from_bytes (file, "etag-1", "first\nsecond".data);

    assert (document.file == file);
    assert (document.etag == "etag-1");
    assert (document.text == "first\nsecond");
    assert (!document.use_crlf);
    assert (!document.has_bom);
    assert (document.encoding == "UTF-8");
    assert (document.display_name () == "valapad-notes.txt");
    assert (document.to_file_text (document.text) == "first\nsecond");
}

private void test_crlf_file () {
    var document = ValaPad.Document.from_bytes (null, null, "first\r\nsecond".data);

    assert (document.text == "first\nsecond");
    assert (document.use_crlf);
    assert (!document.has_bom);
    assert (document.encoding == "UTF-8");
    assert (document.to_file_text (document.text) == "first\r\nsecond");
}

private void test_mixed_line_endings () {
    var document = ValaPad.Document.from_bytes (null, null, "first\r\nsecond\nthird".data);

    assert (document.use_crlf);
    assert (document.text == "first\nsecond\nthird");
    // One CRLF in the file marks the document as CRLF, so every line ending goes
    // back to the file as CRLF.
    assert (document.to_file_text (document.text) == "first\r\nsecond\r\nthird");
}

private void test_utf8_bom_file () {
    uint8[] contents = { 0xef, 0xbb, 0xbf, 'h', 'i' };

    var document = ValaPad.Document.from_bytes (null, null, contents);

    assert (document.text == "hi");
    assert (!document.use_crlf);
    assert (document.has_bom);
    assert (document.encoding == "UTF-8-BOM");
    assert (document.to_file_text (document.text) == "\uFEFFhi");
}

private void test_repaired_file () {
    uint8[] contents = { 'h', 'i', 0xff };

    var document = ValaPad.Document.from_bytes (null, null, contents);

    assert (document.text.validate ());
    assert (!document.has_bom);
    assert (document.encoding == "UTF-8 (invalid bytes replaced)");
    assert (document.to_file_text (document.text) == "hi\uFFFD");
}

private void test_bom_repaired_file () {
    uint8[] contents = { 0xef, 0xbb, 0xbf, 0x80 };

    var document = ValaPad.Document.from_bytes (null, null, contents);

    assert (document.has_bom);
    assert (document.encoding == "UTF-8-BOM (invalid bytes replaced)");
    assert (document.to_file_text (document.text) == "\uFEFF\uFFFD");
}

private void test_saved_as () {
    uint8[] contents = { 0xef, 0xbb, 0xbf, 'a', '\r', '\n', 'b' };
    var document = ValaPad.Document.from_bytes (null, null, contents);
    var saved = document.saved_as (
        File.new_for_path ("/tmp/valapad-saved.txt"),
        "etag-2",
        "first\nsecond\nthird"
    );

    assert (saved.etag == "etag-2");
    assert (saved.text == "first\nsecond\nthird");
    assert (saved.use_crlf);
    assert (saved.has_bom);
    assert (saved.encoding == "UTF-8-BOM");
    assert (saved.display_name () == "valapad-saved.txt");
    assert (saved.to_file_text (saved.text) == "\uFEFFfirst\r\nsecond\r\nthird");

    assert (document.file == null);
    assert (document.etag == null);
    assert (document.text == "a\nb");
    assert (document.display_name () == "Untitled");
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/document/untitled", test_untitled);
    Test.add_func ("/document/plain-file", test_plain_file);
    Test.add_func ("/document/crlf-file", test_crlf_file);
    Test.add_func ("/document/mixed-line-endings", test_mixed_line_endings);
    Test.add_func ("/document/utf8-bom-file", test_utf8_bom_file);
    Test.add_func ("/document/repaired-file", test_repaired_file);
    Test.add_func ("/document/bom-repaired-file", test_bom_repaired_file);
    Test.add_func ("/document/saved-as", test_saved_as);
    return Test.run ();
}
