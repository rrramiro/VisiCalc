const std = @import("std");

/// Converts a letter ('A'-'Z', case-insensitive) to its 0-based index.
pub fn toNum(c: u8) ?u8 {
    return if (std.ascii.isAlphabetic(c))
        std.ascii.toUpper(c) - 'A'
    else
        null;
}

/// Converts a 0-based column index to a spreadsheet label (A-Z, AA-AZ, ...).
/// Returns a slice into the provided buffer.
pub fn toChar(buf: *[3]u8, i: usize) []const u8 {
    if (i < 26) {
        buf[0] = 'A' + @as(u8, @intCast(i));
        buf[1] = 0;
        return buf[0..1];
    } else {
        buf[0] = 'A' + @as(u8, @intCast((i / 26) - 1));
        buf[1] = 'A' + @as(u8, @intCast(i % 26));
        buf[2] = 0;
        return buf[0..2];
    }
}

// --- Tests ---

const testing = std.testing;

test "toNum: uppercase letters" {
    try testing.expectEqual(@as(u8, 0), toNum('A').?);
    try testing.expectEqual(@as(u8, 25), toNum('Z').?);
    try testing.expectEqual(@as(u8, 12), toNum('M').?);
}

test "toNum: lowercase letters" {
    try testing.expectEqual(@as(u8, 0), toNum('a').?);
    try testing.expectEqual(@as(u8, 25), toNum('z').?);
}

test "toNum: non-alphabetic returns null" {
    try testing.expectEqual(null, toNum('0'));
    try testing.expectEqual(null, toNum(' '));
    try testing.expectEqual(null, toNum('@'));
}

test "toChar: single letter columns (0-25)" {
    var buf: [3]u8 = undefined;
    try testing.expectEqualStrings("A", toChar(&buf, 0));
    try testing.expectEqualStrings("Z", toChar(&buf, 25));
    try testing.expectEqualStrings("N", toChar(&buf, 13));
}

test "toChar: double letter columns (26+)" {
    var buf: [3]u8 = undefined;
    try testing.expectEqualStrings("AA", toChar(&buf, 26));
    try testing.expectEqualStrings("AB", toChar(&buf, 27));
    try testing.expectEqualStrings("AZ", toChar(&buf, 51));
    try testing.expectEqualStrings("BA", toChar(&buf, 52));
}

test "toNum and toChar are inverse for single letters" {
    var buf: [3]u8 = undefined;
    for (0..26) |i| {
        const label = toChar(&buf, i);
        try testing.expectEqual(@as(u8, @intCast(i)), toNum(label[0]).?);
    }
}
