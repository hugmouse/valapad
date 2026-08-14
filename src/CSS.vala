/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Stupid hack to avoid deprecation warning
public class ValaPad.Css : Object {
    [CCode (cname = "gtk_style_context_add_provider_for_display")]
    private static extern void add_provider_for_display (
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    public static void add_provider (Gtk.Widget widget, Gtk.StyleProvider provider, uint priority) {
        add_provider_for_display (widget.get_display (), provider, priority);
    }
}
