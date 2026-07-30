/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Lets the user recover or discard any subset of snapshots found at startup.
// Closing the window leaves every snapshot untouched for the next launch.
public class ValaPad.RecoveryDialog : Gtk.Window {
    public signal void recover_requested (RecoverySnapshot[] snapshots);
    public signal void discard_requested (RecoverySnapshot[] snapshots);
    public signal void dismissed ();

    private RecoverySnapshot[] snapshots;
    private Gtk.CheckButton[] checks = {};
    private bool completed;

    public RecoveryDialog (Gtk.Application application, RecoverySnapshot[] snapshots) {
        Object (
            application: application,
            title: _("Recover Documents"),
            modal: true,
            resizable: false,
            default_width: 520
        );
        this.snapshots = snapshots;
        build_ui ();
    }

    private void build_ui () {
        var title = new Gtk.Label (null) {
            xalign = 0,
            wrap = true
        };
        title.set_markup ("<b>%s</b>\n%s".printf (
            Markup.escape_text (_("ValaPad found unsaved changes.")),
            Markup.escape_text (_("Select the documents you want to recover."))
        ));

        var list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE
        };
        list.add_css_class ("boxed-list");

        foreach (RecoverySnapshot snapshot in snapshots) {
            var check = new Gtk.CheckButton () {
                active = true,
                valign = Gtk.Align.CENTER
            };
            checks += check;

            string date = new DateTime.from_unix_local (snapshot.saved_at).format ("%c");
            var name = new Gtk.Label (snapshot.display_name) {
                ellipsize = Pango.EllipsizeMode.MIDDLE,
                hexpand = true,
                xalign = 0
            };
            name.add_css_class ("heading");
            var details = new Gtk.Label (snapshot.original_changed
                ? _("%s — original file changed").printf (date)
                : date) {
                xalign = 0
            };
            details.add_css_class ("dim-label");

            var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            labels.append (name);
            labels.append (details);

            var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 9,
                margin_bottom = 9,
                margin_start = 12,
                margin_end = 12
            };
            row_box.append (check);
            row_box.append (labels);
            list.append (row_box);
        }

        var discard_button = new Gtk.Button.with_label (_("Discard Selected"));
        discard_button.clicked.connect (() => finish (false));
        var recover_button = new Gtk.Button.with_label (_("Recover Selected"));
        recover_button.add_css_class ("suggested-action");
        recover_button.clicked.connect (() => finish (true));

        var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END
        };
        buttons.append (discard_button);
        buttons.append (recover_button);

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 18) {
            margin_top = 18,
            margin_bottom = 18,
            margin_start = 18,
            margin_end = 18
        };
        content.append (title);
        content.append (list);
        content.append (buttons);
        child = content;
    }

    private void finish (bool recover) {
        var selected = new GenericArray<RecoverySnapshot> ();
        for (int i = 0; i < snapshots.length; i++) {
            if (checks[i].active) {
                selected.add (snapshots[i]);
            }
        }
        completed = true;
        if (recover) {
            recover_requested (selected.data);
        } else {
            discard_requested (selected.data);
        }
        destroy ();
    }

    public override bool close_request () {
        if (!completed) {
            completed = true;
            dismissed ();
        }
        return false;
    }
}
