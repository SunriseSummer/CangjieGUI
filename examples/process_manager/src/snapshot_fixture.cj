/* Stable external input for pixel-level E2E comparison. Production runs never use this data. */
package cui_process_manager

func processSnapshotFixture(args: Array<String>): ?String {
    for (arg in args) {
        if (arg == "--snapshot") {
            return Some(deterministicProcessSnapshot())
        }
    }
    None
}

private func deterministicProcessSnapshot(): String {
    "\"System Idle Process\",\"0\",\"Services\",\"0\",\"8 K\"\n" + "\"System\",\"4\",\"Services\",\"0\",\"8,952 K\"\n" +
        "\"Secure System\",\"140\",\"Services\",\"0\",\"110,640 K\"\n" +
        "\"Registry\",\"184\",\"Services\",\"0\",\"54,504 K\"\n" +
        "\"smss.exe\",\"780\",\"Services\",\"0\",\"1,628 K\"\n" +
        "\"csrss.exe\",\"1044\",\"Services\",\"0\",\"6,720 K\"\n" +
        "\"wininit.exe\",\"1148\",\"Services\",\"0\",\"8,980 K\"\n" +
        "\"csrss.exe\",\"1156\",\"Console\",\"1\",\"8,188 K\"\n" +
        "\"winlogon.exe\",\"1248\",\"Console\",\"1\",\"21,664 K\"\n" +
        "\"services.exe\",\"1272\",\"Services\",\"0\",\"20,632 K\"\n" +
        "\"LsaIso.exe\",\"1316\",\"Services\",\"0\",\"3,796 K\"\n" +
        "\"lsass.exe\",\"1324\",\"Services\",\"0\",\"35,496 K\"\n" +
        "\"svchost.exe\",\"1460\",\"Services\",\"0\",\"60,380 K\"\n" +
        "\"fontdrvhost.exe\",\"1496\",\"Console\",\"1\",\"11,456 K\"\n" +
        "\"fontdrvhost.exe\",\"1492\",\"Services\",\"0\",\"6,168 K\"\n" +
        "\"WUDFCompanionHost.exe\",\"1584\",\"Services\",\"0\",\"3,840 K\"\n"
}
