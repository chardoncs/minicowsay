const std = @import("std");

const Allocator = std.mem.Allocator;

const COW_TEMPLATE =
    \\        $thoughts   ^__^
    \\         $thoughts  ($eyes)\\_______
    \\            (__)\\       )\\/\\
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

const HORIZONTAL_BOUNDARY = '_';

const MAX_WIDTH = 100;

const CowsayOptions = struct {
    eyes: []const u8,
    thought_slash: []const u8,
    tongue: []const u8,
};

fn parseOptions(input: anytype) CowsayOptions {
    const InputType = @TypeOf(input);
    const inputType = @typeInfo(InputType);

    var result = CowsayOptions{
        .eyes = "",
        .thought_slash = "\\",
        .tongue = "",
    };

    switch (inputType) {
        .@"struct" => |struct_info| {
            if (@hasField(InputType, "eyes")) {
                result.eyes = @field(struct_info, "eyes");
            }

            if (@hasField(InputType, "thought_slash")) {
                result.thought_slash = @field(struct_info, "thought_slash");
            }

            if (@hasField(InputType, "tongue")) {
                result.tongue = @field(struct_info, "tongue");
            }
        },
        else => {
            @compileError("Failed parsing the type: " ++ @typeName(InputType));
        },
    }

    return result;
}

const CharArrayList = std.ArrayList(u8);

fn parseToken(token: []const u8, opt: *const CowsayOptions) *const []u8 {
    if (std.mem.eql(u8, token, "thoughts")) {
        return opt.thought_slash;
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

fn wrapLines(allocator: Allocator, message: []const u8) Allocator.Error!LineWrapReturn {
    var line_list = std.ArrayList([]const u8).init(allocator);

    var start: usize = 0;
    var end: usize = 0;

    var i: usize = 0;

    var max_width: usize = 0;

    while (i < message.len) : (i += 1) {
        const ch = message[i];

        switch (ch) {
            ' ' => {
                end = i;
            },
            '\n' => {
                end = i;
                try line_list.append(message[start..end]);
                start = end + 1;
            },
            0 => {
                break;
            },
            else => {
                const w = i - start;
                if (w > MAX_WIDTH) {
                    var break_word: bool = false;

                    break_word = end - start < MAX_WIDTH / 2;

                    var line_width = end - start;

                    if (line_width < MAX_WIDTH / 2) {
                        end = i;
                        line_width = w;
                    }

                    try line_list.append(message[start..end]);
                    if (max_width < line_width) {
                        max_width = line_width;
                    }

                    start = end;
                }
            },
        }
    }

    try line_list.append(message[start..i]);

    return .{
        .lines = try line_list.toOwnedSlice(),
        .max_width = max_width,
    };
}

fn addHorizontalBoundary(out_list: *CharArrayList, width: u32) Allocator.Error!void {
    if (width < 3) {
        return;
    }

    try out_list.append(' ');
    try out_list.appendNTimes(HORIZONTAL_BOUNDARY, width - 2);
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
    const width = MAX_WIDTH;

    const ret = try wrapLines(allocator, message);
    const lines = ret.lines;
    defer allocator.free(lines);

    try addHorizontalBoundary(out_list, width);

    var line_idx: usize = 0;
    while (line_idx < lines.len) : (line_idx += 1) {
        try out_list.append(matchBoundary(lines.len, line_idx, LEFT_BOUNDARY, TOP_LEFT_BOUNDARY, BOTTOM_LEFT_BOUNDARY, CONTINUE_BOUNDARY));

        try out_list.appendSlice(lines[line_idx]);

        try out_list.append(matchBoundary(lines.len, line_idx, RIGHT_BOUNDARY, TOP_RIGHT_BOUNDARY, BOTTOM_RIGHT_BOUNDARY, CONTINUE_BOUNDARY));
    }

    try addHorizontalBoundary(out_list, width);
}

pub fn cowsay(allocator: Allocator, message: ?[]const u8, opt: anytype) Allocator.Error![:0]u8 {
    const options = parseOptions(opt);

    var output = CharArrayList.init(allocator);
    var buffer: [41:0]u8 = undefined;

    if (message) |msg| {
        try parseBubble(allocator, &output, msg);
    }

    var i: usize = 0;
    while (i < COW_TEMPLATE.len) : (i += 1) {
        const ch = COW_TEMPLATE[i];
        switch (ch) {
            '$' => {
                var bi: usize = 0;
                var j: usize = i + 1;

                while (j < COW_TEMPLATE.len and bi < buffer.len - 1) : (j += 1) {
                    const token_ch = COW_TEMPLATE[j];
                    switch (token_ch) {
                        'a'...'z', 'A'...'Z', '0'...'9' => {
                            buffer[bi] = token_ch;
                            bi += 1;
                        },
                        else => {
                            break;
                        },
                    }
                }

                buffer[bi] = 0;

                const result = try parseToken(buffer, &options);
                try output.appendSlice(result);
            },
            0 => {
                break;
            },
            else => {
                try output.append(ch);
            },
        }
    }

    try output.append(0);
    return try output.toOwnedSlice();
}
