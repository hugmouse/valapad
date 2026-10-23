/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Thingie to sync accent color from macOS with granite themes
public class ValaPad.MacosAccent : Object {
    private const string THEME_PREFIX = "io.elementary.stylesheet.";

    private static Gtk.CssProvider? accent_provider;

    [CCode (has_target = false)]
    private delegate void ChangedCallback ();

    public delegate void ChangeHandler ();

    private static ChangeHandler? change_handler;

    [CCode (cname = "valapad_macos_accent_index")]
    private static extern int accent_index ();

    [CCode (cname = "valapad_macos_accent_rgb")]
    private static extern int accent_rgb ();

    [CCode (cname = "valapad_macos_prefers_dark")]
    public static extern bool prefers_dark ();

    [CCode (cname = "valapad_macos_accent_observe")]
    private static extern void accent_observe (ChangedCallback callback);

    public static void apply (owned ChangeHandler? handler = null) {
        change_handler = (owned) handler;
        accent_observe (() => MainContext.default ().invoke (handle_change));
        handle_change ();
    }

    private static bool handle_change () {
        update ();
        if (change_handler != null) {
            change_handler ();
        }
        return false;
    }

    private static bool update () {
        var settings = Gtk.Settings.get_default ();
        var display = Gdk.Display.get_default ();
        if (settings == null || display == null) {
            return false;
        }

        int index = accent_index ();
        int rgb = accent_rgb ();
        string theme = theme_for (index);
        if (settings.gtk_theme_name != theme) {
            settings.gtk_theme_name = theme;
        }
        debug (
            "macOS accent: index=%d theme=%s color=%s",
            index,
            theme,
            rgb >= 0 ? "#%06x".printf (rgb) : "unavailable"
        );

        if (rgb < 0) {
            return false;
        }

        if (accent_provider == null) {
            accent_provider = new Gtk.CssProvider ();
            Css.add_provider_for_display (display, accent_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        }
        accent_provider.load_from_string (css_for (rgb));
        return false;
    }

    private static string theme_for (int index) {
        switch (index) {
            case -1:
                return THEME_PREFIX + "slate";
            case 0:
                return THEME_PREFIX + "strawberry";
            case 1:
                return THEME_PREFIX + "orange";
            case 2:
                return THEME_PREFIX + "banana";
            case 3:
                return THEME_PREFIX + "lime";
            case 5:
                return THEME_PREFIX + "grape";
            case 6:
                return THEME_PREFIX + "bubblegum";
            default:
                return THEME_PREFIX + "blueberry";
        }
    }

    private static string css_for (int rgb) {
        return """
            @define-color accent_color #%06x;
            @define-color accent_color_100 shade(@accent_color, 1.6);
            @define-color accent_color_300 shade(@accent_color, 1.3);
            @define-color accent_color_500 @accent_color;
            @define-color accent_color_700 shade(@accent_color, 0.75);
            @define-color accent_color_900 shade(@accent_color, 0.55);
            @define-color selected_bg_color alpha(@accent_color, 0.25);
            @define-color selected_fg_color shade(@accent_color, 0.5);
        """.printf (rgb);
    }
}
