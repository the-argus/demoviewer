///
/// Functions relating to the CLI interface of demoviewer
///
const std = @import("std");
const builtin = @import("builtin");
const clap = @import("clap");
const dem_io = @import("read_dem.zig");
const log = std.log.scoped(.demoviewer);

const default_tf_path = ".steam/steam/steamapps/common/Team Fortress 2/tf";
const map_folders = [_][]const u8{ "maps", "download/maps" };

const params = clap.parseParamsComptime(
    \\-h, --help                Display this help and exit.
    \\-p, --printheader         Print only the header of the specified demo file and exit.
    \\-m, --mapfile <str>       Override the map specified by the demo file.
    \\-b, --bspinfo             Print the information of the selected map and exit.
    \\-t, --tfpath <str>        Path to your tf folder.
    \\<str>...
    \\
);

const CLIError = error{
    BadMap,
    NoHome,
};

pub const Input = struct {
    print_only_header: bool,
    print_only_map_info: bool,
    map_file: ?[]const u8,
    demo_file: ?[]const u8,
    tf_path: ?[]const u8,
};

pub const CLIState = struct {
    parsed_args: clap.Result(clap.Help, &params, clap.parsers.default),
    input: ?Input = null,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        self.parsed_args.deinit();
        if (self.input == null) {
            return;
        }
        if (self.input.?.map_file) |string| {
            allocator.free(string);
        }
    }

    pub fn print_help_if_needed(self: @This()) !void {
        if (self.parsed_args.args.help > 0) {
            return print_help();
        }
    }

    /// Try to get only the required input
    pub fn stage1(self: *@This()) !void {
        self.*.input = gather_required_input(&self.parsed_args);
        if (self.*.input == null) {
            return print_help();
        }
    }

    /// Get the tfpath and map file path
    pub fn stage2(self: *@This(), allocator: std.mem.Allocator) !void {
        // TODO: this is garbage. add detection to see if the CLI input is an absolute or relative patha
        // before doing this concatenation.
        std.debug.assert(self.input != null);
        self.*.input.?.map_file = if (self.*.parsed_args.args.mapfile) |mapfile| block: {
            // mapfile supplied specifically, just append the name to the CWD
            var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const cwd = try std.os.getcwd(&buf);
            break :block try std.fs.path.join(allocator, &[_][]const u8{ cwd, mapfile });
        } else block: {
            // try to find the path the map
            break :block try get_map_absolute_path(allocator, &self.*.input.?, &self.*.parsed_args);
        };
    }
};

pub fn initialize_cli() !CLIState {
    return .{ .parsed_args = try parse_args() };
}

pub fn print_help() !void {
    return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
}

fn parse_args() !clap.Result(clap.Help, &params, clap.parsers.default) {
    var diag: clap.Diagnostic = .{};
    var parse_options: clap.ParseOptions = .{};
    if (builtin.mode == .Debug) {
        diag = clap.Diagnostic{};
        parse_options = .{ .diagnostic = &diag };
    }
    return clap.parse(clap.Help, &params, clap.parsers.default, parse_options) catch |err| {
        if (builtin.mode == .Debug) {
            // Report useful error and exit
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        } else {
            log.err("Unable to parse command line arguments.", .{});
            return print_help();
        }
    };
}

fn gather_required_input(parsed_args: anytype) ?Input {
    var input: Input = .{
        .print_only_header = false,
        .print_only_map_info = false,
        .map_file = null,
        .demo_file = null,
        .tf_path = default_tf_path,
    };

    input.print_only_header = parsed_args.*.args.printheader > 0;
    input.print_only_map_info = parsed_args.*.args.bspinfo > 0;

    const demo_file_supplied = parsed_args.*.positionals.len > 0;
    if (demo_file_supplied) {
        input.demo_file = parsed_args.*.positionals[0];
    } else if (!input.print_only_map_info) {
        log.err("No positional arguments provided. Need demo file.", .{});
        return null;
    }
    return input;
}

fn get_map_absolute_path(allocator: std.mem.Allocator, input: *Input, parsed_args: anytype) ![]u8 {
    if (parsed_args.*.args.tfpath) |tfpath| {
        input.*.tf_path = tfpath;
    }

    // get map basename
    const map_name_from_header = label: {
        const demo_file = try dem_io.open_demo(input.*.demo_file.?);
        const header = try dem_io.read_header(demo_file);
        break :label dem_io.get_slice_from_cstring(&header.map_name);
    };

    // concatenate basename and dirname
    const map_file_abs_path = block: {
        const homedir = std.os.getenv("HOME");
        if (homedir == null) {
            log.err("You somehow don't have a $HOME directory...", .{});
            return CLIError.NoHome;
        }
        const joined = try std.fs.path.join(allocator, &[_][]const u8{ homedir.?, input.*.tf_path.?, map_name_from_header });
        defer allocator.free(joined);
        const joined_with_ext = try std.mem.concat(allocator, u8, &[_][]const u8{ joined, ".bsp" });
        break :block joined_with_ext;
    };

    // make sure file exists
    const map_file = std.fs.openFileAbsolute(map_file_abs_path, .{ .mode = .read_only }) catch |err| {
        log.err("Failed to open mapfile {s}: {any}", .{ map_file_abs_path, err });
        log.info("If the attempted path looks wrong, try passing in --tfpath or --mapfile", .{});
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        allocator.free(map_file_abs_path);
        return CLIError.BadMap;
    };
    map_file.close();
    return map_file_abs_path;
}
