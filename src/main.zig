const std = @import("std");

const lib = @import("minicowsay_lib");

const cowsay = lib.cowsay;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const c = gpa.deinit();
        if (c == .leak) {
            const stderr = std.io.getStdErr().writer();
            stderr.print("Memory leaked", .{}) catch {};
        }
    }

    var args = std.process.args();
    _ = args.skip();

    var allocator = gpa.allocator();

    var message = std.ArrayList(u8).init(allocator);
    defer message.deinit();

    while (args.next()) |arg| {
        try message.appendSlice(arg);
        try message.append(' ');
    }

    var message_slice: ?[]u8 = message.items;
    if (message_slice.?.len < 1) {
        message_slice = null;
    }

    const output = try cowsay(allocator, message_slice, .{});
    defer allocator.free(output);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{output});
}
