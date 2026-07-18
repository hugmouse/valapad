/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public enum ValaPad.FontCategory {
    ALL,
    MONOSPACE,
    SANS_SERIF
}

public class ValaPad.FontFilter : Object {
    // TODO: probably theres better way lmao
    private static string[] sans_markers = {
        "sans", "arial", "cantarell", "gothic", "grotesk", "helvetica",
        "inter", "roboto", "segoe", "tahoma", "ubuntu", "verdana"
    };

    private string normalized_query = "";
    private string _search_text = "";

    public FontCategory category { get; set; default = FontCategory.ALL; }
    public string search_text {
        get { return _search_text; }
        set {
            _search_text = value;
            normalized_query = value.strip ().casefold ();
        }
    }

    public bool matches (string family_name, bool is_monospace) {
        if (!matches_category (family_name, is_monospace)) {
            return false;
        }

        return normalized_query.length == 0 ||
            family_name.casefold ().contains (normalized_query);
    }

    public static bool is_sans_serif (string family_name) {
        string normalized = family_name.casefold ();
        if (normalized.contains ("serif") && !normalized.contains ("sans serif")) {
            return false;
        }

        foreach (unowned string marker in sans_markers) {
            if (normalized.contains (marker)) {
                return true;
            }
        }

        return false;
    }

    private bool matches_category (string family_name, bool is_monospace) {
        switch (category) {
            case FontCategory.MONOSPACE:
                return is_monospace;
            case FontCategory.SANS_SERIF:
                return is_sans_serif (family_name);
            default:
                return true;
        }
    }
}
