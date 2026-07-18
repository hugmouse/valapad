/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.Application : Gtk.Application {
    public const string ACTION_NEW = "new";
    public const string ACTION_NEW_WINDOW = "new-window";
    public const string ACTION_OPEN = "open";
    public const string ACTION_SAVE = "save";
    public const string ACTION_SAVE_AS = "save-as";
    public const string ACTION_PAGE_SETUP = "page-setup";
    public const string ACTION_PRINT = "print";
    public const string ACTION_QUIT = "quit";

    public const string ACTION_UNDO = "undo";
    public const string ACTION_REDO = "redo";
    public const string ACTION_CUT = "cut";
    public const string ACTION_COPY = "copy";
    public const string ACTION_PASTE = "paste";
    public const string ACTION_DELETE = "delete";
    public const string ACTION_FIND = "find";
    public const string ACTION_FIND_NEXT = "find-next";
    public const string ACTION_FIND_PREVIOUS = "find-previous";
    public const string ACTION_REPLACE = "replace";
    public const string ACTION_GO_TO = "go-to";
    public const string ACTION_SELECT_ALL = "select-all";
    public const string ACTION_TIME_DATE = "time-date";

    public const string ACTION_WORD_WRAP = "word-wrap";
    public const string ACTION_FONT = "font";

    public const string ACTION_ZOOM_IN = "zoom-in";
    public const string ACTION_ZOOM_OUT = "zoom-out";
    public const string ACTION_ZOOM_DEFAULT = "zoom-default";
    public const string ACTION_STATUS_BAR = "status-bar";

    public const string ACTION_ABOUT = "about";

    public Application () {
        Object (
            application_id: Build.PROJECT_NAME,
            flags: ApplicationFlags.HANDLES_OPEN
        );

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.textdomain (Build.GETTEXT_PACKAGE);
        Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.LOCALEDIR);
        Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");
    }

    protected override void startup () {
        base.startup ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();
        if (gtk_settings != null) {
            gtk_settings.gtk_application_prefer_dark_theme =
                granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme =
                    granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });
        }

        add_app_actions ();
        set_accels_for_action ("app." + ACTION_QUIT, { "<Control>q" });
    }

    private void add_app_actions () {
        var quit_action = new SimpleAction (ACTION_QUIT, null);
        quit_action.activate.connect (() => {
            foreach (var window in get_windows ()) {
                window.close ();
            }
        });
        add_action (quit_action);

        var new_window_action = new SimpleAction (ACTION_NEW_WINDOW, null);
        new_window_action.activate.connect (() => {
            new_window ();
        });
        add_action (new_window_action);
    }

    protected override void activate () {
        if (active_window == null) {
            new_window ();
        } else {
            active_window.present ();
        }
    }

    public MainWindow new_window () {
        var window = new MainWindow (this);
        window.present ();
        return window;
    }

    protected override void open (File[] files, string hint) {
        foreach (var file in files) {
            var window = new_window ();
            window.open_file (file);
        }
    }

    public static int main (string[] args) {
        if (Environment.get_variable ("GSETTINGS_SCHEMA_DIR") == null) {
            var schema_file = File.new_build_filename (
                Build.GSETTINGS_SCHEMA_DIR,
                "gschemas.compiled"
            );
            if (schema_file.query_exists ()) {
                Environment.set_variable (
                    "GSETTINGS_SCHEMA_DIR",
                    Build.GSETTINGS_SCHEMA_DIR,
                    false
                );
            }
        }

        return new Application ().run (args);
    }
}
