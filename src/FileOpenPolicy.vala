/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

// Centralizes the inexpensive checks performed before loading a whole file.
public class ValaPad.FileOpenPolicy : Object {
    public const int64 LARGE_FILE_BYTES = 3 * 1024 * 1024;

    public static bool is_regular_file (FileType file_type) {
        return file_type == FileType.REGULAR;
    }

    public static bool requires_confirmation (int64 size) {
        return size >= LARGE_FILE_BYTES;
    }
}
