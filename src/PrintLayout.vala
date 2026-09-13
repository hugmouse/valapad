/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.PrintLayout : Object {
    private const double MARGIN_PT = 36.0; // 0.5 inch
    private const double PT_PER_INCH = 72.0;

    public static double points_to_pixels (double pt, double dpi) {
        return pt * dpi / PT_PER_INCH;
    }

    public static double margin_px (double dpi) {
        return points_to_pixels (MARGIN_PT, dpi);
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
