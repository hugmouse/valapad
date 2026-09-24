/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

public class ValaPad.EscapeController : Object {
    public static Gtk.EventControllerKey attach (Gtk.Widget widget, Gtk.PropagationPhase phase) {
        var controller = new Gtk.EventControllerKey () {
            propagation_phase = phase
        };
        widget.add_controller (controller);
        return controller;
    }

    // Not passed in as a handler: close () frees the closure while it runs.
    public static void dismiss_on_escape (Gtk.Window window) {
        var escape = attach (window, Gtk.PropagationPhase.BUBBLE);
        escape.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval != Gdk.Key.Escape) {
                return false;
            }
            window.close ();
            return true;
        });
    }
}
