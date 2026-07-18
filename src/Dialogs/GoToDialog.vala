/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.GoToDialog : Gtk.Window {
    private Gtk.TextView text_view;
    private Gtk.TextBuffer buffer;
    private Gtk.SpinButton line_spin;

    public GoToDialog (Gtk.Window parent, Gtk.TextView text_view) {
        Object (
            transient_for: parent,
            modal: true,
            title: _("Go To"),
            resizable: false
        );
        this.text_view = text_view;
        this.buffer = text_view.buffer;

        build_ui ();
    }

    private void build_ui () {
        var label = new Gtk.Label (_("Line number:")) {
            xalign = 0
        };

        int line_count = buffer.get_line_count ();
        line_spin = new Gtk.SpinButton.with_range (1, line_count, 1) {
            halign = Gtk.Align.START,
            width_chars = 10,
            activates_default = true
        };

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.clicked.connect (() => close ());

        var go_to_button = new Gtk.Button.with_label (_("Go To")) {
            receives_default = true
        };
        go_to_button.add_css_class ("suggested-action");
        go_to_button.clicked.connect (() => {
            go_to_line (line_spin.get_value_as_int ());
            close ();
        });
        default_widget = go_to_button;

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END
        };
        button_box.append (cancel_button);
        button_box.append (go_to_button);

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 18,
            margin_end = 18
        };
        content.append (label);
        content.append (line_spin);
        content.append (button_box);
        child = content;
    }

    public void show_dialog () {
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, buffer.get_insert ());
        line_spin.set_value (iter.get_line () + 1);

        present ();
    }

    private void go_to_line (int line_number) {
        Gtk.TextIter iter;
        buffer.get_start_iter (out iter);
        iter.set_line (line_number - 1);
        iter.set_line_offset (0);

        buffer.place_cursor (iter);
        buffer.select_range (iter, iter);
        text_view.scroll_to_iter (iter, 0.2, false, 0, 0);
    }
}