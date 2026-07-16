package cui_settings

@Test
func defaultsAreSensible(): Unit {
    let model = SettingsModel()
    @Expect(model.theme.value, 1) // 深色
    @Expect(model.notifyEnabled.value)
    @Expect(!model.singleMode.value)
    @Expect(model.fontPercent(), 100)
}

@Test
func summaryTracksThemeAndSharing(): Unit {
    let model = SettingsModel()
    @Expect(model.summary.value.contains("深色"))
    @Expect(model.summary.value.contains("仅崩溃日志"))

    model.theme.value = 0 // 浅色
    model.dataSharing.value = 2 // 完整诊断
    @Expect(model.summary.value.contains("浅色"))
    @Expect(model.summary.value.contains("完整诊断"))
}

@Test
func fontPercentRoundsScale(): Unit {
    let model = SettingsModel()
    model.fontScale.value = 1.25
    @Expect(model.fontPercent(), 125)
    model.fontScale.value = 0.8
    @Expect(model.fontPercent(), 80)
}

@Test
func labelHelpersClampOutOfRange(): Unit {
    @Expect(themeLabel(0), "浅色")
    @Expect(themeLabel(99), "浅色") // 越界回退到第一项
    @Expect(sharingLabel(2), "完整诊断")
}
