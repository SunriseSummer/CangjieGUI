package cui_wenkai

import std.collection.ArrayList
import cui.{FontFamily, FontWeight}

@Test
func resolveFontsDirPicksFirstExisting(): Unit {
    // a 目录存在但缺少 Regular，不能阻止继续寻找 b 中的字体。
    let hit = resolveFontsDir(["a", "b", "c"], {p => p == "a" || p == "b/LXGWWenKai-Regular.ttf" || p == "c/LXGWWenKai-Regular.ttf"})
    @Expect(hit.getOrThrow(), "b")
    // 全部缺失返回 None（示例照常运行、回退系统字体）。
    @Expect(resolveFontsDir(["a", "b"], {_ => false}).isNone())
    // 空候选安全返回 None。
    @Expect(resolveFontsDir([], {_ => true}).isNone())
}

@Test
func registerWeightsGroupsStaticFacesAndSkipsMissingFiles(): Unit {
    let names = ArrayList<String>()
    let families = ArrayList<FontFamily>()
    let count = registerWeights(Some("D:/fonts"), {_ => true}, {name, family => names.add(name); families.add(family)})
    @Expect(count, 4)
    @Expect(names.size, 2)
    @Expect(names[0], "wenkai")
    @Expect(families[0].regular.path, "D:/fonts/LXGWWenKai-Regular.ttf")
    @Expect(families[0].faces().size, 2)
    @Expect(families[0].faces()[0].weight, FontWeight.light)
    @Expect(families[0].faces()[1].weight, FontWeight.medium)
    @Expect(registerWeights(None, {_ => true}, {_, _ => ()}), 0)
    @Expect(registerWeights(Some("empty"), {_ => false}, {_, _ => ()}), 0)
}

@Test
func modelWeightFollowsSelectionWhileFamilyStaysStable(): Unit {
    let model = WenkaiModel(4)
    @Expect(model.family(), "wenkai")
    @Expect(model.weight(), FontWeight.normal)
    model.selected.value = 0
    @Expect(model.family(), "wenkai")
    @Expect(model.weight(), FontWeight.light)
    model.selected.value = 2
    @Expect(model.weight(), FontWeight.medium)
    model.selected.value = 99
    @Expect(model.weight(), FontWeight.normal)
}

@Test
func statusTextReflectsAvailability(): Unit {
    // 已登记：报字重数与授权说明。
    let loaded = WenkaiModel(4)
    @Expect(loaded.available())
    @Expect(loaded.statusText().contains("4 个字体文件"))
    // 缺失：给出回退与获取指引。
    let missing = WenkaiModel(0)
    @Expect(!missing.available())
    @Expect(missing.statusText().contains("回退"))
}

@Test
func weightLabelsMatchWeightTable(): Unit {
    let labels = weightLabels()
    @Expect(labels.size, WEIGHTS.size)
    @Expect(labels[1].contains("Regular"))
}
