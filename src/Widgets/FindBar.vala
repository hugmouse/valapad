/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.FindBar : Gtk.Box {
    private Gtk.TextView text_view;
    private Gtk.TextBuffer buffer;

    private Gtk.SearchEntry search_entry;
    private Gtk.Button next_button;
    private Gtk.Button prev_button;
    private Gtk.Revealer replace_revealer;

    private Gtk.Entry replace_entry;
    private Gtk.Button replace_button;
    private Gtk.Button replace_all_button;

    private Gtk.ToggleButton match_case_toggle;
    private Gtk.ToggleButton wrap_toggle;

    public FindBar (Gtk.TextView text_view) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        this.text_view = text_view;
        this.buffer = text_view.buffer;
        this.add_css_class ("valapad-findbar");

        build_ui ();
    }

    private void build_ui () {
        // Search row
        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Find"),
            hexpand = true,
            width_chars = 24
        };
        search_entry.activate.connect (find_next);

        next_button = new Gtk.Button.from_icon_name ("go-down-symbolic") {
            tooltip_text = _("Find Next (F3)")
        };
        next_button.clicked.connect (find_next);

        prev_button = new Gtk.Button.from_icon_name ("go-up-symbolic") {
            tooltip_text = _("Find Previous (Shift+F3)")
        };
        prev_button.clicked.connect (find_previous);

        match_case_toggle = new Gtk.ToggleButton.with_label (_("Aa")) {
            tooltip_text = _("Match Case")
        };
        wrap_toggle = new Gtk.ToggleButton.with_label (_("↩")) {
            tooltip_text = _("Wrap Around"),
            active = true
        };

        var close_button = new Gtk.Button.from_icon_name ("window-close-symbolic") {
            tooltip_text = _("Close")
        };
        close_button.clicked.connect (hide_bar);

        var search_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 6,
            margin_bottom = 6
        };
        search_box.append (search_entry);
        search_box.append (match_case_toggle);
        search_box.append (wrap_toggle);
        search_box.append (prev_button);
        search_box.append (next_button);
        search_box.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        search_box.append (close_button);

        // Replace row
        replace_entry = new Gtk.Entry () {
            placeholder_text = _("Replace with"),
            hexpand = true,
            width_chars = 24
        };

        replace_button = new Gtk.Button.with_label (_("Replace")) {
            tooltip_text = _("Replace next match")
        };
        replace_button.clicked.connect (replace_one);

        replace_all_button = new Gtk.Button.with_label (_("Replace All")) {
            tooltip_text = _("Replace all matches")
        };
        replace_all_button.clicked.connect (replace_all);

        var replace_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 0, // otherwise feels like it's not really a part of the whole "find and replace" ui
            margin_bottom = 6
        };
        replace_box.append (replace_entry);
        replace_box.append (replace_button);
        replace_box.append (replace_all_button);

        replace_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            child = replace_box,
            reveal_child = false
        };

        append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        append (search_box);
        append (replace_revealer);
    }

    public void show_bar () {
        visible = true;
        replace_revealer.reveal_child = false;
        search_entry.grab_focus ();
        if (buffer.get_has_selection ()) {
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_slice (start, end, true);
            if (!("\n" in selected)) {
                search_entry.text = selected;
            }
        }
        search_entry.select_region (0, -1);
    }

    public void show_replace () {
        visible = true;
        replace_revealer.reveal_child = true;
        search_entry.grab_focus ();
    }

    public new void hide () {
        visible = false;
        text_view.grab_focus ();
    }

    public void hide_bar () {
        hide ();
    }

    private bool find_match (Gtk.TextIter start, bool forward, out Gtk.TextIter match_start, out Gtk.TextIter match_end) {
        string needle = search_entry.text;
        if (needle == "") {
            match_start = start;
            match_end = start;
            return false;
        }

        Gtk.TextSearchFlags flags = Gtk.TextSearchFlags.TEXT_ONLY;
        if (!match_case_toggle.active) {
            flags |= Gtk.TextSearchFlags.CASE_INSENSITIVE;
        }

        if (forward) {
            return start.forward_search (needle, flags, out match_start, out match_end, null);
        } else {
            return start.backward_search (needle, flags, out match_start, out match_end, null);
        }
    }

    public void find_next () {
        if (search_entry.text == "") {
            return;
        }

        Gtk.TextIter start;
        if (buffer.get_has_selection ()) {
            Gtk.TextIter sel_start, sel_end;
            buffer.get_selection_bounds (out sel_start, out sel_end);
            start = sel_end;
        } else {
            buffer.get_iter_at_mark (out start, buffer.get_insert ());
        }

        Gtk.TextIter match_start, match_end;
        if (find_match (start, true, out match_start, out match_end)) {
            buffer.select_range (match_start, match_end);
            scroll_to_iter (match_start);
            return;
        }

        if (wrap_toggle.active) {
            buffer.get_start_iter (out start);
            if (find_match (start, true, out match_start, out match_end)) {
                buffer.select_range (match_start, match_end);
                scroll_to_iter (match_start);
            }
        }
    }

    public void find_previous () {
        if (search_entry.text == "") {
            return;
        }

        Gtk.TextIter start;
        if (buffer.get_has_selection ()) {
            Gtk.TextIter sel_start, sel_end;
            buffer.get_selection_bounds (out sel_start, out sel_end);
            start = sel_start;
        } else {
            buffer.get_iter_at_mark (out start, buffer.get_insert ());
        }

        Gtk.TextIter match_start, match_end;
        if (find_match (start, false, out match_start, out match_end)) {
            buffer.select_range (match_start, match_end);
            scroll_to_iter (match_start);
            return;
        }

        if (wrap_toggle.active) {
            buffer.get_end_iter (out start);
            if (find_match (start, false, out match_start, out match_end)) {
                buffer.select_range (match_start, match_end);
                scroll_to_iter (match_start);
            }
        }
    }

    private void replace_one () {
        if (search_entry.text == "") {
            return;
        }

        Gtk.TextIter match_start = Gtk.TextIter ();
        Gtk.TextIter match_end = Gtk.TextIter ();
        bool has_match = false;

        if (buffer.get_has_selection ()) {
            Gtk.TextIter sel_start, sel_end;
            buffer.get_selection_bounds (out sel_start, out sel_end);
            has_match = find_match (sel_start, true, out match_start, out match_end);
            if (has_match && (match_start.compare (sel_start) != 0 || match_end.compare (sel_end) != 0)) {
                has_match = false;
            }
        }

        if (!has_match) {
            find_next ();
            return;
        }

        string replacement = replace_entry.text;
        buffer.begin_user_action ();
        buffer.@delete (ref match_start, ref match_end);
        buffer.insert (ref match_start, replacement, replacement.length);
        buffer.end_user_action ();

        find_next ();
    }

    private void replace_all () {
        if (search_entry.text == "") {
            return;
        }

        string needle = search_entry.text;
        string replacement = replace_entry.text;
        Gtk.TextSearchFlags flags = Gtk.TextSearchFlags.TEXT_ONLY;
        if (!match_case_toggle.active) {
            flags |= Gtk.TextSearchFlags.CASE_INSENSITIVE;
        }

        buffer.begin_user_action ();

        Gtk.TextIter iter;
        buffer.get_start_iter (out iter);

        int safety = 100000;
        while (safety-- > 0) {
            Gtk.TextIter match_start, match_end;
            if (!iter.forward_search (needle, flags, out match_start, out match_end, null)) {
                break;
            }

            buffer.@delete (ref match_start, ref match_end);
            Gtk.TextIter insert_iter = match_start;
            buffer.insert (ref insert_iter, replacement, replacement.length);
            iter = insert_iter;
        }

        buffer.end_user_action ();
    }

    private void scroll_to_iter (Gtk.TextIter iter) {
        text_view.scroll_to_iter (iter, 0.2, false, 0, 0);
    }
}
