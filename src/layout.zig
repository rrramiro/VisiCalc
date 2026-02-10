const std = @import("std");
const nc = @import("ncurses.zig");
const data = @import("data.zig");
const functions = @import("functions.zig");

// --- Module state ---

pub var draw_size: c_int = 8;
var x_start: c_int = 0;
var y_start: c_int = 0;

// --- Public functions ---

pub fn colorOn() void {
    const win = nc.stdScr();
    win.attrOff(nc.colorPair(1));
    win.attrOn(nc.colorPair(2));
}

pub fn colorOff() void {
    const win = nc.stdScr();
    win.attrOff(nc.colorPair(2));
    win.attrOn(nc.colorPair(1));
}

pub fn drawAxes(yn: u16, xn: u16) void {
    const adj_xn = xn - 1;
    const adj_yn = yn - 1;
    x_start = adj_xn;
    y_start = adj_yn;
    const win = nc.stdScr();
    const dims = nc.curScr().getDimensions();

    // Draw row numbers
    win.move(4, 0);
    var b: c_int = 4;
    win.attrOn(nc.colorPair(2));
    var a = adj_yn + 1;
    while (a < dims.rows - 3 + adj_yn) : (a += 1) {
        win.print("{d: >3}", .{a});
        b += 1;
        win.move(b, 0);
    }

    // Draw column headers
    win.move(3, 3);
    var k: c_int = 0;
    while ((k + 1) * draw_size + 3 < dims.cols) {
        var buf: [3]u8 = undefined;
        const col_idx: usize = @intCast(k + adj_xn);
        const letters = functions.toChar(&buf, col_idx);

        var j: c_int = 0;
        while (j < draw_size) : (j += 1) {
            if (col_idx < 26) {
                if (j != @divTrunc(draw_size, 2)) {
                    win.addStr(" ");
                } else {
                    win.addStr(letters);
                }
            } else {
                if (j != @divTrunc(draw_size - 1, 2)) {
                    win.addStr(" ");
                } else {
                    win.addStr(letters);
                    j += 1;
                }
            }
        }
        k += 1;
    }
}

pub fn drawCells(
    row: u16,
    col: u16,
    max_y: c_int,
    max_x: c_int,
    ds: c_int,
    table: *const data.Table,
) void {
    const draw_count: usize = @intCast(@divTrunc(max_x - 3, ds));
    colorOff();
    const win = nc.stdScr();
    var print_buf: [64]u8 = undefined;
    for (0..@intCast(max_y - 4)) |i| {
        win.move(@intCast(4 + @as(c_int, @intCast(i))), 3);
        for (0..draw_count) |j| {
            const slice = data.printData(
                row + @as(u16, @intCast(i)),
                col + @as(u16, @intCast(j)),
                @intCast(ds),
                table,
                &print_buf,
            );
            win.addStr(slice);
        }
    }
}

pub fn drawScreenyx() c_int {
    const win = nc.stdScr();
    const dims = nc.curScr().getDimensions();

    win.move(0, 0);
    nc.startColor();
    nc.initColor(nc.color_black, 187, 39, 141);
    nc.initColor(nc.color_blue, 334, 627, 845);
    nc.initPair(2, nc.color_black, nc.color_blue);
    nc.initPair(1, nc.color_blue, nc.color_black);
    win.attrOn(nc.colorPair(2));

    win.addStr("  A1      ");

    for (6..@intCast(dims.cols)) |_| {
        win.addStr(" ");
    }
    win.move(1, 0);
    for (0..@intCast(dims.cols)) |_| {
        win.addStr(" ");
    }
    win.attrOff(nc.colorPair(2));
    win.attrOn(nc.colorPair(1));
    for (0..@intCast(dims.cols)) |_| {
        win.addStr(" ");
    }
    win.attrOff(nc.colorPair(1));
    win.attrOn(nc.colorPair(2));

    win.addStr("   ");
    drawAxes(1, 1);
    nc.refresh();
    return 0;
}

pub fn setup() void {
    nc.noEcho();
    nc.cursSet(0);
    draw_size = 8;
}

pub fn initscr() nc.Window {
    return nc.initScr();
}

pub fn endwin() void {
    nc.endWin();
}

pub fn move(y: c_int, x: c_int) void {
    nc.stdScr().move(y, x);
}

pub fn refresh() void {
    nc.refresh();
}

pub fn getch() c_int {
    return nc.getCh();
}
