package cui.core

private class CountingBindable <: Bindable<Int64> {
    private var stored: Int64
    var reads: Int64 = 0
    var writes: Int64 = 0
    private var bindingRevision: UInt64 = UInt64(0)

    init(value: Int64) {
        this.stored = value
    }

    public mut prop value: Int64 {
        get() {
            reads += 1
            stored
        }
        set(next) {
            writes += 1
            stored = next
            bindingRevision = nextRevision(bindingRevision)
        }
    }

    public prop revision: UInt64 {
        get() {
            bindingRevision
        }
    }

    public func observe(_: (Int64, Int64) -> Unit): StateObservation<Int64> {
        StateObservation<Int64>({=> ()})
    }

    func resetCounts(): Unit {
        reads = 0
        writes = 0
    }
}

private class BindingPolicyProbe {
    var notifications: Int64 = 0
    var previous: String = ""
    var current: String = ""
}

@Test
func composedLensObeysGetPutPutGetAndPutPut(): Unit {
    let profileName = Lens<TestProfile, String>(
        get: {profile => profile.name},
        set: {profile, name => TestProfile(name, profile.subscribed)}
    )
    let accountProfile = Lens<TestAccount, TestProfile>(
        get: {account => account.profile},
        set: {account, profile => TestAccount(profile, account.active)}
    )
    let accountName = accountProfile.then(profileName)
    let original = TestProfile("林", true)
    let account = TestAccount(original, true)

    @Expect(profileName.set(original, profileName.get(original)).name, original.name)
    let changed = profileName.set(original, "陈明")
    @Expect(profileName.get(changed), "陈明")
    let overwritten = profileName.set(profileName.set(original, "甲"), "乙")
    @Expect(overwritten.name, profileName.set(original, "乙").name)
    @Expect(accountName.get(account), "林")
    let renamed = accountName.set(account, "陈")
    @Expect(renamed.profile.name, "陈")
    @Expect(renamed.active)
}

@Test
func bindingProjectsThroughComposableLens(): Unit {
    let profile = State<TestProfile>(TestProfile("林", true))
    let nameLens = Lens<TestProfile, String>(
        get: {value => value.name},
        set: {value, name => TestProfile(name, value.subscribed)}
    )
    let name = profile.project(nameLens)

    name.value = "陈"

    @Expect(profile.value.name, "陈")
    @Expect(profile.value.subscribed)
}

@Test
func bindingPolicyFiltersSiblingChangesWithoutWeakeningLensWrites(): Unit {
    let profile = State<TestProfile>(TestProfile("林", true))
    let nameLens = Lens<TestProfile, String>(
        get: {value => value.name},
        set: {value, name => TestProfile(name, value.subscribed)}
    )
    let named = profile.project(
        get: {value => value.name},
        set: {value, name => TestProfile(name, value.subscribed)},
        policy: structuralEqualityPolicy<String>()
    )
    let name = profile.project(nameLens, policy: structuralEqualityPolicy<String>())
    let probe = BindingPolicyProbe()
    let observation = name.observe({previous, current =>
        probe.notifications += 1
        probe.previous = previous
        probe.current = current
    })
    let initialRevision = name.revision

    profile.value = TestProfile("林", false)
    @Expect(named.value, "林")
    @Expect(name.revision, initialRevision)
    @Expect(probe.notifications, Int64(0))

    name.update({value => "${value}青"})
    @Expect(profile.value.name, "林青")
    @Expect(!profile.value.subscribed)
    @Expect(name.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, "林")
    @Expect(probe.current, "林青")
    observation.close()
}

@Test
func deeplyProjectedBindingSetterReadsRootExactlyOnce(): Unit {
    let root = CountingBindable(0)
    var current: Bindable<Int64> = root
    for (_ in 0..32) {
        current = current.project(get: {value => value}, set: {_, value => value})
    }
    let leaf = current
    root.resetCounts()

    leaf.value = 7

    @Expect(root.reads, Int64(1))
    @Expect(root.writes, Int64(1))
    @Expect(root.value, Int64(7))
}

@Test
func deeplyProjectedBindingUpdateLiftsOneRootEndomorphism(): Unit {
    let root = CountingBindable(4)
    var current: Bindable<Int64> = root
    for (_ in 0..32) {
        current = current.project(get: {value => value}, set: {_, value => value})
    }
    let leaf = current
    root.resetCounts()

    leaf.update({value => value * 3})

    @Expect(root.reads, Int64(1))
    @Expect(root.writes, Int64(1))
    @Expect(root.value, Int64(12))
}

@Test
func nestedBindingUpdatePreservesSiblingsAndNotifiesRootOnce(): Unit {
    let account = State<TestAccount>(TestAccount(TestProfile("林", true), true))
    let profile = account.project(
        get: {value => value.profile},
        set: {value, next => TestAccount(next, value.active)}
    )
    let name = profile.project(
        get: {value => value.name},
        set: {value, next => TestProfile(next, value.subscribed)}
    )
    let notifications = State<Int64>(0)
    let observation = account.observe({_, _ => notifications.value += 1})

    name.update({value => "${value}青"})

    @Expect(account.value.profile.name, "林青")
    @Expect(account.value.profile.subscribed)
    @Expect(account.value.active)
    @Expect(account.revision, UInt64(1))
    @Expect(notifications.value, Int64(1))
    observation.close()
}

@Test
func nestedBindingUpdateFailureDoesNotWriteRoot(): Unit {
    let root = CountingBindable(9)
    let leaf = root.project(get: {value => value}, set: {_, value => value})
    root.resetCounts()
    var didThrow = false
    try {
        leaf.update({_ => throw IllegalStateException("expected binding update failure")})
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(root.reads, Int64(1))
    @Expect(root.writes, Int64(0))
    @Expect(root.value, Int64(9))
}
