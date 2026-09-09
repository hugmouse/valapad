/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private Pango.FontDescription monospace_font (double px) {
    var font = Pango.FontDescription.from_string ("monospace");
    font.set_absolute_size (px * Pango.SCALE);
    return font;
}

private Pango.FontDescription monospace_point_font (double pt) {
    var font = Pango.FontDescription.from_string ("monospace");
    font.set_size ((int) (pt * Pango.SCALE));
    return font;
}

private void test_line_height_positive () {
    double height = ValaPad.PrintLayout.line_height (monospace_font (12.0));
    assert (height > 0.0);
}

private void test_line_height_scales_with_font () {
    double small = ValaPad.PrintLayout.line_height (monospace_font (10.0));
    double big = ValaPad.PrintLayout.line_height (monospace_font (20.0));
    assert (big > small);
}

private void test_line_height_point_size () {
    // FontDialog stores point sizes via set_size (); the print path must
    // handle them, not just absolute px sizes.
    double height = ValaPad.PrintLayout.line_height (monospace_point_font (12.0));
    assert (height > 10.0);
    assert (height < 24.0);
    double bigger = ValaPad.PrintLayout.line_height (monospace_point_font (24.0));
    assert (bigger > height);
}

private void test_lines_per_page () {
    var font = monospace_font (10.0);
    double height = ValaPad.PrintLayout.line_height (font);
    int per_page = ValaPad.PrintLayout.lines_per_page (font, 600.0);
    int expected = int.max ((int) ((600.0 - 2.0 * ValaPad.PrintLayout.margin ()) / height), 1);
    assert (per_page == expected);
    assert (per_page >= 1);
}

private void test_larger_font_means_fewer_lines () {
    int small = ValaPad.PrintLayout.lines_per_page (monospace_font (10.0), 600.0);
    int big = ValaPad.PrintLayout.lines_per_page (monospace_font (20.0), 600.0);
    assert (big < small);
}

private void test_minimum_one_line () {
    assert (ValaPad.PrintLayout.lines_per_page (monospace_font (12.0), 10.0) == 1);
    assert (ValaPad.PrintLayout.lines_per_page (monospace_font (12.0), 0.0) == 1);
}

private void test_unit_conversions () {
    assert (ValaPad.PrintLayout.margin () == 36.0);
    assert (ValaPad.PrintLayout.margin_px (72.0) == 36.0);
    assert (ValaPad.PrintLayout.margin_px (96.0) == 48.0);
    double pt = ValaPad.PrintLayout.pixels_to_points (96.0, 96.0);
    assert (pt == 72.0);
    double px = ValaPad.PrintLayout.points_to_pixels (72.0, 96.0);
    assert (px == 96.0);
    double roundtrip = ValaPad.PrintLayout.pixels_to_points (
        ValaPad.PrintLayout.points_to_pixels (36.0, 300.0),
        300.0
    );
    assert (roundtrip > 35.99 && roundtrip < 36.01);
}

private void test_paginate_empty () {
    var starts = ValaPad.PrintLayout.paginate_by_heights ({}, 100);
    assert (starts.length == 1);
    assert (starts[0] == 0);
}

private void test_paginate_single_page () {
    var starts = ValaPad.PrintLayout.paginate_by_heights ({ 10, 10, 10 }, 30);
    assert (starts.length == 1);
    assert (starts[0] == 0);
}

private void test_paginate_overflow () {
    var starts = ValaPad.PrintLayout.paginate_by_heights ({ 10, 10, 10 }, 25);
    assert (starts.length == 2);
    assert (starts[0] == 0);
    assert (starts[1] == 2);
}

private void test_paginate_oversized_line () {
    var single = ValaPad.PrintLayout.paginate_by_heights ({ 100 }, 30);
    assert (single.length == 1);
    assert (single[0] == 0);

    var mixed = ValaPad.PrintLayout.paginate_by_heights ({ 10, 100, 10 }, 30);
    assert (mixed.length == 3);
    assert (mixed[0] == 0);
    assert (mixed[1] == 1);
    assert (mixed[2] == 2);
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/print-layout/line-height-positive", test_line_height_positive);
    Test.add_func ("/print-layout/line-height-scales", test_line_height_scales_with_font);
    Test.add_func ("/print-layout/line-height-point-size", test_line_height_point_size);
    Test.add_func ("/print-layout/lines-per-page", test_lines_per_page);
    Test.add_func ("/print-layout/larger-font-fewer-lines", test_larger_font_means_fewer_lines);
    Test.add_func ("/print-layout/minimum-one-line", test_minimum_one_line);
    Test.add_func ("/print-layout/unit-conversions", test_unit_conversions);
    Test.add_func ("/print-layout/paginate-empty", test_paginate_empty);
    Test.add_func ("/print-layout/paginate-single-page", test_paginate_single_page);
    Test.add_func ("/print-layout/paginate-overflow", test_paginate_overflow);
    Test.add_func ("/print-layout/paginate-oversized-line", test_paginate_oversized_line);
    return Test.run ();
}
