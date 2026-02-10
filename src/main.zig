const std = @import("std");
const nc = @import("ncurses.zig");
const data = @import("data.zig");
const layout = @import("layout.zig");
const functions = @import("functions.zig");

// --- Module state ---

var col: u16 = 1;
var row: u16 = 1;
var cur_x: c_int = 3;
var cur_y: c_int = 4;
var max_x: c_int = 0;
var max_y: c_int = 0;
var corner_row: u16 = 1;
var corner_col: u16 = 1;
var entry_size: usize = 0;
var table: *data.Table = undefined;

const allocator = std.heap.c_allocator;

fn win() nc.Window {
    return nc.stdScr();
}

// --- Entry point ---

pub fn main() void {
    _ = layout.initscr();
    layout.refresh();
    layout.setup();
    start();
}

fn start() void {
    layout.draw_size = 8;
    _ = layout.drawScreenyx();
    layout.drawAxes(1, 1);
    corner_row = 1;
    corner_col = 1;
    layout.refresh();

    win().mvAddStr(4, 3, "        ");
    layout.move(4, 3);
    cur_x = 3;
    cur_y = 4;
    row = 1;
    col = 1;

    const dims = nc.curScr().getDimensions();
    max_y = dims.rows;
    max_x = dims.cols;
    entry_size = @intCast(max_x - 12);
    layout.refresh();

    table = data.initTable(allocator) catch {
        layout.endwin();
        return;
    };

    input();

    _ = layout.getch();
    layout.endwin();
}

fn setIcon(r: u16, co: u16) void {
    layout.colorOn();
    const w = win();
    var buf: [3]u8 = undefined;
    const letters = functions.toChar(&buf, @as(usize, co) - 1);
    w.move(0, 1);
    if (co < 27) {
        w.addStr(" ");
    }
    w.addStr(letters);
    w.print("{d}  ", .{r});

    // Type indicator
    w.move(0, 6);
    if (table[r - 1][co - 1]) |cell| {
        switch (cell.data) {
            .integer, .float => w.addStr("<V>"),
            .label => w.addStr("<L>"),
        }
    } else {
        w.addStr("   ");
    }

    // Raw data display
    var raw_buf: [256]u8 = undefined;
    if (data.getRaw(r, co, table, &raw_buf)) |raw| {
        w.addStr("  ");
        w.addStr(raw);
        var i: usize = 11 + raw.len;
        while (i < @as(usize, @intCast(max_x))) : (i += 1) {
            w.addStr(" ");
        }
    } else {
        var i: usize = 9;
        while (i < @as(usize, @intCast(max_x))) : (i += 1) {
            w.addStr(" ");
        }
    }
    layout.colorOff();
}

fn entry(ch_init: c_int) void {
    var entry_line = std.mem.zeroes([256]u8);
    var typed: usize = 0;
    const w = win();

    layout.colorOn();
    w.move(2, 0);

    if (ch_init >= 32 and ch_init <= 122) {
        layout.colorOff();
        var i: usize = 1;
        while (i < @as(usize, @intCast(max_x))) : (i += 1) {
            w.addStr(" ");
        }
        w.move(2, 1);
        w.addCh(@intCast(ch_init));
        entry_line[typed] = @intCast(ch_init);
        typed += 1;
    }

    while (true) {
        const ch = layout.getch();
        if (ch == 10) break; // Enter
        if (ch == 127) {
            // Backspace
            if (typed > 0) {
                w.move(2, @intCast(typed));
                w.addStr(" ");
                w.move(2, @intCast(typed));
                entry_line[typed] = 0;
                typed -= 1;
            }
        } else if (ch == 27) {
            // Escape -- cancel
            return;
        } else if (ch >= 32 and ch <= 122 and typed < entry_size) {
            w.addCh(@intCast(ch));
            entry_line[typed] = @intCast(ch);
            typed += 1;
        } else if (ch == '\x1b') {
            // Arrow key inside entry -- consume and ignore
            _ = layout.getch();
            _ = layout.getch();
        }
    }

    // Clear entry line
    w.move(2, 0);
    {
        var i: usize = 0;
        while (i < @as(usize, @intCast(max_x))) : (i += 1) {
            w.addStr(" ");
        }
    }
    setIcon(row, col);
    layout.move(cur_y, cur_x);

    data.setData(entry_line[0..typed], row, col, table, allocator);
    fillIn(cur_y, cur_x, row, col);
    setIcon(row, col);
}

fn fillIn(fy: c_int, fx: c_int, fr: u16, fc: u16) void {
    layout.colorOn();
    const w = win();
    w.move(fy, fx);
    var buf: [64]u8 = undefined;
    const slice = data.printData(fr, fc, @intCast(layout.draw_size), table, &buf);
    w.addStr(slice);
    w.move(fy, fx);
}

fn refill(ry: c_int, rx: c_int, rr: u16, rc: u16) void {
    layout.colorOff();
    const w = win();
    w.move(ry, rx);
    var buf: [64]u8 = undefined;
    const slice = data.printData(rr, rc, @intCast(layout.draw_size), table, &buf);
    w.addStr(slice);
    w.move(ry, rx);
    layout.colorOn();
}

fn input() void {
    while (true) {
        const ch = layout.getch();
        if (ch == 0) break;

        if (ch == '\x1b') {
            _ = layout.getch(); // consume '['
            const real = layout.getch();

            if (real == 'A') {
                // Up
                if (row > 1 and row > corner_row) {
                    refill(cur_y, cur_x, row, col);
                    cur_y -= 1;
                    row -= 1;
                    fillIn(cur_y, cur_x, row, col);
                    setIcon(row, col);
                    layout.move(cur_y, cur_x);
                } else if (corner_row > 1) {
                    corner_row -= 1;
                    row -= 1;
                    layout.drawAxes(corner_row, corner_col);
                    layout.drawCells(corner_row, corner_col, max_y, max_x, layout.draw_size, table);
                    setIcon(row, col);
                    layout.move(cur_y, cur_x);
                    fillIn(cur_y, cur_x, row, col);
                }
            } else if (real == 'B') {
                // Down
                if (cur_y < max_y - 1) {
                    refill(cur_y, cur_x, row, col);
                    cur_y += 1;
                    row += 1;
                    fillIn(cur_y, cur_x, row, col);
                    setIcon(row, col);
                    layout.move(cur_y, cur_x);
                } else if (row < 254) {
                    corner_row += 1;
                    row += 1;
                    layout.drawAxes(corner_row, corner_col);
                    layout.drawCells(corner_row, corner_col, max_y, max_x, layout.draw_size, table);
                    fillIn(cur_y, cur_x, row, col);
                    setIcon(row, col);
                    layout.move(cur_y, cur_x);
                }
            } else if (real == 'C') {
                // Right
                if (cur_x <= max_x - (2 * layout.draw_size)) {
                    refill(cur_y, cur_x, row, col);
                    cur_x += layout.draw_size;
                    col += 1;
                    fillIn(cur_y, cur_x, row, col);
                    setIcon(row, col);
                    layout.move(cur_y, cur_x);
                } else if (col < 63) {
                    corner_col += 1;
                    col += 1;
                    layout.drawAxes(corner_row, corner_col);
                    layout.drawCells(corner_row, corner_col, max_y, max_x, layout.draw_size, table);
                    setIcon(row, col);
                    fillIn(cur_y, cur_x, row, col);
                    layout.move(cur_y, cur_x);
                }
            } else if (real == 'D') {
                // Left
                if (cur_x >= layout.draw_size) {
                    refill(cur_y, cur_x, row, col);
                    cur_x -= layout.draw_size;
                    col -= 1;
                    setIcon(row, col);
                    fillIn(cur_y, cur_x, row, col);
                    layout.move(cur_y, cur_x);
                } else if (col > 1) {
                    corner_col -= 1;
                    col -= 1;
                    layout.drawAxes(corner_row, corner_col);
                    layout.drawCells(corner_row, corner_col, max_y, max_x, layout.draw_size, table);
                    setIcon(row, col);
                    fillIn(cur_y, cur_x, row, col);
                    layout.move(cur_y, cur_x);
                }
            }
        } else if (ch <= 127) {
            entry(ch);
        }
    }
}
