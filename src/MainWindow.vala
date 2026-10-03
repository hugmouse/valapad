/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// TODO: decouple stuff from here since this class is insanely long
// TODO: document every single function
public class ValaPad.MainWindow : Gtk.ApplicationWindow {
    private const int BASE_FONT_PX = 14;
    private const int MIN_ZOOM = 10;
    private const int MAX_ZOOM = 500;
    private const int64 LARGE_FILE_BYTES = 3 * 1024 * 1024;

    private Gtk.TextView text_view;
    private Gtk.TextBuffer buffer;
    private Gtk.Label ln_label;
    private Gtk.Label col_label;
    private Gtk.Label zoom_label;
    private Gtk.Label line_ending_label;
    private Gtk.Label encoding_label;
    private Gtk.Revealer recovery_warning;
    private Gtk.Label recovery_warning_label;
    private Gtk.Spinner save_spinner;

    private Gtk.CssProvider font_provider;
    private Pango.FontDescription font_description;
    private FontDialog? font_dialog;
    private WordWrapController? word_wrap_controller;
    private Settings settings;
    private RecoveryStore recovery_store;
    private AutosaveController autosave_controller;

    private Document current = new Document ();
    private int zoom_percentage = 100;

    private FindBar? find_bar;
    private GoToDialog? go_to_dialog;

    private bool confirmed_close = false;
    private bool saving = false;

    public MainWindow (Gtk.Application app) {
        Object (
            application: app,
            default_height: 600,
            default_width: 800,
            title: _("Untitled - ValaPad")
        );

        recovery_store = new RecoveryStore ();
        build_ui ();
        restore_window_state ();
        autosave_controller = new AutosaveController (buffer, recovery_store);
        autosave_controller.save_failed.connect (show_recovery_warning);
        update_autosave_document ();
        add_window_actions ();
        connect_signals ();
        load_zoom ();
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

        recovery_warning_label = new Gtk.Label (null) {
            hexpand = true,
            wrap = true,
            xalign = 0
        };
        var dismiss_warning = new Gtk.Button.from_icon_name ("window-close-symbolic") {
            tooltip_text = _("Dismiss")
        };
        dismiss_warning.update_property (Gtk.AccessibleProperty.LABEL, _("Dismiss warning"));
        dismiss_warning.add_css_class ("flat");
        dismiss_warning.clicked.connect (() => recovery_warning.reveal_child = false);
        var warning_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 6
        };
        warning_box.append (recovery_warning_label);
        warning_box.append (dismiss_warning);
        recovery_warning = new Gtk.Revealer () {
            child = warning_box,
            reveal_child = false
        };
        recovery_warning.add_css_class ("warning");

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.append (menu_bar);
        main_box.append (recovery_warning);
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
        Css.add_provider (
            this,
            font_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        );

        var style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("/dev/mysh/valapad/style.css");
        Css.add_provider (
            this,
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }


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
        save_spinner = new Gtk.Spinner () {
            margin_start = 8,
            margin_end = 8,
            valign = Gtk.Align.CENTER,
            visible = false,
            spinning = false
        };
        save_spinner.update_property (Gtk.AccessibleProperty.LABEL, _("Saving"));

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box.add_css_class ("valapad-statusbar");
        box.append (save_spinner);
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
        add_action_with_callback (Application.ACTION_SAVE_AS, () => save_as_async.begin ());
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

        // Keyboard shortcuts
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
        buffer.notify["cursor-position"].connect (() => {
            update_status ();
            autosave_controller.schedule_cursor_update ();
        });

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

        // Escape closes the find bar; the search entry eats the key first
        var escape = EscapeController.attach (this, Gtk.PropagationPhase.CAPTURE);
        escape.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval != Gdk.Key.Escape || !find_bar.visible) {
                return false;
            }
            find_bar.hide_bar ();
            return true;
        });
    }

    // --- Status updates ---------------------------------------------------------------------------------

    private void update_title () {
        string name = current.display_name ();
        string prefix = buffer.get_modified () ? "*" : "";
        title = "%s%s - %s".printf (prefix, name, _("ValaPad"));
    }

    private void update_status () {
        int line, col;
        compute_line_col (out line, out col);
        ln_label.label = _("Ln %d").printf (line);
        col_label.label = _("Col %d").printf (col);
        zoom_label.label = "%d%%".printf (zoom_percentage);
        line_ending_label.label = current.use_crlf ? "CRLF" : "LF";
        encoding_label.label = current.encoding;
    }

    private void compute_line_col (out int line, out int col) {
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, buffer.get_insert ());
        line = iter.get_line () + 1;
        col = iter.get_line_offset () + 1;
    }

    private void update_zoom_css () {
        font_provider.load_from_string (FontCss.build (font_description, zoom_percentage));
    }

    // --- File actions ---------------------------------------------------------------------------------

    private void set_document (Document document, bool modified) {
        autosave_controller.suspend ();
        buffer.text = document.text;
        current = document;
        buffer.set_modified (modified);
        autosave_controller.resume ();
        update_autosave_document ();
        update_title ();
        update_status ();
    }

    private async void action_new () {
        if (saving) {
            return;
        }
        if (!yield confirm_discard ()) {
            return;
        }

        yield autosave_controller.reset ();
        set_document (Document.untitled (), false);
    }

    private async void action_open () {
        if (saving) {
            return;
        }
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
            if (!(e is Gtk.DialogError.CANCELLED || e is Gtk.DialogError.DISMISSED)) {
                show_error (_("Open failed"), e.message);
            }
            return;
        }

        if (file != null) {
            yield open_file (file);
        }
    }

    public async bool open_file (File file) {
        try {
            // Reject unsafe inputs from metadata and a small sample before the
            // complete file is allocated and decoded.
            FileInfo info = yield file.query_info_async (
                FileAttribute.STANDARD_TYPE + "," + FileAttribute.STANDARD_SIZE,
                FileQueryInfoFlags.NONE,
                Priority.DEFAULT,
                null
            );
            if (info.get_file_type () != FileType.REGULAR) {
                show_error (
                    _("Open failed"),
                    _("“%s” is not a regular file.").printf (file.get_parse_name ())
                );
                return false;
            }
            bool looks_like_text = yield file_looks_like_text (file);
            if (!looks_like_text) {
                string unsupported_message = _(
                    "“%s” does not appear to be a supported text file. Opening it may display corrupted text, " +
                    "and saving it could damage the file."
                ).printf (file.get_basename ());
                bool open_unsupported = yield confirm_open_anyway (unsupported_message);
                if (!open_unsupported) {
                    return false;
                }
            }
            if (info.get_size () >= LARGE_FILE_BYTES) {
                string large_message = _(
                    "“%s” is %s. Opening it may make ValaPad unresponsive and requires substantially more memory " +
                    "than the file size."
                ).printf (file.get_basename (), GLib.format_size ((uint64) info.get_size ()));
                bool open_large = yield confirm_open_anyway (large_message);
                if (!open_large) {
                    return false;
                }
            }

            uint8[] contents;
            string? etag;
            yield file.load_contents_async (null, out contents, out etag);

            set_document (Document.from_bytes (file, etag, contents), false);
        } catch (Error e) {
            show_error (_("Open failed"), e.message);
            return false;
        }
        return true;
    }

    private async bool file_looks_like_text (File file) throws Error {
        var stream = yield file.read_async (Priority.DEFAULT, null);
        uint8[] sample = new uint8[TextFileProbe.SAMPLE_BYTES];
        try {
            ssize_t bytes_read = yield stream.read_async (sample, Priority.DEFAULT, null);
            return TextFileProbe.is_probably_text (sample[0: (int) bytes_read]);
        } finally {
            try {
                stream.close (null);
            } catch (Error error) {
            }
        }
    }

    private async bool confirm_open_anyway (string message) {
        var alert = new Gtk.AlertDialog (message) {
            modal = true,
            buttons = { _("Cancel"), _("Open Anyway") },
            cancel_button = 0,
            default_button = 0
        };

        try {
            int response = yield alert.choose (this, null);
            return response == 1;
        } catch (Error error) {
            return false;
        }
    }

    private async void action_save () {
        if (saving) {
            return;
        }
        File? open_file = current.file;
        if (open_file != null) {
            yield save_to_file_async (open_file);
        } else {
            yield save_as_async ();
        }
    }

    private async bool save_as_async () {
        File? open_file = current.file;
        var dialog = new Gtk.FileDialog () {
            title = _("Save As"),
            initial_name = open_file != null ? open_file.get_basename () : _("Untitled.txt")
        };

        File? file = null;
        try {
            file = yield dialog.save (this, null);
        } catch (Error e) {
            if (!(e is Gtk.DialogError.CANCELLED || e is Gtk.DialogError.DISMISSED)) {
                show_error (_("Save failed"), e.message);
            }
            return false;
        }

        if (file == null) {
            return false;
        }

        yield save_to_file_async (file);
        return !buffer.get_modified ();
    }

    private async void save_to_file_async (File file) {
        if (saving) {
            return;
        }
        saving = true;
        debug ("Document save started: name=%s", file.get_basename ());

        if (!save_spinner.visible) {
            save_spinner.visible = true;
            save_spinner.start ();
        }
        try {
            bool recovery_flushed = yield autosave_controller.flush ();
            if (!recovery_flushed) {
                debug ("Document save continuing without a flushed recovery snapshot: name=%s", file.get_basename ());
            } else {
                debug ("Recovery snapshot flushed before document save: name=%s", file.get_basename ());
            }

            string saved_text = buffer.text;
            string text = current.to_file_text (saved_text);

            uint8[] contents = text.data;
            string? new_etag = null;
            debug (
                "Writing document file asynchronously: name=%s chars=%d bytes=%zu",
                file.get_basename (),
                (int) saved_text.char_count (),
                contents.length
            );
            yield file.replace_contents_async (
                contents,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                null,
                out new_etag
            );

            current = current.saved_as (file, new_etag, saved_text);
            debug ("Document file write completed: name=%s", file.get_basename ());
            update_autosave_document ();

            // The buffer can keep changing while the write is in flight.
            // Only clear the dirty flag when the buffer still matches what we wrote
            // and anything newer stays dirty and is re-backed-up below
            if (buffer.text == saved_text) {
                buffer.set_modified (false);
                yield autosave_controller.clear ();
                recovery_warning.reveal_child = false;
                debug ("Document save completed cleanly: name=%s", file.get_basename ());
            } else {
                debug (
                    "Document changed during file write: name=%s saved-chars=%d current-chars=%d",
                    file.get_basename (),
                    (int) saved_text.char_count (),
                    (int) buffer.text.char_count ()
                );
            }

            update_title ();
            update_status ();
        } catch (Error e) {
            debug ("Document save failed: name=%s error=%s", file.get_basename (), e.message);
            apply_recovery_outcome.begin (RecoveryDocumentOutcome.SAVE_FAILED);
            show_error (_("Save failed"), e.message);
        } finally {
            if (buffer.get_modified ()) {
                autosave_controller.schedule_now ();
            }
            save_spinner.stop ();
            save_spinner.visible = false;
            saving = false;
        }
    }

    private async void apply_recovery_outcome (RecoveryDocumentOutcome outcome) {
        if (RecoveryWorkflow.should_delete_snapshot (outcome)) {
            yield autosave_controller.clear ();
        }
    }

    private void get_print_metrics (Gtk.PrintContext ctx,
                                    out double margin_x,
                                    out double margin_y,
                                    out double content_width,
                                    out double content_height) {
        double dpi_x = ctx.get_dpi_x ();
        double dpi_y = ctx.get_dpi_y ();
        if (!(dpi_x > 0)) {
            dpi_x = 72.0;
        }
        if (!(dpi_y > 0)) {
            dpi_y = 72.0;
        }
        margin_x = PrintLayout.margin_px (dpi_x);
        margin_y = PrintLayout.margin_px (dpi_y);
        content_width = double.max (ctx.get_width () - 2.0 * margin_x, 1.0);
        content_height = double.max (ctx.get_height () - 2.0 * margin_y, 1.0);
    }

    private Pango.Layout create_print_layout (Gtk.PrintContext ctx, double content_width) {
        var layout = ctx.create_pango_layout ();
        layout.set_font_description (font_description);
        layout.set_width ((int) (content_width * Pango.SCALE));
        layout.set_wrap (Pango.WrapMode.WORD_CHAR);
        return layout;
    }

    private void action_print () {
        var print = new Gtk.PrintOperation ();
        print.print_settings = new Gtk.PrintSettings ();

        string[] lines = buffer.text.split ("\n");
        var page_starts = new GenericArray<int> ();

        print.begin_print.connect ((op, ctx) => {
            double margin_x, margin_y, content_width, content_height;
            get_print_metrics (ctx, out margin_x, out margin_y, out content_width, out content_height);

            // Measure with the same width/wrap/font as draw_page so wrapped
            // long lines occupy the visual height they will actually print.
            var measure = create_print_layout (ctx, content_width);

            int[] heights = new int[lines.length];
            for (int i = 0; i < lines.length; i++) {
                measure.set_text (lines[i], -1);
                int w, h;
                measure.get_pixel_size (out w, out h);
                heights[i] = int.max (h, 1);
            }

            page_starts.remove_range (0, page_starts.length);
            var starts = PrintLayout.paginate_by_heights (heights, (int) content_height);
            for (int i = 0; i < starts.length; i++) {
                page_starts.add (starts[i]);
            }

            op.set_n_pages (page_starts.length);
        });

        print.draw_page.connect ((op, ctx, page_nr) => {
            if (page_nr < 0 || page_nr >= page_starts.length) {
                return;
            }
            double margin_x, margin_y, content_width, content_height;
            get_print_metrics (ctx, out margin_x, out margin_y, out content_width, out content_height);

            var cr = ctx.get_cairo_context ();
            cr.set_source_rgb (0, 0, 0);

            var layout = create_print_layout (ctx, content_width);

            int start = page_starts[page_nr];
            int end = page_nr + 1 < page_starts.length ? page_starts[page_nr + 1] : lines.length;

            var sb = new StringBuilder ();
            for (int i = start; i < end; i++) {
                if (i > start) {
                    sb.append_c ('\n');
                }
                sb.append (lines[i]);
            }
            layout.set_text (sb.str, -1);

            cr.move_to (margin_x, margin_y);
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
    private void restore_window_state () {
        default_width = settings.get_int ("window-width").clamp (400, 10000);
        default_height = settings.get_int ("window-height").clamp (300, 10000);
        if (settings.get_boolean ("window-maximized")) {
            maximized = true;
        }
    }

    private void save_window_state () {
        settings.set_boolean ("window-maximized", maximized);
        if (!maximized) {
            settings.set_int ("window-width", get_width ());
            settings.set_int ("window-height", get_height ());
        }
    }

    private void load_zoom () {
        set_zoom (settings.get_int ("zoom-percentage"));
    }

    private void set_zoom (int value) {
        var new_zoom = value.clamp (MIN_ZOOM, MAX_ZOOM);
        if (new_zoom == zoom_percentage) {
            return;
        }
        zoom_percentage = new_zoom;
        settings.set_int ("zoom-percentage", zoom_percentage);
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
        set_zoom (100);
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
            website = "https://github.com/hugmouse/valapad",
            authors = { "Iaroslav Angliuster" },
            translator_credits = _("translator-credits"),
            copyright = "© 2026 Iaroslav Angliuster and Contributors"
        };
        about.present ();
    }

    // --- Discard confirmation ---------------------------------------------------------------------------------

    private async bool confirm_discard () {
        if (!buffer.get_modified ()) {
            return true;
        }

        string name = current.display_name ();
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
            File? open_file = current.file;
            if (open_file != null) {
                yield save_to_file_async (open_file);
                return !buffer.get_modified ();
            }
            return yield save_as_async ();
        } else if (response == 1) {
            // Don't Save
            yield apply_recovery_outcome (RecoveryDocumentOutcome.DONT_SAVE);
            return true;
        }

        yield apply_recovery_outcome (RecoveryDocumentOutcome.CLOSE_CANCELLED);
        return false; // Cancel
    }

    private void update_autosave_document () {
        autosave_controller.update_document (current);
    }

    private void show_recovery_warning (string message) {
        show_warning (_("Changes could not be backed up: %s").printf (message));
    }

    private void show_warning (string message) {
        recovery_warning_label.label = message;
        recovery_warning.reveal_child = true;
    }

    public void restore_snapshot (RecoverySnapshot snapshot) {
        debug (
            "Restoring recovery snapshot: id=%s chars=%d cursor=%d original-changed=%s",
            snapshot.id,
            (int) snapshot.text.char_count (),
            snapshot.cursor_offset,
            snapshot.original_changed.to_string ()
        );
        autosave_controller.adopt_recovery (snapshot.id);
        File? snapshot_file = snapshot.original_uri != null
            ? File.new_for_uri (snapshot.original_uri)
            : null;
        var recovered = new Document () {
            file = snapshot_file,
            etag = snapshot.original_etag,
            text = snapshot.text,
            use_crlf = snapshot.use_crlf,
            has_bom = snapshot.has_bom,
            encoding = snapshot.encoding_name
        };
        set_document (recovered, true);
        Gtk.TextIter cursor;
        buffer.get_iter_at_offset (out cursor, snapshot.cursor_offset.clamp (0, buffer.get_char_count ()));
        buffer.place_cursor (cursor);
        text_view.scroll_to_iter (cursor, 0.0, false, 0.0, 0.0);
        autosave_controller.schedule_now ();
        update_status ();
        string? conflict = RecoveryWorkflow.conflict_warning (
            snapshot,
            _("The original file changed after this backup was created. Use Save As to avoid replacing newer changes.")
        );
        if (conflict != null) {
            show_warning (conflict);
        }
    }

    private void show_error (string title, string message) {
        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
            title,
            message,
            "dialog-error",
            Gtk.ButtonsType.CLOSE
        ) {
            transient_for = this,
            modal = true
        };
        dialog.response.connect (() => dialog.destroy ());
        dialog.present ();
    }

    public override bool close_request () {
        save_window_state ();
        if (saving) {
            return true;
        }
        if (confirmed_close || !buffer.get_modified ()) {
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
