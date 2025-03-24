const std = @import("std");

const lib = @import("minicowsay_lib");

const cowsay = lib.cowsay;

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();

    const args = std.process.args();
    _ = args.skip();

    var message = std.ArrayList(u8).init(gpa.allocator());
    defer message.deinit();

    while (args.next()) |arg| {
        try message.appendSlice(arg);
    }

    const allocator = gpa.allocator();
    const output = try cowsay(allocator, &message.items, .{});
    defer allocator.free(output);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{output});
}
