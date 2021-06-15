const Lexer = @import("lexer.zig").Lexer;
const std = @import("std");
const tokenizer = @import("tokenizer.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const print = std.debug.print;
const talloc = std.testing.allocator;
const tokenize = tokenizer.tokenize;

const ArgsList = ArrayList(Arg);

pub const ArgumentError = error{
    MissingExe,
    MissingFiles,
    InvalidFile,
    InvalidFiles,
};

pub const ArgType = enum {
    File,
    Flag,
    Integer,
    Float,
    String,
};

pub const Arg = struct {
    name: []const u8,
    arg_type: ArgType,
    short: []const u8 = "",
    desc: []const u8,
    is_req: bool,
};

pub const ArgParser = struct {
    allocator: *Allocator,
    args: ArgsList,
    exe_name: []const u8 = "",
    exe_desc: []const u8 = "",

    pub fn init(a: *Allocator) !*ArgParser {
        var parser = try a.create(ArgParser);
        var args = ArgsList.init(a);

        parser.* = ArgParser{
            .allocator = a,
            .args = args,
        };

        return parser;
    }

    pub fn append(self: *ArgParser, arg: Arg) !void {
        try self.args.append(arg);
    }

    pub fn appendArgs(self: *ArgParser, args: []Arg) !void {
        for (args) |arg| {
            try self.append(arg);
        }
    }

    pub fn deinit(self: *ArgParser) void {
        self.args.deinit();
        self.allocator.destroy(self);
    }

    pub fn usage(self: *ArgParser, buffer: anytype) !void {
        try fmt.format(buffer,
            \\{s} {s}
            \\Usage: {s}
            \\  Options:
        , .{ self.exe_name, self.exe_desc, self.exe_name });
    }

    // NOTE(lbayes): std.os.args are: [][*:0]u8, we need to provide
    // an easy way to convert this to a slice of []const u8.
    pub fn parse(self: *ArgParser, input: [][*:0]u8) !void {
        print("PARSER input: {s}\n", .{input});

        // for (input) |arg| {
        // }
        // var segment = input.next(self.allocator);
        // while (segment != null) : (segment = input.next()) {
        // print("Seg: {s}\n", .{segment});
        // }
    }
};

test "ArgParser append" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "makes everything just a little more difficult";

    defer p.deinit();

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "foo",
        .short = "f",
        .desc = "Foo the foo",
        .is_req = true,
    });

    try p.append(.{
        .arg_type = ArgType.String,
        .name = "bar",
        .short = "b",
        .desc = "Bar the bar",
        .is_req = false,
    });

    var buf: [512]u8 = undefined;
    var buf_stream = io.fixedBufferStream(&buf);
    var writer = buf_stream.writer();
    try p.usage(writer);
    var lines = mem.split(buf_stream.getWritten(), "\n");

    var line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "abcd makes everything just a little more difficult");

    line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "Usage: abcd");

    line = try lines.next() orelse error.Fail;
    try expectEqualStrings(line, "  Options:");

    var empty = lines.next();
    try expect(empty == null);
}

test "ArgParser.parse" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "makes everything just a little more difficult";

    defer p.deinit();

    try p.append(.{
        .name = "name",
        .short = "n",
        .desc = "Name for the parameter",
        .is_req = true,
        .arg_type = ArgType.String,
    });

    try p.append(.{
        .name = "flag",
        .short = "f",
        .desc = "Do it if present",
        .is_req = false,
        .arg_type = ArgType.Flag,
    });

    try p.append(.{
        .name = "color",
        .short = "c",
        .desc = "Set the color",
        .is_req = false,
        .arg_type = ArgType.String,
    });

    try p.append(.{
        .name = "unused",
        .short = "u",
        .desc = "Unused param",
        .is_req = false,
        .arg_type = ArgType.String,
    });

    var argv = [_][]const u8{
        "cmd",
        "--name=efgh",
        "--bigflag",
        "--color",
        "green",
    };

    var itr = try p.parse(argv[0..]);
}
