/// Zig-friendly bindings for ncurses.
/// Wraps the C API with Zig types, std.fmt printing, and a Window struct.
const std = @import("std");

const c = @cImport({
    @cInclude("ncurses.h");
});

// --- Attribute type ---

pub const Attr = c_int;

pub fn colorPair(n: c_int) Attr {
    return @intCast(@as(c_uint, @intCast(n)) << 8);
}

// --- Color constants ---

pub const color_black: c_short = c.COLOR_BLACK;
pub const color_blue: c_short = c.COLOR_BLUE;
pub const color_red: c_short = c.COLOR_RED;
pub const color_green: c_short = c.COLOR_GREEN;
pub const color_yellow: c_short = c.COLOR_YELLOW;
pub const color_magenta: c_short = c.COLOR_MAGENTA;
pub const color_cyan: c_short = c.COLOR_CYAN;
pub const color_white: c_short = c.COLOR_WHITE;

// --- Window struct ---

pub const Window = struct {
    ptr: *c.WINDOW,

    /// Move the cursor to (row, col) within this window.
    pub fn move(self: Window, row: c_int, col: c_int) void {
        _ = c.wmove(self.ptr, row, col);
    }

    /// Print a Zig-formatted string at the current cursor position.
    pub fn print(self: Window, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, fmt, args) catch return;
        self.addStr(str);
    }

    /// Print a Zig slice at the current cursor position.
    pub fn addStr(self: Window, str: []const u8) void {
        _ = c.waddnstr(self.ptr, str.ptr, @intCast(str.len));
    }

    /// Print a single character at the current cursor position.
    pub fn addCh(self: Window, ch: u8) void {
        _ = c.waddch(self.ptr, ch);
    }

    /// Move then print a Zig-formatted string.
    pub fn mvPrint(self: Window, row: c_int, col: c_int, comptime fmt: []const u8, args: anytype) void {
        self.move(row, col);
        self.print(fmt, args);
    }

    /// Move then print a slice.
    pub fn mvAddStr(self: Window, row: c_int, col: c_int, str: []const u8) void {
        self.move(row, col);
        self.addStr(str);
    }

    /// Turn on an attribute.
    pub fn attrOn(self: Window, attr: Attr) void {
        _ = c.wattron(self.ptr, attr);
    }

    /// Turn off an attribute.
    pub fn attrOff(self: Window, attr: Attr) void {
        _ = c.wattroff(self.ptr, attr);
    }

    /// Get the max number of rows in this window.
    pub fn getMaxY(self: Window) c_int {
        return c.getmaxy(self.ptr);
    }

    /// Get the max number of columns in this window.
    pub fn getMaxX(self: Window) c_int {
        return c.getmaxx(self.ptr);
    }

    /// Get dimensions as a struct.
    pub fn getDimensions(self: Window) struct { rows: c_int, cols: c_int } {
        return .{ .rows = self.getMaxY(), .cols = self.getMaxX() };
    }

    /// Read a single keypress (blocking).
    pub fn getCh(self: Window) c_int {
        return c.wgetch(self.ptr);
    }

    /// Refresh this window.
    pub fn refresh(self: Window) void {
        _ = c.wrefresh(self.ptr);
    }

    /// Fill n columns at current cursor with spaces using current attributes.
    pub fn hLine(self: Window, ch: u8, n: c_int) void {
        _ = c.whline(self.ptr, ch, n);
    }
};

// --- Global functions ---

/// Initialize the screen and return the standard screen window.
pub fn initScr() Window {
    return .{ .ptr = c.initscr().? };
}

/// Restore terminal to its original state.
pub fn endWin() void {
    _ = c.endwin();
}

/// Refresh the standard screen.
pub fn refresh() void {
    _ = c.refresh();
}

/// Disable echoing of typed characters.
pub fn noEcho() void {
    _ = c.noecho();
}

/// Set cursor visibility (0 = invisible, 1 = normal, 2 = very visible).
pub fn cursSet(visibility: c_int) void {
    _ = c.curs_set(visibility);
}

/// Initialize color support.
pub fn startColor() void {
    _ = c.start_color();
}

/// Define a custom color (r, g, b in 0-1000 range).
pub fn initColor(color: c_short, r: c_short, g_val: c_short, b_val: c_short) void {
    _ = c.init_color(color, r, g_val, b_val);
}

/// Define a color pair.
pub fn initPair(pair: c_short, fg: c_short, bg: c_short) void {
    _ = c.init_pair(pair, fg, bg);
}

/// Return the standard screen as a Window.
pub fn stdScr() Window {
    return .{ .ptr = c.stdscr.? };
}

/// Return the current screen as a Window (reflects what's actually on terminal).
pub fn curScr() Window {
    return .{ .ptr = c.curscr.? };
}

/// Read a keypress from the standard screen.
pub fn getCh() c_int {
    return c.getch();
}
