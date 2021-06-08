const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Writer = std.io.Writer;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const print = std.debug.print;
const process = std.process;
const talloc = std.testing.allocator;

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
        print("\nArgParser.init() called\n", .{});
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

    pub fn parse(self: *ArgParser, input: []const u8) !void {}
};

test "ArgParser is instantiable" {
    var p = try ArgParser.init(talloc);
    p.exe_name = "abcd";
    p.exe_desc = "Runs the abc's";

    defer p.deinit();
    try expectEqualStrings(p.exe_name, "abcd");
    try expectEqualStrings(p.exe_desc, "Runs the abc's");
}

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

    try p.parse("abcd -foo");
}
