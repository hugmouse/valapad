/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_text_samples () {
    assert (ValaPad.TextFileProbe.is_probably_text ({}));
    assert (ValaPad.TextFileProbe.is_probably_text ("Héllö\nwórld\t!".data));
    assert (ValaPad.TextFileProbe.is_probably_text ("Ура кириллица в моём тесте!\r\n".data));
}

private void test_png_header () {
    uint8[] png = {
        0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 'I', 'H', 'D', 'R'
    };
    assert (!ValaPad.TextFileProbe.is_probably_text (png));
}

private void test_binary_markers () {
    uint8[] nul_byte = { 'a', 'b', 0x00, 'c' };
    uint8[] invalid_utf8 = { 0xff, 0xfe, 0xfd };
    uint8[] controls = { 0x01, 0x02, 0x03, 0x04, 'A' };
    assert (!ValaPad.TextFileProbe.is_probably_text (nul_byte));
    assert (!ValaPad.TextFileProbe.is_probably_text (invalid_utf8));
    assert (!ValaPad.TextFileProbe.is_probably_text (controls));
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/text-file-probe/text", test_text_samples);
    Test.add_func ("/text-file-probe/png", test_png_header);
    Test.add_func ("/text-file-probe/binary-markers", test_binary_markers);
    return Test.run ();
}
