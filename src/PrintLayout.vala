/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.PrintLayout : Object {
    private const double MARGIN_PT = 36.0; // 0.5 inch
    private const double PT_PER_INCH = 72.0;

    public static double margin () {
        return MARGIN_PT;
    }

    public static double pixels_to_points (double px, double dpi) {
        return px * PT_PER_INCH / dpi;
    }

    public static double points_to_pixels (double pt, double dpi) {
        return pt * dpi / PT_PER_INCH;
    }

    public static double margin_px (double dpi) {
        return points_to_pixels (MARGIN_PT, dpi);
    }

    public static double line_height (Pango.FontDescription font) {
        var font_map = Pango.CairoFontMap.get_default ();
        var pango_context = new Pango.Context ();
        pango_context.set_font_map (font_map);

        var layout = new Pango.Layout (pango_context);
        layout.set_font_description (font);
        layout.set_text ("", -1);

        Pango.Rectangle ink_rect, logical_rect;
        layout.get_extents (out ink_rect, out logical_rect);

        // Fallback: the empty layout may report zero height.
        double height = logical_rect.height;
        if (height <= 0) {
            height = logical_rect.y + layout.get_baseline ();
        }
        if (height <= 0) {
            // get_size () is in device pixels for absolute sizes but in
            // points otherwise; normalize to device pixels * SCALE so the
            // points conversion below stays correct.
            if (font.get_size_is_absolute ()) {
                height = font.get_size ();
            } else {
                double dpi_fallback = 96.0;
                if (font_map is Pango.CairoFontMap) {
                    dpi_fallback = ((Pango.CairoFontMap) font_map).get_resolution ();
                }
                if (!(dpi_fallback > 0)) {
                    dpi_fallback = 96.0;
                }
                height = font.get_size () * dpi_fallback / PT_PER_INCH;
            }
        }
        if (height <= 0) {
            // Font has no size set; assume a readable 12pt line.
            return 12.0;
        }

        // Metrics come back in device pixels; Gtk.PrintContext dimensions
        // are also in device pixels (use get_dpi_x/y to convert to points).
        double dpi = 96.0;
        if (font_map is Pango.CairoFontMap) {
            dpi = ((Pango.CairoFontMap) font_map).get_resolution ();
        }
        if (!(dpi > 0)) {
            dpi = 96.0;
        }
        return height * PT_PER_INCH / (dpi * Pango.SCALE);
    }

    public static int lines_per_page (Pango.FontDescription font, double page_height_pt) {
        double available = page_height_pt - 2.0 * MARGIN_PT;
        double height = line_height (font);
        if (!(available > 0) || !(height > 0)) {
            return 1;
        }
        // Truncation toward zero is fine: negative results clamp to 1 below.
        int count = (int) (available / height);
        return int.max (count, 1);
    }

    public static GenericArray<int> paginate_by_heights (int[] heights, int content_height_px) {
        var starts = new GenericArray<int> ();
        if (heights.length == 0) {
            starts.add (0);
            return starts;
        }
        if (content_height_px < 1) {
            content_height_px = 1;
        }
        starts.add (0);
        int used = 0;
        for (int i = 0; i < heights.length; i++) {
            int line_height_px = int.max (heights[i], 1);
            // A single oversized logical line gets its own page rather than
            // joining (and overflowing) the previous one.
            if (used > 0 && used + line_height_px > content_height_px) {
                starts.add (i);
                used = line_height_px;
            } else {
                used += line_height_px;
            }
        }
        return starts;
    }
}
