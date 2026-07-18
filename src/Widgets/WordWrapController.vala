/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.WordWrapController : Object {
    public const string SETTINGS_KEY = "word-wrap";

    private Gtk.TextView text_view;
    private Settings settings;

    public WordWrapController (Gtk.TextView text_view, Settings settings) {
        this.text_view = text_view;
        this.settings = settings;

        settings.changed[SETTINGS_KEY].connect (apply);
        apply ();
    }

    public Action create_action () {
        return settings.create_action (SETTINGS_KEY);
    }

    private void apply () {
        text_view.wrap_mode = settings.get_boolean (SETTINGS_KEY)
            ? Gtk.WrapMode.WORD
            : Gtk.WrapMode.NONE;
    }
}
