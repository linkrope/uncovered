//          Copyright Mario Kröplin 2020.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

import core.stdc.stdlib;
import std.algorithm;
import std.range;
import std.stdio;
import std.traits;

void main(string[] args)
{
    import std.conv : to;
    import std.getopt : defaultGetoptPrinter, getopt, GetoptResult;

    size_t depth;
    GetoptResult result;

    try
    {
        result = getopt(args,
                "depth", "Write package summary limited to the given depth.", &depth,
        );
    }
    catch (Exception exception)
    {
        stderr.writeln("error: ", exception.msg);
        exit(EXIT_FAILURE);
    }
    if (result.helpWanted)
    {
        import std.path : baseName;

        writefln!"Usage: %s [options] files"(args.front.baseName);
        writeln("Examine listing files to identify the ones with the most uncovered lines.");
        defaultGetoptPrinter("Options:", result.options);
        exit(EXIT_SUCCESS);
    }

    auto records = args.dropOne.map!read;
    const hitCountSum = records.map!"a.hitCount".sum;
    const missCountSum = records.map!"a.missCount".sum;
    const width = (hitCountSum + missCountSum).to!string.length;

    if (!records.empty)
    {
        records.write(width);
        if (depth > 0)
        {
            auto totals = records.summary(depth);

            if (!totals.empty)
                totals.write(width);
        }
        Record("lines uncovered", hitCountSum, missCountSum).write(width);
    }
}

Record read(string path)
{
    import std.exception : ErrnoException;

    try
        return File(path).byLine.read(path);
    catch (ErrnoException exception)
    {
        stderr.writefln!"error: %s"(exception.msg);
        exit(EXIT_FAILURE);
        assert(0);
    }
}

Record read(Range)(Range range, string path)
if (isInputRange!Range)
{
    import std.regex : matchFirst, regex;

    static immutable string[] patterns = [EnumMembers!Pattern];
    enum pattern = regex(patterns.dropOne);
    auto hitCount = 0;
    auto missCount = 0;

    foreach (line; range)
    {
        const captures = line.matchFirst(pattern);

        switch (captures.whichPattern) with (Pattern)
        {
            case index(hit):
                ++hitCount;
                break;
            case index(miss):
                ++missCount;
                break;
            case index(nope):
            case index(noCode):
            case index(percent):
                break;
            default:
                stderr.writefln!"skipping: %s"(line);
                break;
        }
    }
    return Record(path, hitCount, missCount);
}

unittest
{
    const path = "foo.lst";

    assert(["       | nope"].read(path) == Record(path, 0, 0));
    assert(["     42| hits"].read(path) == Record(path, 1, 0));
    assert(["0000000| miss"].read(path) == Record(path, 0, 1));
    assert(["foo.d has no code"].read(path) == Record(path, 0, 0));
    assert(["foo.d is 100% covered"].read(path) == Record(path, 0, 0));
}

private enum Pattern
{
    error = ``,
    nope = `^\s+\|`,
    miss = `^0+\|`,
    hit = `^\s*[1-9]\d*\|`,
    noCode = `(?P<path>^.+) has no code`,
    percent = `(?P<path>^.+) is (?P<percent>\d+)% covered`,
}

private int index(Pattern pattern) pure @safe
{
    import std.conv : to;

    return [EnumMembers!Pattern].countUntil(pattern).to!int;
}

auto summary(Range)(Range records, size_t depth)
if (isInputRange!Range && is(Unqual!(ElementType!Range) == Record))
{
    string[] order;
    Record[string] subtotal;

    foreach (record; records)
    {
        const key = record.path.packages(depth);

        if (key.empty)
            continue;
        if (key !in subtotal)
        {
            order ~= key;
            subtotal[key] = Record(key);
        }
        with (subtotal[key])
        {
            hitCount += record.hitCount;
            missCount += record.missCount;
        }
    }
    return order.map!(key => subtotal[key]);
}

string packages(string path, size_t depth) nothrow pure @safe
{
    import std.path : baseName;

    return path.baseName.split("-").dropBackOne.take(depth).join("-");
}

unittest
{
    assert("qux/bar-baz-foo.lst".packages(2) == "bar-baz");
    assert("qux/bar-foo.lst".packages(2) == "bar");
    assert("foo.lst".packages(1).empty);
}

void write(Range)(Range records, size_t width)
if (isInputRange!Range && is(ElementType!Range == Record))
{
    foreach (record; records.array.sort!("a.missCount < b.missCount", SwapStrategy.stable))
        record.write(width);
    writeln('-'.repeat(width + 1 + width));
}

void write(Record record, size_t width) @safe
{
    with (record)
        writefln!"%*d/%-*d %s"(width, missCount, width, hitCount + missCount, path);
}

struct Record
{
    string path;
    size_t hitCount;
    size_t missCount;
}
