/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.MainWindow : Gtk.ApplicationWindow {
    [CCode (cname = "gtk_style_context_add_provider_for_display")]
    private static extern void add_provider_for_display (
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private const int BASE_FONT_PX = 14;
    private const int MIN_ZOOM = 10;
    private const int MAX_ZOOM = 500;

    private Gtk.TextView text_view;
    private Gtk.TextBuffer buffer;
    private Gtk.Label ln_label;
    private Gtk.Label col_label;
    private Gtk.Label zoom_label;
    private Gtk.Label line_ending_label;
    private Gtk.Label encoding_label;

    private Gtk.CssProvider font_provider;
    private Pango.FontDescription font_description;
    private FontDialog? font_dialog;
    private WordWrapController? word_wrap_controller;
    private Settings settings;

    private File? current_file = null;
    private bool use_crlf = false;
    private string encoding_name = "UTF-8";
    private int zoom_percentage = 100;

    private FindBar? find_bar;
    private GoToDialog? go_to_dialog;

    private bool confirmed_close = false;

    public MainWindow (Gtk.Application app) {
        Object (
            application: app,
            default_height: 600,
            default_width: 800,
            title: _("Untitled - ValaPad")
        );

        build_ui ();
        add_window_actions ();
        connect_signals ();
        update_status ();
        update_zoom_css ();
    }

    // --- UI construction ---------------------------------------------------------------------------------

    private void build_ui () {
        var menu_bar = new Gtk.PopoverMenuBar.from_model (build_menu_model ());

        buffer = new Gtk.TextBuffer (null);
        buffer.enable_undo = true;
        text_view = new Gtk.TextView.with_buffer (buffer) {
            wrap_mode = Gtk.WrapMode.WORD,
            monospace = false,
            left_margin = 12,
            right_margin = 12,
            top_margin = 8,
            bottom_margin = 8,
            pixels_inside_wrap = 2,
            vexpand = true,
            hexpand = true
        };
        text_view.add_css_class ("valapad-text");

        var scrolled = new Gtk.ScrolledWindow () {
            child = text_view,
            hexpand = true,
            vexpand = true
        };

        find_bar = new FindBar (text_view);
        find_bar.visible = false;

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.append (menu_bar);
        main_box.append (scrolled);
        main_box.append (find_bar);
        main_box.append (build_status_bar ());

        child = main_box;

        // CSS providers
        font_provider = new Gtk.CssProvider ();
        settings = new Settings (Build.PROJECT_NAME);
        string saved_font = settings.get_string ("font");
        if (saved_font != "") {
            font_description = Pango.FontDescription.from_string (saved_font);
        } else {
            font_description = Pango.FontDescription.from_string ("system-ui");
            font_description.set_absolute_size (BASE_FONT_PX * Pango.SCALE);
        }
        add_provider_for_display (
            get_display (),
            font_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        );

        var style_provider = new Gtk.CssProvider ();
        style_provider.load_from_string (STATUSBAR_CSS);
        add_provider_for_display (
            get_display (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private const string STATUSBAR_CSS = """
        .valapad-statusbar {
            border-top: 1px solid @borders;
            padding: 4px 0;
            font-size: 0.85em;
            color: @theme_text_color;
        }
        .valapad-statusbar label {
            opacity: 0.8;
        }
        .valapad-findbar {
            border-top: 1px solid @borders;
        }
    """;

    // ------------------------------
    // Ln 1 Col 1 | 100% | LF | UTF-8
    private Gtk.Widget build_status_bar () {
        ln_label = new Gtk.Label (_("Ln 1")) {
            xalign = 1,
            hexpand = true,
            margin_start = 8,
            margin_end = 4
        };
        col_label = new Gtk.Label (_("Col 1")) {
            xalign = 0,
            margin_end = 8
        };
        zoom_label = new Gtk.Label ("100%") {
            xalign = 0,
            margin_start = 8,
            margin_end = 8
        };
        line_ending_label = new Gtk.Label ("LF") {
            xalign = 0,
            margin_end = 8,
            margin_start = 8
        };
        encoding_label = new Gtk.Label ("UTF-8") {
            xalign = 0,
            margin_end = 8,
            margin_start = 8
        };

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box.add_css_class ("valapad-statusbar");
        box.append (ln_label);
        box.append (col_label);
        box.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        box.append (zoom_label);
        box.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        box.append (line_ending_label);
        box.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        box.append (encoding_label);

        return box;
    }

    // --- Menu model ---------------------------------------------------------------------------------

    private GLib.Menu build_menu_model () {
        var menu = new Menu ();

        // File
        var file_menu = new Menu ();
        file_menu.append (_("New"), "win." + Application.ACTION_NEW);
        file_menu.append (_("New Window"), "app." + Application.ACTION_NEW_WINDOW);
        file_menu.append (_("Open…"), "win." + Application.ACTION_OPEN);
        var save_section = new Menu ();
        save_section.append (_("Save"), "win." + Application.ACTION_SAVE);
        save_section.append (_("Save As…"), "win." + Application.ACTION_SAVE_AS);
        file_menu.append_section (null, save_section);
        var print_section = new Menu ();
        print_section.append (_("Print…"), "win." + Application.ACTION_PRINT);
        file_menu.append_section (null, print_section);
        file_menu.append (_("Exit"), "app." + Application.ACTION_QUIT);
        menu.append_submenu (_("File"), file_menu);

        // Edit
        var edit_menu = new Menu ();
        edit_menu.append (_("Undo"), "win." + Application.ACTION_UNDO);
        edit_menu.append (_("Redo"), "win." + Application.ACTION_REDO);
        var clip_section = new Menu ();
        clip_section.append (_("Cut"), "win." + Application.ACTION_CUT);
        clip_section.append (_("Copy"), "win." + Application.ACTION_COPY);
        clip_section.append (_("Paste"), "win." + Application.ACTION_PASTE);
        clip_section.append (_("Delete"), "win." + Application.ACTION_DELETE);
        edit_menu.append_section (null, clip_section);
        var find_section = new Menu ();
        find_section.append (_("Find…"), "win." + Application.ACTION_FIND);
        find_section.append (_("Find Next"), "win." + Application.ACTION_FIND_NEXT);
        find_section.append (_("Find Previous"), "win." + Application.ACTION_FIND_PREVIOUS);
        find_section.append (_("Replace…"), "win." + Application.ACTION_REPLACE);
        edit_menu.append_section (null, find_section);
        edit_menu.append (_("Go To…"), "win." + Application.ACTION_GO_TO);
        edit_menu.append (_("Select All"), "win." + Application.ACTION_SELECT_ALL);
        edit_menu.append (_("Time/Date"), "win." + Application.ACTION_TIME_DATE);
        menu.append_submenu (_("Edit"), edit_menu);

        // Format
        var format_menu = new Menu ();
        format_menu.append (_("Word Wrap"), "win." + Application.ACTION_WORD_WRAP);
        format_menu.append (_("Font…"), "win." + Application.ACTION_FONT);
        menu.append_submenu (_("Format"), format_menu);

        // View
        var view_menu = new Menu ();
        view_menu.append (_("Zoom In"), "win." + Application.ACTION_ZOOM_IN);
        view_menu.append (_("Zoom Out"), "win." + Application.ACTION_ZOOM_OUT);
        view_menu.append (_("Restore Default Zoom"), "win." + Application.ACTION_ZOOM_DEFAULT);
        menu.append_submenu (_("View"), view_menu);

        // Help
        var help_menu = new Menu ();
        help_menu.append (_("About ValaPad"), "win." + Application.ACTION_ABOUT);
        menu.append_submenu (_("Help"), help_menu);

        return menu;
    }

    // --- Actions ---------------------------------------------------------------------------------

    private void add_window_actions () {
        // Async actions (file operations that may prompt)
        add_action_with_callback (Application.ACTION_NEW, () => action_new.begin ());
        add_action_with_callback (Application.ACTION_OPEN, () => action_open.begin ());
        add_action_with_callback (Application.ACTION_SAVE, () => action_save.begin ());
        add_action_with_callback (Application.ACTION_SAVE_AS, () => action_save_as.begin ());
        add_action_with_callback (Application.ACTION_PRINT, action_print);

        // Edit actions
        add_action_with_callback (Application.ACTION_UNDO, action_undo);
        add_action_with_callback (Application.ACTION_REDO, action_redo);
        add_action_with_callback (Application.ACTION_CUT, action_cut);
        add_action_with_callback (Application.ACTION_COPY, action_copy);
        add_action_with_callback (Application.ACTION_PASTE, action_paste);
        add_action_with_callback (Application.ACTION_DELETE, action_delete);
        add_action_with_callback (Application.ACTION_FIND, action_find);
        add_action_with_callback (Application.ACTION_FIND_NEXT, () => find_bar.find_next ());
        add_action_with_callback (Application.ACTION_FIND_PREVIOUS, () => find_bar.find_previous ());
        add_action_with_callback (Application.ACTION_REPLACE, () => find_bar.show_replace ());
        add_action_with_callback (Application.ACTION_GO_TO, action_go_to);
        add_action_with_callback (Application.ACTION_SELECT_ALL, action_select_all);
        add_action_with_callback (Application.ACTION_TIME_DATE, action_time_date);

        // Format actions
        word_wrap_controller = new WordWrapController (text_view, settings);
        add_action (word_wrap_controller.create_action ());

        add_action_with_callback (Application.ACTION_FONT, action_font);

        // View actions
        add_action_with_callback (Application.ACTION_ZOOM_IN, action_zoom_in);
        add_action_with_callback (Application.ACTION_ZOOM_OUT, action_zoom_out);
        add_action_with_callback (Application.ACTION_ZOOM_DEFAULT, action_zoom_default);

        // Help actions
        add_action_with_callback (Application.ACTION_ABOUT, action_about);

        // Fuckton of bindings
        var app = (Application) application;
        app.set_accels_for_action ("win." + Application.ACTION_NEW, { "<Control>n" });
        app.set_accels_for_action ("win." + Application.ACTION_OPEN, { "<Control>o" });
        app.set_accels_for_action ("win." + Application.ACTION_SAVE, { "<Control>s" });
        app.set_accels_for_action ("win." + Application.ACTION_SAVE_AS, { "<Control><Shift>s" });
        app.set_accels_for_action ("win." + Application.ACTION_PRINT, { "<Control>p" });

        app.set_accels_for_action ("win." + Application.ACTION_UNDO, { "<Control>z" });
        app.set_accels_for_action ("win." + Application.ACTION_REDO, { "<Control>y" });
        app.set_accels_for_action ("win." + Application.ACTION_CUT, { "<Control>x" });
        app.set_accels_for_action ("win." + Application.ACTION_COPY, { "<Control>c" });
        app.set_accels_for_action ("win." + Application.ACTION_PASTE, { "<Control>v" });
        app.set_accels_for_action ("win." + Application.ACTION_DELETE, { "Delete" });
        app.set_accels_for_action ("win." + Application.ACTION_FIND, { "<Control>f" });
        app.set_accels_for_action ("win." + Application.ACTION_FIND_NEXT, { "F3" });
        app.set_accels_for_action ("win." + Application.ACTION_FIND_PREVIOUS, { "<Shift>F3" });
        app.set_accels_for_action ("win." + Application.ACTION_REPLACE, { "<Control>h" });
        app.set_accels_for_action ("win." + Application.ACTION_GO_TO, { "<Control>g" });
        app.set_accels_for_action ("win." + Application.ACTION_SELECT_ALL, { "<Control>a" });
        app.set_accels_for_action ("win." + Application.ACTION_TIME_DATE, { "F5" });

        app.set_accels_for_action ("win." + Application.ACTION_ZOOM_IN, { "<Control>plus", "<Control>equal" });
        app.set_accels_for_action ("win." + Application.ACTION_ZOOM_OUT, { "<Control>minus" });
        app.set_accels_for_action ("win." + Application.ACTION_ZOOM_DEFAULT, { "<Control>0" });
    }

    private void add_action_with_callback (string name, SimpleActionActivateCallback handler) {
        var action = new SimpleAction (name, null);
        action.activate.connect ((action, parameter) => handler (action, parameter));
        add_action (action);
    }

    // --- Signals ---------------------------------------------------------------------------------

    private void connect_signals () {
        buffer.modified_changed.connect (update_title);
        buffer.notify["cursor-position"].connect (update_status);

        // Ctrl+scroll to zoom
        var scroll_controller = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect ((dx, dy) => {
            var state = scroll_controller.get_current_event_state ();
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (dy < 0) {
                    action_zoom_in ();
                } else {
                    action_zoom_out ();
                }
                return true;
            }
            return false;
        });
        text_view.add_controller (scroll_controller);
    }

    // --- Status updates ---------------------------------------------------------------------------------

    private void update_title () {
        string name = current_file != null ? current_file.get_basename () : _("Untitled");
        string prefix = buffer.get_modified () ? "*" : "";
        title = "%s%s - %s".printf (prefix, name, _("ValaPad"));
    }

    private void update_status () {
        int line, col;
        compute_line_col (out line, out col);
        ln_label.label = _("Ln %d").printf (line);
        col_label.label = _("Col %d").printf (col);
        zoom_label.label = "%d%%".printf (zoom_percentage);
        line_ending_label.label = use_crlf ? "CRLF" : "LF";
        encoding_label.label = encoding_name;
    }

    private void compute_line_col (out int line, out int col) {
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, buffer.get_insert ());
        line = iter.get_line () + 1;
        col = iter.get_line_offset () + 1;
    }

    private void update_zoom_css () {
        string family = font_description.get_family () ?? "system-ui";
        family = family.replace ("\\", "\\\\").replace ("\"", "\\\"");

        double size = font_description.get_size () / (double) Pango.SCALE;
        size *= zoom_percentage / 100.0;
        string unit = font_description.get_size_is_absolute () ? "px" : "pt";

        font_provider.load_from_string ("""
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
            font_style_to_css (font_description.get_style ()),
            (int) font_description.get_weight (),
            font_stretch_to_css (font_description.get_stretch ()),
            font_variant_to_css (font_description.get_variant ())
        ));
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

    // --- File actions ---------------------------------------------------------------------------------

    private async void action_new () {
        if (!yield confirm_discard ()) {
            return;
        }

        buffer.text = "";
        current_file = null;
        use_crlf = false;
        encoding_name = "UTF-8";
        buffer.set_modified (false);
        update_title ();
        update_status ();
    }

    private async void action_open () {
        if (!yield confirm_discard ()) {
            return;
        }

        var dialog = new Gtk.FileDialog () {
            title = _("Open")
        };

        File? file = null;
        try {
            file = yield dialog.open (this, null);
        } catch (Error e) {
            if (!(e is Gtk.DialogError.CANCELLED) && !(e is Gtk.DialogError.DISMISSED)) {
                show_error (_("Open failed"), e.message);
            }
            return;
        }

        if (file != null) {
            open_file (file);
        }
    }

    public void open_file (File file) {
        try {
            uint8[] contents;
            file.load_contents (null, out contents, null);

            bool has_bom;
            bool repaired;
            string text = TextFileDecoder.decode (
                contents,
                out has_bom,
                out use_crlf,
                out repaired
            );

            if (repaired) {
                encoding_name = _("UTF-8 (invalid bytes replaced)");
            } else {
                encoding_name = has_bom ? "UTF-8-BOM" : "UTF-8";
            }

            buffer.text = text;
            current_file = file;
            buffer.set_modified (false);
            update_title ();
            update_status ();
        } catch (Error e) {
            show_error (_("Open failed"), e.message);
        }
    }

    private async void action_save () {
        if (current_file != null) {
            save_to_file (current_file);
        } else {
            yield save_as_async ();
        }
    }

    private async void action_save_as () {
        yield save_as_async ();
    }

    private async bool save_as_async () {
        var dialog = new Gtk.FileDialog () {
            title = _("Save As"),
            initial_name = current_file != null ? current_file.get_basename () : _("Untitled.txt")
        };

        File? file = null;
        try {
            file = yield dialog.save (this, null);
        } catch (Error e) {
            if (!(e is Gtk.DialogError.CANCELLED) && !(e is Gtk.DialogError.DISMISSED)) {
                show_error (_("Save failed"), e.message);
            }
            return false;
        }

        if (file == null) {
            return false;
        }

        save_to_file (file);
        return !buffer.get_modified ();
    }

    private void save_to_file (File file) {
        try {
            string text = buffer.text;
            if (use_crlf) {
                text = text.replace ("\n", "\r\n");
            }

            uint8[] contents = text.data;
            file.replace_contents (
                contents,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                null
            );

            current_file = file;
            buffer.set_modified (false);
            update_title ();
            update_status ();
        } catch (Error e) {
            show_error (_("Save failed"), e.message);
        }
    }

    private void action_print () {
        var print = new Gtk.PrintOperation ();
        print.print_settings = new Gtk.PrintSettings ();

        string[] lines = buffer.text.split ("\n");
        int lines_per_page = 50;

        print.begin_print.connect ((op, ctx) => {
            int n_pages = (lines.length + lines_per_page - 1) / lines_per_page;
            if (n_pages < 1) {
                n_pages = 1;
            }
            op.set_n_pages (n_pages);
        });

        print.draw_page.connect ((op, ctx, page_nr) => {
            var cr = ctx.get_cairo_context ();
            cr.set_source_rgb (0, 0, 0);

            var layout = ctx.create_pango_layout ();
            layout.set_font_description (Pango.FontDescription.from_string ("Sans 12"));

            int start = page_nr * lines_per_page;
            int end = int.min (start + lines_per_page, lines.length);

            var sb = new StringBuilder ();
            for (int i = start; i < end; i++) {
                sb.append (lines[i]);
                sb.append_c ('\n');
            }
            layout.set_text (sb.str, -1);
            cr.move_to (20, 20);
            Pango.cairo_show_layout (cr, layout);
        });

        try {
            print.run (Gtk.PrintOperationAction.PRINT_DIALOG, this);
        } catch (Error e) {
            show_error (_("Print failed"), e.message);
        }
    }

    // --- Edit actions ---------------------------------------------------------------------------------

    private void action_undo () {
        if (buffer.can_undo) {
            buffer.undo ();
        }
    }

    private void action_redo () {
        if (buffer.can_redo) {
            buffer.redo ();
        }
    }

    private void action_cut () {
        if (buffer.get_has_selection ()) {
            var clipboard = text_view.get_clipboard ();
            buffer.cut_clipboard (clipboard, text_view.get_editable ());
        }
    }

    private void action_copy () {
        if (buffer.get_has_selection ()) {
            var clipboard = text_view.get_clipboard ();
            buffer.copy_clipboard (clipboard);
        }
    }

    private void action_paste () {
        var clipboard = text_view.get_clipboard ();
        buffer.paste_clipboard (clipboard, null, text_view.get_editable ());
    }

    private void action_delete () {
        if (buffer.get_has_selection ()) {
            buffer.delete_selection (true, text_view.get_editable ());
        }
    }

    private void action_find () {
        find_bar.show_bar ();
    }

    private void action_go_to () {
        if (go_to_dialog == null) {
            go_to_dialog = new GoToDialog (this, text_view);
        }
        go_to_dialog.show_dialog ();
    }

    private void action_select_all () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        buffer.select_range (start, end);
    }

    private void action_time_date () {
        var now = new DateTime.now_local ();
        string stamp = now.format ("%H:%M %d/%m/%Y");
        buffer.begin_user_action ();
        buffer.delete_selection (true, text_view.get_editable ());
        buffer.insert_at_cursor (stamp, stamp.length);
        buffer.end_user_action ();
    }

    // --- Format actions ---------------------------------------------------------------------------------

    private void action_font () {
        if (font_dialog == null) {
            font_dialog = new FontDialog (this, font_description);
            font_dialog.font_selected.connect ((selected_font) => {
                font_description = selected_font;
                settings.set_string ("font", font_description.to_string ());
                update_zoom_css ();
            });
        } else {
            font_dialog.set_initial_font (font_description);
        }

        font_dialog.present ();
    }

    // --- View actions ---------------------------------------------------------------------------------

    // helper
    private void set_zoom (int value) {
        var new_zoom = value.clamp (MIN_ZOOM, MAX_ZOOM);
        if (new_zoom == zoom_percentage) {
            return;
        }
        zoom_percentage = new_zoom;
        update_zoom_css ();
        update_status ();
    }

    private void action_zoom_in () {
        set_zoom (zoom_percentage + 10);
    }

    private void action_zoom_out () {
        set_zoom (zoom_percentage - 10);
    }

    private void action_zoom_default () {
        set_zoom(100);
    }

    // --- Help actions ---------------------------------------------------------------------------------

    private void action_about () {
        var about = new Gtk.AboutDialog () {
            transient_for = this,
            modal = true,
            program_name = _("ValaPad"),
            version = Build.VERSION,
            comments = _("A lightweight plain-text editor."),
            license_type = Gtk.License.GPL_3_0,
            logo_icon_name = application.application_id,
            copyright = "© 2026 Iaroslav Angliuster and Contributers"
        };
        about.present ();
    }

    // --- Discard confirmation ---------------------------------------------------------------------------------

    private async bool confirm_discard () {
        if (!buffer.get_modified ()) {
            return true;
        }

        string name = current_file != null ? current_file.get_basename () : _("Untitled");
        var question = new Gtk.AlertDialog (
            _("Do you want to save changes to %s?").printf (name)
        );
        question.modal = true;
        question.buttons = { _("Save"), _("Don't Save"), _("Cancel") };
        question.cancel_button = 2;
        question.default_button = 0;

        int response;
        try {
            response = yield question.choose (this, null);
        } catch (Error e) {
            return false;
        }

        if (response == 0) {
            // Save
            if (current_file != null) {
                save_to_file (current_file);
                return !buffer.get_modified ();
            }
            return yield save_as_async ();
        } else if (response == 1) {
            // Don't Save
            return true;
        }

        return false; // Cancel
    }

    private void show_error (string title, string message) {
        var alert = new Gtk.AlertDialog ("%s: %s".printf (title, message));
        alert.modal = true;
        alert.detail = message;
        alert.show (this);
    }

    public override bool close_request () {
        if (confirmed_close) {
            return false; // allow close
        }
        if (!buffer.get_modified ()) {
            return false; // allow close
        }
        confirm_discard_and_close.begin ();
        return true; // prevent close
    }

    private async void confirm_discard_and_close () {
        if (yield confirm_discard ()) {
            confirmed_close = true;
            destroy ();
        }
    }
}
