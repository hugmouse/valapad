/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_category_all () {
    var filter = new ValaPad.FontFilter ();
    assert (filter.matches ("DejaVu Sans", false));
    assert (filter.matches ("DejaVu Sans Mono", true));
}

private void test_category_monospace () {
    var filter = new ValaPad.FontFilter () {
        category = ValaPad.FontCategory.MONOSPACE
    };
    assert (filter.matches ("DejaVu Sans Mono", true));
    assert (!filter.matches ("DejaVu Sans", false));
}

private void test_category_sans_serif () {
    var filter = new ValaPad.FontFilter () {
        category = ValaPad.FontCategory.SANS_SERIF
    };
    assert (filter.matches ("Cantarell", false));
    assert (filter.matches ("Helvetica Neue", false));
    assert (filter.matches ("Sans Serif", false));
    assert (!filter.matches ("Liberation Serif", false));
    assert (!filter.matches ("DejaVu Sans Mono", true));
}

private void test_search_text () {
    var filter = new ValaPad.FontFilter ();
    filter.search_text = "  DEJA  ";
    assert (filter.matches ("DejaVu Sans Mono", true));
    assert (!filter.matches ("Cantarell", false));

    filter.search_text = "";
    assert (filter.matches ("Cantarell", false));
}

private void test_sans_serif_detection () {
    assert (ValaPad.FontFilter.is_sans_serif ("Helvetica Neue"));
    assert (!ValaPad.FontFilter.is_sans_serif ("Liberation Serif"));
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/font-filter/category-all", test_category_all);
    Test.add_func ("/font-filter/category-monospace", test_category_monospace);
    Test.add_func ("/font-filter/category-sans-serif", test_category_sans_serif);
    Test.add_func ("/font-filter/search-text", test_search_text);
    Test.add_func ("/font-filter/sans-serif-detection", test_sans_serif_detection);
    return Test.run ();
}
