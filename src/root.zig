const std = @import("std");

const Allocator = std.mem.Allocator;

const COW_TEMPLATE =
    \\        $thoughts   ^__^
    \\         $thoughts  ($eyes)\_______
    \\            (__)\       )\/\
    \\             $tongue ||----w |
    \\                ||     ||
;

const LEFT_BOUNDARY = '<';
const RIGHT_BOUNDARY = '>';

const TOP_LEFT_BOUNDARY = '/';
const BOTTOM_LEFT_BOUNDARY = '\\';
const TOP_RIGHT_BOUNDARY = '\\';
const BOTTOM_RIGHT_BOUNDARY = '/';

const CONTINUE_BOUNDARY = '|';

const TOP_HORIZONTAL_BOUNDARY = '_';
const BOTTOM_HORIZONTAL_BOUNDARY = '-';

const MAX_WIDTH = 45;

const CowsayOptions = struct {
    eyes: []const u8,
    thoughts: []const u8,
    tongue: []const u8,
};

fn parseOptions(input: anytype) CowsayOptions {
    const InputType = @TypeOf(input);
    const inputType = @typeInfo(InputType);

    var result = CowsayOptions{
        .eyes = "oo",
        .thoughts = "\\",
        .tongue = "  ",
    };

    switch (inputType) {
        .@"struct" => {
            if (@hasField(InputType, "eyes")) {
                if (@as(?[*:0]const u8, @ptrCast(@field(input, "eyes")))) |eyes| {
                    result.eyes = std.mem.span(eyes);
                }
            }

            if (@hasField(InputType, "thoughts")) {
                if (@as(?[*:0]const u8, @ptrCast(@field(input, "thoughts")))) |thoughts| {
                    result.thoughts = std.mem.span(thoughts);
                }
            }

            if (@hasField(InputType, "tongue")) {
                if (@as(?[*:0]const u8, @ptrCast(@field(input, "tongue")))) |tongue| {
                    result.tongue = std.mem.span(tongue);
                }
            }
        },
        else => {
            @compileError("Failed parsing the type: " ++ @typeName(InputType));
        },
    }

    return result;
}

const CharArrayList = std.ArrayList(u8);

fn parseToken(token: [:0]const u8, opt: *const CowsayOptions) []const u8 {
    if (std.mem.eql(u8, token, "thoughts")) {
        return opt.thoughts;
    }

    if (std.mem.eql(u8, token, "eyes")) {
        return opt.eyes;
    }

    if (std.mem.eql(u8, token, "tongue")) {
        return opt.tongue;
    }

    return token;
}

const LineWrapReturn = struct {
    lines: [][]const u8,
    max_width: usize,
};

fn updateMaxLineWidth(cur_max: usize, start: usize, end: usize) usize {
    const width = end - start;

    if (cur_max < width) {
        return width;
    }

    return cur_max;
}

fn wrapLines(allocator: Allocator, message: []const u8) Allocator.Error!LineWrapReturn {
    var line_list = std.ArrayList([]const u8).init(allocator);

    var start: usize = 0;
    var end: usize = 0;

    var i: usize = 0;

    var max_line_width: usize = 0;
    const max_width = MAX_WIDTH - 4;

    while (i < message.len) : (i += 1) {
        switch (message[i]) {
            ' ' => {
                end = i;
            },
            '\n' => {
                end = i;
                try line_list.append(message[start..end]);
                max_line_width = updateMaxLineWidth(max_line_width, start, end);
                end += 1;
                start = end;
            },
            0 => {
                break;
            },
            else => {
                const w = i - start;
                if (w > max_width) {
                    var line_width = end - start;

                    const break_word = end - start < max_width / 2;
                    if (line_width < max_width / 2 or break_word) {
                        end = i;
                        line_width = w;
                    }

                    try line_list.append(message[start..end]);
                    max_line_width = updateMaxLineWidth(max_line_width, start, end);

                    start = end;
                }
            },
        }
    }

    try line_list.append(message[start..i]);
    max_line_width = updateMaxLineWidth(max_line_width, start, i);

    return .{
        .lines = try line_list.toOwnedSlice(),
        .max_width = max_line_width,
    };
}

const BoundaryPosition = enum {
    top,
    bottom,
};

fn addHorizontalBoundary(pos: BoundaryPosition, out_list: *CharArrayList, width: usize) Allocator.Error!void {
    if (width < 3) {
        return;
    }

    try out_list.append(' ');
    try out_list.appendNTimes(switch (pos) {
        .top => TOP_HORIZONTAL_BOUNDARY,
        .bottom => BOTTOM_HORIZONTAL_BOUNDARY,
    }, width - 2);
    try out_list.append('\n');
}

fn matchBoundary(line_count: usize, line_idx: usize, b: u8, top_b: u8, bottom_b: u8, cont_b: u8) u8 {
    var ret: u8 = ' ';

    switch (line_count) {
        1 => ret = b,
        else => {
            switch (line_idx) {
                0 => ret = top_b,
                else => {
                    if (line_idx == line_count - 1) {
                        ret = bottom_b;
                    } else {
                        ret = cont_b;
                    }
                },
            }
        },
    }

    return ret;
}

fn parseBubble(allocator: Allocator, out_list: *CharArrayList, message: []const u8) Allocator.Error!void {
    const ret = try wrapLines(allocator, message);
    const lines = ret.lines;
    defer allocator.free(lines);

    const max_bubble_width = ret.max_width + 4;
    try addHorizontalBoundary(.top, out_list, max_bubble_width);

    var line_idx: usize = 0;
    while (line_idx < lines.len) : (line_idx += 1) {
        try out_list.append(matchBoundary(lines.len, line_idx, LEFT_BOUNDARY, TOP_LEFT_BOUNDARY, BOTTOM_LEFT_BOUNDARY, CONTINUE_BOUNDARY));
        try out_list.append(' ');

        try out_list.appendSlice(lines[line_idx]);

        const printed_len = lines[line_idx].len + 2;
        try out_list.appendNTimes(' ', max_bubble_width - printed_len - 1);

        try out_list.append(matchBoundary(lines.len, line_idx, RIGHT_BOUNDARY, TOP_RIGHT_BOUNDARY, BOTTOM_RIGHT_BOUNDARY, CONTINUE_BOUNDARY));
        try out_list.append('\n');
    }

    try addHorizontalBoundary(.bottom, out_list, max_bubble_width);
}

pub fn cowsay(allocator: Allocator, message: ?[]const u8, opt: anytype) Allocator.Error![]u8 {
    var options = parseOptions(opt);

    var output = CharArrayList.init(allocator);
    var buffer: [41:0]u8 = undefined;

    if (message) |msg| {
        try parseBubble(allocator, &output, msg);
    } else {
        options.thoughts = " ";
    }

    var i: usize = 0;
    while (i < COW_TEMPLATE.len) : (i += 1) {
        switch (COW_TEMPLATE[i]) {
            '$' => {
                var bi: usize = 0;
                var j: usize = i + 1;

                while (j < COW_TEMPLATE.len and bi < buffer.len - 1) : (j += 1) {
                    switch (COW_TEMPLATE[j]) {
                        'a'...'z', 'A'...'Z', '0'...'9' => |token_ch| {
                            buffer[bi] = token_ch;
                            bi += 1;
                        },
                        else => {
                            break;
                        },
                    }
                }

                buffer[bi] = 0;

                const result = parseToken(buffer[0..bi :0], &options);
                try output.appendSlice(result);

                i = j - 1;
            },
            0 => {
                break;
            },
            else => |ch| {
                try output.append(ch);
            },
        }
    }

    try output.append(0);
    return try output.toOwnedSlice();
}
