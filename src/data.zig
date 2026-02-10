const std = @import("std");

pub const max_rows: usize = 256;
pub const max_cols: usize = 64;

pub const CellData = union(enum) {
    integer: i64,
    float: f64,
    label: []u8,
};

pub const Cell = struct {
    row: u16,
    col: u16,
    data: CellData,
};

pub const Table = [max_rows][max_cols]?*Cell;

pub fn initTable(allocator: std.mem.Allocator) !*Table {
    const table = try allocator.create(Table);
    @memset(std.mem.asBytes(table), 0);
    return table;
}

fn getOrCreateCell(
    table: *Table,
    row: u16,
    col: u16,
    allocator: std.mem.Allocator,
) ?*Cell {
    const r = row - 1;
    const c = col - 1;
    if (table[r][c]) |existing| {
        if (existing.data == .label) {
            allocator.free(existing.data.label);
        }
        return existing;
    } else {
        const cell = allocator.create(Cell) catch return null;
        cell.* = .{ .row = row, .col = col, .data = .{ .integer = 0 } };
        table[r][c] = cell;
        return cell;
    }
}

pub fn setData(
    input: []const u8,
    row: u16,
    col: u16,
    table: *Table,
    allocator: std.mem.Allocator,
) void {
    if (input.len == 0) return;

    if (input[0] == '"') {
        // Label: strip leading quote, optionally strip trailing quote
        var label_src = input[1..];
        if (label_src.len > 0 and label_src[label_src.len - 1] == '"') {
            label_src = label_src[0 .. label_src.len - 1];
        }
        const label_copy = allocator.alloc(u8, label_src.len) catch return;
        @memcpy(label_copy, label_src);

        const cell = getOrCreateCell(table, row, col, allocator) orelse return;
        cell.data = .{ .label = label_copy };
    } else if (std.mem.indexOfScalar(u8, input, '.') != null) {
        // Double
        const num = std.fmt.parseFloat(f64, input) catch return;
        const cell = getOrCreateCell(table, row, col, allocator) orelse return;
        cell.data = .{ .float = num };
    } else {
        // Integer: must start with a digit
        if (input[0] < '0' or input[0] > '9') return;
        const num = std.fmt.parseInt(i64, input, 10) catch return;
        const cell = getOrCreateCell(table, row, col, allocator) orelse return;
        cell.data = .{ .integer = num };
    }
}

fn rightJustify(out: []u8, content: []const u8) []const u8 {
    const len = @min(content.len, out.len);
    const pad = out.len - len;
    @memset(out[0..pad], ' ');
    @memcpy(out[pad..][0..len], content[0..len]);
    return out;
}

fn overflowIndicator(out: []u8) []const u8 {
    @memset(out[0 .. out.len - 3], ' ');
    out[out.len - 3] = '>';
    out[out.len - 2] = '>';
    out[out.len - 1] = '>';
    return out;
}

pub fn printData(
    row: u16,
    col: u16,
    draw_size: usize,
    table: *const Table,
    buf: []u8,
) []const u8 {
    const r = row - 1;
    const c = col - 1;

    if (table[r][c]) |cell| {
        switch (cell.data) {
            .label => |lbl| {
                return rightJustify(buf[0..draw_size], lbl[0..@min(lbl.len, draw_size)]);
            },
            .float => |val| {
                const limit = std.math.pow(f64, 10.0, @floatFromInt(draw_size));
                if (val >= limit) {
                    return overflowIndicator(buf[0..draw_size]);
                }
                var tmp: [64]u8 = undefined;
                const formatted = std.fmt.bufPrint(&tmp, "{d:.15}", .{val}) catch
                    return overflowIndicator(buf[0..draw_size]);
                const trimmed = std.mem.trimEnd(u8, formatted, "0");
                return rightJustify(buf[0..draw_size], trimmed);
            },
            .integer => |val| {
                const limit: i64 = @intFromFloat(std.math.pow(f64, 10.0, @floatFromInt(draw_size)));
                if (val >= limit) {
                    return overflowIndicator(buf[0..draw_size]);
                }
                var tmp: [24]u8 = undefined;
                const formatted = std.fmt.bufPrint(&tmp, "{d}", .{val}) catch
                    return overflowIndicator(buf[0..draw_size]);
                return rightJustify(buf[0..draw_size], formatted);
            },
        }
    } else {
        @memset(buf[0..draw_size], ' ');
        return buf[0..draw_size];
    }
}

pub fn getRaw(
    row: u16,
    col: u16,
    table: *const Table,
    buf: []u8,
) ?[]const u8 {
    const r = row - 1;
    const c = col - 1;
    const cell = table[r][c] orelse return null;

    switch (cell.data) {
        .label => |lbl| {
            const len = @min(lbl.len, buf.len);
            @memcpy(buf[0..len], lbl[0..len]);
            return buf[0..len];
        },
        .float => |val| {
            const formatted = std.fmt.bufPrint(buf, "{d:.15}", .{val}) catch return null;
            return std.mem.trimEnd(u8, formatted, "0");
        },
        .integer => |val| {
            return std.fmt.bufPrint(buf, "{d}", .{val}) catch null;
        },
    }
}

// --- Tests ---

const testing = std.testing;

test "initTable: all cells are null" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    for (0..max_rows) |r| {
        for (0..max_cols) |c| {
            try testing.expectEqual(null, table[r][c]);
        }
    }
}

test "setData: integer" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("42", 1, 1, table, testing.allocator);
    const cell = table[0][0].?;
    defer testing.allocator.destroy(cell);
    try testing.expectEqual(@as(i64, 42), cell.data.integer);
}

test "setData: float" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("3.14", 1, 1, table, testing.allocator);
    const cell = table[0][0].?;
    defer testing.allocator.destroy(cell);
    try testing.expectApproxEqAbs(@as(f64, 3.14), cell.data.float, 0.001);
}

test "setData: label" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("\"Hello\"", 1, 1, table, testing.allocator);
    const cell = table[0][0].?;
    defer {
        testing.allocator.free(cell.data.label);
        testing.allocator.destroy(cell);
    }
    try testing.expectEqualStrings("Hello", cell.data.label);
}

test "setData: ignores non-digit non-label" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("abc", 1, 1, table, testing.allocator);
    try testing.expectEqual(null, table[0][0]);
}

test "printData: empty cell" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    var buf: [64]u8 = undefined;
    const result = printData(1, 1, 8, table, &buf);
    try testing.expectEqualStrings("        ", result);
}

test "printData: integer right-justified" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("42", 1, 1, table, testing.allocator);
    defer testing.allocator.destroy(table[0][0].?);
    var buf: [64]u8 = undefined;
    const result = printData(1, 1, 8, table, &buf);
    try testing.expectEqualStrings("      42", result);
}

test "getRaw: returns null for empty cell" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    var buf: [64]u8 = undefined;
    try testing.expectEqual(null, getRaw(1, 1, table, &buf));
}

test "getRaw: returns integer string" {
    const table = try initTable(testing.allocator);
    defer testing.allocator.destroy(table);
    setData("99", 1, 1, table, testing.allocator);
    defer testing.allocator.destroy(table[0][0].?);
    var buf: [64]u8 = undefined;
    const result = getRaw(1, 1, table, &buf).?;
    try testing.expectEqualStrings("99", result);
}
