/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// The CSS rule the editor text is drawn with: the chosen font description at the
// current zoom.
public class ValaPad.FontCss : Object {
    public static string build (Pango.FontDescription font, int zoom_percentage) {
        string family = font.get_family () ?? "system-ui";
        family = family.replace ("\\", "\\\\").replace ("\"", "\\\"");

        double size = font.get_size () / (double) Pango.SCALE;
        size *= zoom_percentage / 100.0;
        string unit = font.get_size_is_absolute () ? "px" : "pt";

        return """
            .valapad-text {
                font-family: "%s";
                font-size: %.2f%s;
                font-style: %s;
                font-weight: %d;
                font-stretch: %s;
                font-variant-caps: %s;
            }
        """.printf (
            family,
            size,
            unit,
            font_style_to_css (font.get_style ()),
            (int) font.get_weight (),
            font_stretch_to_css (font.get_stretch ()),
            font_variant_to_css (font.get_variant ())
        );
    }

    private static string font_style_to_css (Pango.Style style) {
        switch (style) {
            case Pango.Style.ITALIC:
                return "italic";
            case Pango.Style.OBLIQUE:
                return "oblique";
            default:
                return "normal";
        }
    }

    private static string font_stretch_to_css (Pango.Stretch stretch) {
        switch (stretch) {
            case Pango.Stretch.ULTRA_CONDENSED:
                return "ultra-condensed";
            case Pango.Stretch.EXTRA_CONDENSED:
                return "extra-condensed";
            case Pango.Stretch.CONDENSED:
                return "condensed";
            case Pango.Stretch.SEMI_CONDENSED:
                return "semi-condensed";
            case Pango.Stretch.SEMI_EXPANDED:
                return "semi-expanded";
            case Pango.Stretch.EXPANDED:
                return "expanded";
            case Pango.Stretch.EXTRA_EXPANDED:
                return "extra-expanded";
            case Pango.Stretch.ULTRA_EXPANDED:
                return "ultra-expanded";
            default:
                return "normal";
        }
    }

    private static string font_variant_to_css (Pango.Variant variant) {
        switch (variant) {
            case Pango.Variant.SMALL_CAPS:
                return "small-caps";
            case Pango.Variant.ALL_SMALL_CAPS:
                return "all-small-caps";
            case Pango.Variant.PETITE_CAPS:
                return "petite-caps";
            case Pango.Variant.ALL_PETITE_CAPS:
                return "all-petite-caps";
            case Pango.Variant.UNICASE:
                return "unicase";
            case Pango.Variant.TITLE_CAPS:
                return "titling-caps";
            default:
                return "normal";
        }
    }
}
