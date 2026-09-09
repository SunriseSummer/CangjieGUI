package cui.core

import std.collection.ArrayList
import std.convert.RadixConvertible
import std.fs.File

@Test
func unicode17OfficialGraphemeBreakConformance(): Unit {
    let fixture = String.fromUtf8(File.readFrom(".dev/unicode/GraphemeBreakTest.txt"))
    var cases: Int64 = 0
    for (line in fixture.lines()) {
        let sample = line.split("#")[0].trimAscii()
        if (sample.isEmpty()) { continue }
        let runes = ArrayList<Rune>()
        let expected = ArrayList<Int64>()
        for (token in sample.split(" ")) {
            if (token == "÷") { expected.add(runes.size) }
            else if (token != "×" && !token.isEmpty()) { runes.add(Rune(UInt32.parse(token, radix: 16))) }
        }
        @Expect(graphemeRuneBoundaries(runes.toArray()), expected.toArray())
        cases += 1
    }
    @Expect(cases > 700)
}
