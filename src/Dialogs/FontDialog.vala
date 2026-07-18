/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.FontDialog : Gtk.Window {
    private const string PREVIEW_TEXT = "The quick brown fox jumps over the lazy dog.";

    private Gtk.SingleSelection family_selection;
    private Gtk.CustomFilter family_filter;
    private Gtk.FilterListModel filtered_families;
    private FontFilter filter_state;
    private Gtk.SearchEntry search_entry;
    private Gtk.DropDown category_dropdown;
    private Gtk.DropDown face_dropdown;
    private Gtk.SpinButton size_spin;
    private Gtk.Label preview;
    private Gtk.Button select_button;
    private Pango.FontDescription selected_font;
    private Pango.FontDescription[] face_descriptions = {};

    public signal void font_selected (Pango.FontDescription description);

    public FontDialog (Gtk.Window parent, Pango.FontDescription initial_font) {
        Object (
            title: _("Choose Font"),
            transient_for: parent,
            modal: true,
            default_width: 640,
            default_height: 520,
            hide_on_close: true
        );

        selected_font = initial_font.copy ();
        build_ui ();
        update_faces ();
        select_initial_family ();
    }

    private void build_ui () {
        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((object) => {
            var list_item = object as Gtk.ListItem;
            if (list_item != null) {
                list_item.child = new Gtk.Label (null) {
                    ellipsize = Pango.EllipsizeMode.END,
                    hexpand = true,
                    xalign = 0,
                    margin_start = 8,
                    margin_end = 8,
                    margin_top = 4,
                    margin_bottom = 4
                };
            }
        });
        factory.bind.connect ((object) => {
            var list_item = object as Gtk.ListItem;
            var family = list_item != null ? list_item.item as Pango.FontFamily : null;
            var label = list_item != null ? list_item.child as Gtk.Label : null;
            if (family != null && label != null) {
                label.label = family.get_name ();
            }
        });

        filter_state = new FontFilter ();
        family_filter = new Gtk.CustomFilter ((item) => {
            var family = item as Pango.FontFamily;
            return family != null && filter_state.matches (
                family.get_name (),
                family.is_monospace ()
            );
        });

        var font_map = Pango.CairoFontMap.get_default ();
        filtered_families = new Gtk.FilterListModel ((ListModel) font_map, family_filter) {
            incremental = true
        };
        family_selection = new Gtk.SingleSelection (filtered_families) {
            autoselect = true,
            can_unselect = false
        };
        family_selection.notify["selected-item"].connect (update_faces);

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search fonts")
        };
        search_entry.notify["text"].connect (() => {
            filter_state.search_text = search_entry.text;
            family_filter.changed (Gtk.FilterChange.DIFFERENT);
        });

        category_dropdown = new Gtk.DropDown.from_strings ({
            _("All Fonts"),
            _("Monospace"),
            _("Sans Serif")
        }) {
            selected = FontCategory.ALL
        };
        category_dropdown.notify["selected"].connect (() => {
            filter_state.category = (FontCategory) category_dropdown.selected;
            family_filter.changed (Gtk.FilterChange.DIFFERENT);
        });

        var filter_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12
        };
        filter_box.append (search_entry);
        filter_box.append (category_dropdown);

        var family_list = new Gtk.ListView (family_selection, factory) {
            single_click_activate = true,
            vexpand = true
        };
        family_list.activate.connect ((position) => {
            family_selection.selected = position;
        });
        var family_scroller = new Gtk.ScrolledWindow () {
            child = family_list,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            vexpand = true,
            min_content_width = 280
        };
        var family_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            width_request = 280
        };
        family_box.append (filter_box);
        family_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        family_box.append (family_scroller);

        var face_expression = new Gtk.PropertyExpression (
            typeof (Gtk.StringObject),
            null,
            "string"
        );
        face_dropdown = new Gtk.DropDown.from_strings ({ _("Regular") }) {
            enable_search = true,
            expression = face_expression,
            hexpand = true
        };
        face_dropdown.notify["selected"].connect (update_preview);

        size_spin = new Gtk.SpinButton.with_range (6, 144, 1) {
            value = get_initial_size (),
            width_chars = 5
        };
        size_spin.value_changed.connect (update_preview);

        var controls = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 12,
            margin_start = 18,
            margin_end = 18,
            margin_top = 18,
            margin_bottom = 18
        };
        controls.attach (new Gtk.Label (_("Style")) { xalign = 0 }, 0, 0);
        controls.attach (face_dropdown, 1, 0);
        controls.attach (new Gtk.Label (_("Size")) { xalign = 0 }, 0, 1);
        controls.attach (size_spin, 1, 1);

        preview = new Gtk.Label (PREVIEW_TEXT) {
            wrap = true,
            xalign = 0,
            yalign = 0.5f,
            height_request = 140,
            margin_start = 18,
            margin_end = 18,
            margin_top = 12,
            margin_bottom = 12,
            selectable = true
        };
        var preview_frame = new Gtk.Frame (_("Preview")) {
            child = preview,
            margin_start = 18,
            margin_end = 18,
            margin_bottom = 18
        };

        select_button = new Gtk.Button.with_label (_("Select")) {
            sensitive = false
        };
        select_button.add_css_class ("suggested-action");
        select_button.clicked.connect (() => {
            font_selected (selected_font.copy ());
            close ();
        });
        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        cancel_button.clicked.connect (() => close ());

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
            halign = Gtk.Align.END,
            margin_start = 18,
            margin_end = 18,
            margin_bottom = 18
        };
        button_box.append (cancel_button);
        button_box.append (select_button);

        var detail_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true
        };
        detail_box.append (controls);
        detail_box.append (preview_frame);
        detail_box.append (button_box);

        var content = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            position = 280,
            resize_start_child = false,
            shrink_start_child = false,
            shrink_end_child = false,
            start_child = family_box,
            end_child = detail_box
        };
        child = content;
    }

    private double get_initial_size () {
        double size = selected_font.get_size () / (double) Pango.SCALE;
        return size > 0 ? size.clamp (6, 144) : 14;
    }

    private void select_initial_family () {
        string? initial_family = selected_font.get_family ();
        var model = family_selection.get_model ();
        if (initial_family == null || model == null) {
            return;
        }

        for (uint i = 0; i < model.get_n_items (); i++) {
            var family = model.get_item (i) as Pango.FontFamily;
            if (family != null && family.get_name () == initial_family) {
                family_selection.selected = i;
                return;
            }
        }
    }

    private void update_faces () {
        var family = family_selection.get_selected_item () as Pango.FontFamily;
        if (family == null) {
            select_button.sensitive = false;
            return;
        }

        (unowned Pango.FontFace)[] faces;
        family.list_faces (out faces);
        face_descriptions = new Pango.FontDescription[faces.length];
        string[] names = new string[faces.length + 1];
        for (int i = 0; i < faces.length; i++) {
            face_descriptions[i] = faces[i].describe ();
            names[i] = faces[i].get_face_name ();
        }
        names[faces.length] = null;

        face_dropdown.model = new Gtk.StringList (names);
        face_dropdown.selected = 0;
        select_button.sensitive = faces.length > 0;
        update_preview ();
    }

    private void update_preview () {
        uint selected = face_dropdown.selected;
        if (selected >= face_descriptions.length) {
            return;
        }

        selected_font = face_descriptions[selected].copy ();
        selected_font.set_size ((int) (size_spin.value * Pango.SCALE));

        var attributes = new Pango.AttrList ();
        attributes.insert (new Pango.AttrFontDesc (selected_font));
        attributes.insert (Pango.attr_fallback_new (true));
        preview.attributes = attributes;
    }
}
