const std = @import("std");
const arg_parser = @import("arg_parser.zig");

const ArgParser = arg_parser.ArgParser;
const heap = std.heap;
const print = std.debug.print;
const talloc = std.testing.allocator;

pub fn main() !u8 {
    print("--------------------------------------------------\n", .{});
    print("Main Console loaded\n", .{});
    // Create the configured allocator
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("MEMORY LEAK DETECTED");
        }
    }

    // Create an arg parser
    const parser = try ArgParser.init(&gpa.allocator);
    defer parser.deinit();

    return 0;
}

test "ArgParser is available to main" {
    const parser = try ArgParser.init(talloc, "abcd", "efgh");
    defer parser.deinit();
}
