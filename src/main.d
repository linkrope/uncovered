//          Copyright Mario Kröplin 2020.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

import std.range;

void main(const string[] args)
{
    import std.algorithm : map, sum;
    import std.conv : to;
    import std.format : format;
    import std.stdio : File, writeln;

    Record[] records;

    foreach (path; args.dropOne)
        // Throws: ErrnoException if the file could not be opened.
        records ~= File(path).byLine.read(path);

    const hitCountSum = records.map!(record => record.hitCount).sum;
    const missCountSum = records.map!(record => record.missCount).sum;
    const width = (hitCountSum + missCountSum).to!string.length;

    records.write(width);

    const depth = 2;
    Record[string] soFar; // TODO: do something stable

    foreach (record; records)
        with (record)
        {
            import std.array : join, split;
            import std.path : baseName, stripExtension;

            // TODO: check whether there is one for dropBackOne
            const prefix = path.baseName.stripExtension.split("-").dropBackOne.take(depth).join("-");

            if (auto subtotal = prefix in soFar)
            {
                subtotal.hitCount += hitCount;
                subtotal.missCount += missCount;
            }
            else
                soFar[prefix] = Record(prefix, hitCount, missCount);

        }
    soFar.values.write(width);
    writeln(format!"%*d/%*d lines uncovered"(width, missCountSum, width, hitCountSum + missCountSum));
}

Record read(Range)(Range range, string path)
if (isInputRange!Range)
{
    import std.regex : matchFirst, regex;
    import std.stdio : stderr, writeln;
    import std.traits : EnumMembers;

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
                stderr.writeln("error: ", line); // TODO: better error message
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
    noCode = `(?P<source>^.+) has no code`,
    percent = `(?P<source>^.+) is (?P<percent>\d+)% covered`,
}

private int index(Pattern pattern) pure @safe
{
    import std.algorithm : countUntil;
    import std.conv : to;
    import std.traits : EnumMembers;

    return [EnumMembers!Pattern].countUntil(pattern).to!int;
}

void write(const Record[] records, size_t width)
{
    import std.algorithm : sort, SwapStrategy;
    import std.format : format;
    import std.stdio : writeln;

    foreach (record; records.dup.sort!((a, b) => a.missCount < b.missCount, SwapStrategy.stable))
        with (record)
            writeln(format!"%*d/%-*d %s"(width, missCount, width, hitCount + missCount, path));
    writeln('-'.repeat(width + 1 + width));
}

struct Record
{
    string path;
    size_t hitCount;
    size_t missCount;
}
