package cui.core

@Test
func textQualityGraphemesDoNotJoinUnrelatedTextThroughHangulOrZwj(): Unit {
    @Expect(graphemeRuneBoundaries("a\u{1161}".toRuneArray()), [0, 1, 2])
    @Expect(graphemeRuneBoundaries("\u{1100}\u{1161}\u{11A8}".toRuneArray()), [0, 3])
    @Expect(graphemeRuneBoundaries("a\u{200D}b".toRuneArray()), [0, 2, 3])
}
