//
// Quiz Time!
//
// Let's revisit the Hermit's Map from Quiz 7.
//
// Oh, don't worry, it's not nearly as big without all the
// explanatory comments. And we're only going to change one part
// of it.
//
const std = @import("std");
const print = std.debug.print;

const TripError = error{ Unreachable, EatenByAGrue };

const Place = struct {
    name: []const u8,
    paths: []const Path = undefined,
};

var a = Place{ .name = "Archer's Point" };
var b = Place{ .name = "Bridge" };
var c = Place{ .name = "Cottage" };
var d = Place{ .name = "Dogwood Grove" };
var e = Place{ .name = "East Pond" };
var f = Place{ .name = "Fox Pond" };

// Remember how we didn't have to declare the numeric type of the
// place_count because it is only used at compile time? That
// probably makes a lot more sense now. :-)
const place_count = 6;

const Path = struct {
    from: *const Place,
    to: *const Place,
    dist: u8,
};

// Okay, so as you may recall, we had to create each Path struct
// by hand and each one took 5 lines of code to define:
//
//    Path{
//        .from = &a, // from: Archer's Point
//        .to = &b,   //   to: Bridge
//        .dist = 2,
//    },
//
// Well, armed with the knowledge that we can run code at compile
// time, we can perhaps shorten this a bit with a simple function
// instead.
//
// Please fill in the body of this function!
fn makePath(from: *Place, to: *Place, dist: u8) Path {
    return Path {
        .from = from,
        .to = to,
        .dist = dist,
    };
}

// Using our new function, these path definitions take up considerably less
// space in our program now!
// const a_paths = [_]Path{makePath(&a, &b, 2)};
// const b_paths = [_]Path{ makePath(&b, &a, 2), makePath(&b, &d, 1) };
// const c_paths = [_]Path{ makePath(&c, &d, 3), makePath(&c, &e, 2) };
// const d_paths = [_]Path{ makePath(&d, &b, 1), makePath(&d, &c, 3), makePath(&d, &f, 7) };
// const e_paths = [_]Path{ makePath(&e, &c, 2), makePath(&e, &f, 1) };
// const f_paths = [_]Path{makePath(&f, &d, 7)};
//
// But is it more readable? That could be argued either way.
//
// We've seen that it is possible to parse strings at compile
// time, so the sky's really the limit on how fancy we could get
// with this.
//
// For example, we could create our own "path language" and
// create Paths from that. Something like this, perhaps:
//
//    a -> (b[2])
//    b -> (a[2] d[1])
//    c -> (d[3] e[2])
//    ...
//
// Feel free to implement something like that as a SUPER BONUS EXERCISE!
var buffer: [432]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
const instructions = [_][]const u8 {
    "a -> (b[2])",
    "b -> (a[2] d[1])",
    "c -> (d[3] e[2])",
    "d -> (b[1] c[3] f[7])",
    "e -> (c[2] f[1])",
    "f -> (d[7])",
};

const TripItem = union(enum) {
    place: *const Place,
    path: *const Path,

    fn printMe(self: TripItem) void {
        switch (self) {
            .place => |p| print("{s}", .{p.name}),
            .path => |p| print("--{}->", .{p.dist}),
        }
    }
};

const NotebookEntry = struct {
    place: *const Place,
    coming_from: ?*const Place,
    via_path: ?*const Path,
    dist_to_reach: u16,
};

const HermitsNotebook = struct {
    entries: [place_count]?NotebookEntry = .{null} ** place_count,
    next_entry: u8 = 0,
    end_of_entries: u8 = 0,

    fn getEntry(self: *HermitsNotebook, place: *const Place) ?*NotebookEntry {
        for (&self.entries, 0..) |*entry, i| {
            if (i >= self.end_of_entries) break;
            if (place == entry.*.?.place) return &entry.*.?;
        }
        return null;
    }

    fn checkNote(self: *HermitsNotebook, note: NotebookEntry) void {
        const existing_entry = self.getEntry(note.place);

        if (existing_entry == null) {
            self.entries[self.end_of_entries] = note;
            self.end_of_entries += 1;
        } else if (note.dist_to_reach < existing_entry.?.dist_to_reach) {
            existing_entry.?.* = note;
        }
    }

    fn hasNextEntry(self: *HermitsNotebook) bool {
        return self.next_entry < self.end_of_entries;
    }

    fn getNextEntry(self: *HermitsNotebook) *const NotebookEntry {
        defer self.next_entry += 1;
        return &self.entries[self.next_entry].?;
    }

    fn getTripTo(self: *HermitsNotebook, trip: []?TripItem, dest: *Place) TripError!void {
        const destination_entry = self.getEntry(dest);

        if (destination_entry == null) {
            return TripError.Unreachable;
        }

        var current_entry = destination_entry.?;
        var i: u8 = 0;

        while (true) : (i += 2) {
            trip[i] = TripItem{ .place = current_entry.place };
            if (current_entry.coming_from == null) break;
            trip[i + 1] = TripItem{ .path = current_entry.via_path.? };
            const previous_entry = self.getEntry(current_entry.coming_from.?);
            if (previous_entry == null) return TripError.EatenByAGrue;
            current_entry = previous_entry.?;
        }
    }
};

pub fn main() void {
    const start = &a; // Archer's Point
    const destination = &f; // Fox Pond

    // We could either have this:
    //
    //   a.paths = a_paths[0..];
    //   b.paths = b_paths[0..];
    //   c.paths = c_paths[0..];
    //   d.paths = d_paths[0..];
    //   e.paths = e_paths[0..];
    //   f.paths = f_paths[0..];
    //
    // or this comptime wizardry:
    //
    // const letters = [_][]const u8{ "a", "b", "c", "d", "e", "f" };
    // inline for (letters) |letter| {
    //     @field(@This(), letter).paths = @field(@This(), letter ++ "_paths")[0..];
    // }

    // This solution for the "SUPER BONUS EXERCISE" was informative, but there are some
    // important notes:
    //   1. The previous inline for was expanded to the equivalent of the code in the comment
    //      but it was still executing at runtime.
    //   2. The solution below keeps the paths defined on the stack (using the FixedBufferAllocator), 
    //      but they are now defined at runtime unlike the original example.
    // Pointers are limited at comptime, so I don't see a way to move the definitions
    // back to comptime while still using the "path language".  I don't feel we accomplished
    // much implmenting this "path lauguage" in a comptime discussion but I'll leave it as 
    // an example of an experiment that provided insight.
    
    inline for (instructions) |instruction| {
        const from_letter = instruction[0..1];
        var paths = std.ArrayList(Path).init(allocator);
        comptime var i = 6;
        const this = @This();
        inline while (i < instruction.len) : (i += 5) {
            const to_letter = instruction[i..i+1];
            const dist = instruction[i+2] - '0';
            paths.append(makePath(&@field(this, from_letter), &@field(this, to_letter), dist)) catch unreachable;
        }
        @field(this, from_letter).paths = paths.toOwnedSlice() catch unreachable;
    }

    var notebook = HermitsNotebook{};
    var working_note = NotebookEntry{
        .place = start,
        .coming_from = null,
        .via_path = null,
        .dist_to_reach = 0,
    };
    notebook.checkNote(working_note);

    while (notebook.hasNextEntry()) {
        const place_entry = notebook.getNextEntry();

        for (place_entry.place.paths) |*path| {
            working_note = NotebookEntry{
                .place = path.to,
                .coming_from = place_entry.place,
                .via_path = path,
                .dist_to_reach = place_entry.dist_to_reach + path.dist,
            };
            notebook.checkNote(working_note);
        }
    }

    var trip = [_]?TripItem{null} ** (place_count * 2);

    notebook.getTripTo(trip[0..], destination) catch |err| {
        print("Oh no! {}\n", .{err});
        return;
    };

    printTrip(trip[0..]);
}

fn printTrip(trip: []?TripItem) void {
    var i: u8 = @intCast(trip.len);

    while (i > 0) {
        i -= 1;
        if (trip[i] == null) continue;
        trip[i].?.printMe();
    }

    print("\n", .{});
}
