/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

private void test_font_rule () {
    var font = Pango.FontDescription.from_string ("Monospace 12");

    string css = ValaPad.FontCss.build (font, 100);

    assert (".valapad-text {" in css);
    assert ("font-family: \"Monospace\";" in css);
    assert ("font-size: 12.00pt;" in css);
    assert ("font-style: normal;" in css);
    assert ("font-weight: 400;" in css);
    assert ("font-stretch: normal;" in css);
    assert ("font-variant-caps: normal;" in css);
}

private void test_zoom_scales_size () {
    var font = Pango.FontDescription.from_string ("Monospace 12");

    assert ("font-size: 24.00pt;" in ValaPad.FontCss.build (font, 200));
    assert ("font-size: 6.00pt;" in ValaPad.FontCss.build (font, 50));
}

private void test_absolute_size_uses_pixels () {
    var font = Pango.FontDescription.from_string ("system-ui");
    font.set_absolute_size (14 * Pango.SCALE);

    string css = ValaPad.FontCss.build (font, 100);

    assert ("font-family: \"system-ui\";" in css);
    assert ("font-size: 14.00px;" in css);
}

private void test_missing_family_falls_back () {
    var font = new Pango.FontDescription ();

    assert ("font-family: \"system-ui\";" in ValaPad.FontCss.build (font, 100));
}

private void test_style_variants () {
    var font = Pango.FontDescription.from_string ("Monospace 12");
    font.set_style (Pango.Style.ITALIC);
    font.set_weight (Pango.Weight.BOLD);
    font.set_stretch (Pango.Stretch.CONDENSED);
    font.set_variant (Pango.Variant.SMALL_CAPS);

    string css = ValaPad.FontCss.build (font, 100);

    assert ("font-style: italic;" in css);
    assert ("font-weight: 700;" in css);
    assert ("font-stretch: condensed;" in css);
    assert ("font-variant-caps: small-caps;" in css);
}

private void test_quoted_family_is_escaped () {
    var font = Pango.FontDescription.from_string ("Monospace 12");
    font.set_family ("An\"Quoted");

    assert ("font-family: \"An\\\"Quoted\";" in ValaPad.FontCss.build (font, 100));
}

private void test_backslash_family_is_escaped () {
    var font = Pango.FontDescription.from_string ("Monospace 12");
    font.set_family ("Back\\slash");

    assert ("font-family: \"Back\\\\slash\";" in ValaPad.FontCss.build (font, 100));
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/font-css/font-rule", test_font_rule);
    Test.add_func ("/font-css/zoom-scales-size", test_zoom_scales_size);
    Test.add_func ("/font-css/absolute-size-uses-pixels", test_absolute_size_uses_pixels);
    Test.add_func ("/font-css/missing-family-falls-back", test_missing_family_falls_back);
    Test.add_func ("/font-css/style-variants", test_style_variants);
    Test.add_func ("/font-css/quoted-family-is-escaped", test_quoted_family_is_escaped);
    Test.add_func ("/font-css/backslash-family-is-escaped", test_backslash_family_is_escaped);
    return Test.run ();
}
