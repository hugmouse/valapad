/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_unit_conversions () {
    assert (ValaPad.PrintLayout.margin_px (72.0) == 36.0);
    assert (ValaPad.PrintLayout.margin_px (96.0) == 48.0);
    double px = ValaPad.PrintLayout.points_to_pixels (72.0, 96.0);
    assert (px == 96.0);
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
    Test.add_func ("/print-layout/unit-conversions", test_unit_conversions);
    Test.add_func ("/print-layout/paginate-empty", test_paginate_empty);
    Test.add_func ("/print-layout/paginate-single-page", test_paginate_single_page);
    Test.add_func ("/print-layout/paginate-overflow", test_paginate_overflow);
    Test.add_func ("/print-layout/paginate-oversized-line", test_paginate_oversized_line);
    return Test.run ();
}
