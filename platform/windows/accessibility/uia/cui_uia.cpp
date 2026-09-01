#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <ole2.h>
#include <commctrl.h>
#include <UIAutomation.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#if defined(_WIN32)
#define CUI_UIA_EXPORT extern "C" __declspec(dllexport)
#else
#define CUI_UIA_EXPORT extern "C"
#endif

struct CuiUiaNode {
    std::uint64_t token;
    std::int64_t id_offset;
    std::int64_t label_offset;
    std::int64_t value_offset;
    std::int64_t hint_offset;
    std::int32_t role;
    std::int32_t enabled;
    std::int32_t selected;
    std::int32_t checked;
    std::uint32_t action_mask;
    double x;
    double y;
    double width;
    double height;
    std::int64_t parent_index;
};

struct CuiUiaChange {
    std::uint64_t token;
    std::int32_t kind;
};

// ABI ownership contract: every pointer passed to cui_uia_update is borrowed only for that call.
// Nodes reference the bounded UTF-8 arena by offset; copySnapshot validates and deep-copies every string.

namespace {

constexpr std::uint64_t kUiaAbiVersion = 2;
constexpr std::uint32_t kActionActivate = 1u << 0;
constexpr std::uint32_t kActionFocus = 1u << 1;
constexpr std::uint32_t kActionSetValue = 1u << 4;
constexpr std::size_t kMaximumQueuedActions = 1024;
constexpr UINT_PTR kSubclassId = 0x43554941u;  // "CUIA"

constexpr std::uint64_t layoutFingerprint(std::size_t size, std::size_t alignment) noexcept {
    return static_cast<std::uint64_t>(size) | (static_cast<std::uint64_t>(alignment) << 32u);
}

enum class ActionKind : std::int32_t {
    Activate = 1,
    Focus = 2,
    Increment = 3,
    Decrement = 4,
    SetValue = 5,
};

struct RectD {
    double x = 0.0;
    double y = 0.0;
    double width = 0.0;
    double height = 0.0;

    bool hasArea() const noexcept { return width > 0.0 && height > 0.0; }

    bool contains(double px, double py) const noexcept {
        return hasArea() && px >= x && py >= y && px < x + width && py < y + height;
    }
};

struct Node {
    std::uint64_t token = 0;
    std::string id;
    std::string label;
    std::string value;
    std::string hint;
    std::int32_t role = 0;
    bool enabled = true;
    std::int32_t selected = -1;
    std::int32_t checked = -1;
    std::uint32_t actionMask = 0;
    RectD bounds;
    std::int64_t parent = -1;
    std::int64_t previousSibling = -1;
    std::int64_t nextSibling = -1;
    std::int64_t firstChild = -1;
    std::int64_t lastChild = -1;
};

struct SpatialNode {
    std::int64_t begin = 0;
    std::int64_t end = 0;
    std::int64_t left = -1;
    std::int64_t right = -1;
    RectD bounds;
    bool hasBounds = false;

    bool isLeaf() const noexcept { return end - begin == 1; }
};

struct Snapshot {
    std::uint64_t revision = 0;
    double viewportWidth = 0.0;
    double viewportHeight = 0.0;
    std::uint64_t focusedToken = 0;
    std::vector<Node> nodes;
    std::unordered_map<std::uint64_t, std::int64_t> indexByToken;
    std::int64_t firstRoot = -1;
    std::int64_t lastRoot = -1;
    std::vector<SpatialNode> spatialNodes;
    std::int64_t spatialRoot = -1;
};

struct PendingAction {
    std::uint64_t token = 0;
    ActionKind kind = ActionKind::Activate;
    std::string value;
};

class Provider;

using PushSdlEvent = bool (*)(void*);

struct SdlUserEvent {
    std::uint32_t type = 0;
    std::uint32_t reserved = 0;
    std::uint64_t timestamp = 0;
    std::uint32_t windowId = 0;
    std::int32_t code = 0;
    void* data1 = nullptr;
    void* data2 = nullptr;
};

union SdlEvent {
    SdlUserEvent user;
    alignas(8) std::uint8_t padding[128];

    SdlEvent() : padding{} {}
};

std::wstring utf8ToWide(const char* text) {
    if (text == nullptr || *text == '\0') {
        return {};
    }
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, nullptr, 0);
    if (count <= 0) {
        count = MultiByteToWideChar(CP_UTF8, 0, text, -1, nullptr, 0);
    }
    if (count <= 1) {
        return {};
    }
    std::wstring result(static_cast<std::size_t>(count), L'\0');
    if (MultiByteToWideChar(CP_UTF8, 0, text, -1, result.data(), count) <= 0) {
        return {};
    }
    result.resize(static_cast<std::size_t>(count - 1));
    return result;
}

std::string wideToUtf8(const wchar_t* text) {
    if (text == nullptr || *text == L'\0') {
        return {};
    }
    const int count = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
    if (count <= 1) {
        return {};
    }
    std::string result(static_cast<std::size_t>(count), '\0');
    if (WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), count, nullptr, nullptr) <= 0) {
        return {};
    }
    result.resize(static_cast<std::size_t>(count - 1));
    return result;
}

RectD unionRect(const RectD& left, const RectD& right, bool leftValid, bool rightValid) {
    if (!leftValid) {
        return right;
    }
    if (!rightValid) {
        return left;
    }
    const double x = (std::min)(left.x, right.x);
    const double y = (std::min)(left.y, right.y);
    const double rightEdge = (std::max)(left.x + left.width, right.x + right.width);
    const double bottomEdge = (std::max)(left.y + left.height, right.y + right.height);
    return {x, y, rightEdge - x, bottomEdge - y};
}

std::int64_t buildSpatialNode(Snapshot& snapshot, std::int64_t begin, std::int64_t end) {
    if (end - begin == 1) {
        SpatialNode leaf;
        leaf.begin = begin;
        leaf.end = end;
        leaf.bounds = snapshot.nodes[static_cast<std::size_t>(begin)].bounds;
        leaf.hasBounds = leaf.bounds.hasArea();
        snapshot.spatialNodes.push_back(leaf);
        return static_cast<std::int64_t>(snapshot.spatialNodes.size() - 1);
    }
    const std::int64_t middle = begin + (end - begin) / 2;
    const std::int64_t left = buildSpatialNode(snapshot, begin, middle);
    const std::int64_t right = buildSpatialNode(snapshot, middle, end);
    const SpatialNode& leftNode = snapshot.spatialNodes[static_cast<std::size_t>(left)];
    const SpatialNode& rightNode = snapshot.spatialNodes[static_cast<std::size_t>(right)];
    SpatialNode branch;
    branch.begin = begin;
    branch.end = end;
    branch.left = left;
    branch.right = right;
    branch.hasBounds = leftNode.hasBounds || rightNode.hasBounds;
    branch.bounds = unionRect(leftNode.bounds, rightNode.bounds, leftNode.hasBounds, rightNode.hasBounds);
    snapshot.spatialNodes.push_back(branch);
    return static_cast<std::int64_t>(snapshot.spatialNodes.size() - 1);
}

std::int64_t hitTest(const Snapshot& snapshot, double x, double y, std::int64_t nodeIndex) {
    if (nodeIndex < 0) {
        return -1;
    }
    const SpatialNode& spatial = snapshot.spatialNodes[static_cast<std::size_t>(nodeIndex)];
    if (!spatial.hasBounds || !spatial.bounds.contains(x, y)) {
        return -1;
    }
    if (spatial.isLeaf()) {
        return spatial.begin;
    }
    const std::int64_t right = hitTest(snapshot, x, y, spatial.right);
    return right >= 0 ? right : hitTest(snapshot, x, y, spatial.left);
}

bool validateParents(const std::vector<Node>& nodes) {
    const std::int64_t count = static_cast<std::int64_t>(nodes.size());
    std::vector<std::uint8_t> state(nodes.size(), 0);
    for (std::int64_t start = 0; start < count; ++start) {
        if (state[static_cast<std::size_t>(start)] == 2) {
            continue;
        }
        std::vector<std::int64_t> path;
        std::int64_t current = start;
        while (current >= 0 && state[static_cast<std::size_t>(current)] == 0) {
            state[static_cast<std::size_t>(current)] = 1;
            path.push_back(current);
            const std::int64_t parent = nodes[static_cast<std::size_t>(current)].parent;
            if (parent < -1 || parent >= count || parent == current) {
                return false;
            }
            current = parent;
        }
        if (current >= 0 && state[static_cast<std::size_t>(current)] == 1) {
            return false;
        }
        for (std::int64_t index : path) {
            state[static_cast<std::size_t>(index)] = 2;
        }
    }
    return true;
}

void linkTopology(Snapshot& snapshot) {
    for (std::int64_t index = 0; index < static_cast<std::int64_t>(snapshot.nodes.size()); ++index) {
        Node& node = snapshot.nodes[static_cast<std::size_t>(index)];
        if (node.parent < 0) {
            if (snapshot.firstRoot < 0) {
                snapshot.firstRoot = index;
            }
            if (snapshot.lastRoot >= 0) {
                node.previousSibling = snapshot.lastRoot;
                snapshot.nodes[static_cast<std::size_t>(snapshot.lastRoot)].nextSibling = index;
            }
            snapshot.lastRoot = index;
            continue;
        }
        Node& parent = snapshot.nodes[static_cast<std::size_t>(node.parent)];
        if (parent.firstChild < 0) {
            parent.firstChild = index;
        }
        if (parent.lastChild >= 0) {
            node.previousSibling = parent.lastChild;
            snapshot.nodes[static_cast<std::size_t>(parent.lastChild)].nextSibling = index;
        }
        parent.lastChild = index;
    }
}

class BridgeState : public std::enable_shared_from_this<BridgeState> {
public:
    BridgeState(HWND window, std::uint32_t sdlWindowId, std::uint32_t wakeEventType, PushSdlEvent pushEvent)
        : window_(window),
          sdlWindowId_(sdlWindowId),
          wakeEventType_(wakeEventType),
          pushEvent_(pushEvent) {}

    std::shared_ptr<const Snapshot> snapshot() const {
        std::lock_guard<std::mutex> guard(mutex_);
        return snapshot_;
    }

    HWND window() const {
        std::lock_guard<std::mutex> guard(mutex_);
        return window_;
    }

    bool publish(std::shared_ptr<const Snapshot> snapshot) {
        std::lock_guard<std::mutex> guard(mutex_);
        if (closed_) {
            return false;
        }
        snapshot_ = std::move(snapshot);
        return true;
    }

    bool enqueue(std::uint64_t token, ActionKind kind, std::uint32_t requiredMask, std::string value = {}) {
        HWND window = nullptr;
        {
            std::lock_guard<std::mutex> guard(mutex_);
            if (closed_ || !snapshot_ || actions_.size() >= kMaximumQueuedActions) {
                return false;
            }
            const auto found = snapshot_->indexByToken.find(token);
            if (found == snapshot_->indexByToken.end()) {
                return false;
            }
            const Node& node = snapshot_->nodes[static_cast<std::size_t>(found->second)];
            if (!node.enabled || (node.actionMask & requiredMask) == 0) {
                return false;
            }
            actions_.push_back(PendingAction{token, kind, std::move(value)});
            window = window_;
        }
        bool woke = false;
        if (pushEvent_ != nullptr && wakeEventType_ != 0) {
            SdlEvent event;
            event.user.type = wakeEventType_;
            event.user.windowId = sdlWindowId_;
            woke = pushEvent_(&event);
        }
        if (!woke && window != nullptr) {
            PostMessageW(window, WM_NULL, 0, 0);
        }
        return true;
    }

    std::int64_t nextActionValueSize() const {
        std::lock_guard<std::mutex> guard(mutex_);
        if (closed_ || actions_.empty()) {
            return -1;
        }
        return static_cast<std::int64_t>(actions_.front().value.size() + 1);
    }

    bool popAction(
        std::uint64_t* token,
        std::int32_t* kind,
        char* value,
        std::int64_t valueCapacity
    ) {
        std::lock_guard<std::mutex> guard(mutex_);
        if (closed_ || actions_.empty() || token == nullptr || kind == nullptr || value == nullptr) {
            return false;
        }
        const PendingAction& action = actions_.front();
        const std::int64_t required = static_cast<std::int64_t>(action.value.size() + 1);
        if (valueCapacity < required) {
            return false;
        }
        *token = action.token;
        *kind = static_cast<std::int32_t>(action.kind);
        std::memcpy(value, action.value.c_str(), static_cast<std::size_t>(required));
        actions_.pop_front();
        return true;
    }

    void setRoot(Provider* root) {
        std::lock_guard<std::mutex> guard(mutex_);
        root_ = root;
    }

    Provider* acquireRoot();

    void closeWindow() {
        std::lock_guard<std::mutex> guard(mutex_);
        window_ = nullptr;
        closed_ = true;
        snapshot_.reset();
        actions_.clear();
    }

    Provider* detachRoot() {
        std::lock_guard<std::mutex> guard(mutex_);
        Provider* result = root_;
        root_ = nullptr;
        return result;
    }

private:
    mutable std::mutex mutex_;
    HWND window_ = nullptr;
    bool closed_ = false;
    std::shared_ptr<const Snapshot> snapshot_ = std::make_shared<Snapshot>();
    std::deque<PendingAction> actions_;
    Provider* root_ = nullptr;
    std::uint32_t sdlWindowId_ = 0;
    std::uint32_t wakeEventType_ = 0;
    PushSdlEvent pushEvent_ = nullptr;
};

class Provider final : public IRawElementProviderSimple,
                       public IRawElementProviderFragment,
                       public IRawElementProviderFragmentRoot,
                       public IInvokeProvider,
                       public IValueProvider,
                       public IToggleProvider {
public:
    Provider(std::shared_ptr<BridgeState> state, std::uint64_t token)
        : state_(std::move(state)), token_(token) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        if (iid == IID_IUnknown || iid == IID_IRawElementProviderSimple) {
            *result = static_cast<IRawElementProviderSimple*>(this);
        } else if (iid == IID_IRawElementProviderFragment) {
            *result = static_cast<IRawElementProviderFragment*>(this);
        } else if (iid == IID_IRawElementProviderFragmentRoot && isRoot()) {
            *result = static_cast<IRawElementProviderFragmentRoot*>(this);
        } else if (iid == IID_IInvokeProvider) {
            *result = static_cast<IInvokeProvider*>(this);
        } else if (iid == IID_IValueProvider) {
            *result = static_cast<IValueProvider*>(this);
        } else if (iid == IID_IToggleProvider) {
            *result = static_cast<IToggleProvider*>(this);
        } else {
            return E_NOINTERFACE;
        }
        AddRef();
        return S_OK;
    }

    ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }

    ULONG STDMETHODCALLTYPE Release() override {
        const ULONG remaining = --references_;
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }

    HRESULT STDMETHODCALLTYPE get_ProviderOptions(ProviderOptions* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = static_cast<ProviderOptions>(ProviderOptions_ServerSideProvider |
                                               ProviderOptions_UseComThreading |
                                               ProviderOptions_ProviderOwnsSetFocus);
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetPatternProvider(PATTERNID pattern, IUnknown** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        Node node;
        if (!nodeCopy(&node, nullptr)) {
            return isRoot() ? S_OK : UIA_E_ELEMENTNOTAVAILABLE;
        }
        if (pattern == UIA_InvokePatternId && (node.actionMask & kActionActivate) != 0) {
            *result = static_cast<IInvokeProvider*>(this);
        } else if (pattern == UIA_ValuePatternId && (node.actionMask & kActionSetValue) != 0) {
            *result = static_cast<IValueProvider*>(this);
        } else if (pattern == UIA_TogglePatternId && node.checked >= 0 &&
                   (node.actionMask & kActionActivate) != 0) {
            *result = static_cast<IToggleProvider*>(this);
        }
        if (*result != nullptr) {
            AddRef();
        }
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetPropertyValue(PROPERTYID property, VARIANT* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        VariantInit(result);
        if (isRoot()) {
            return rootProperty(property, result);
        }
        Node node;
        if (!nodeCopy(&node, nullptr)) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        switch (property) {
            case UIA_NamePropertyId:
                return setUtf8Bstr(result, node.label);
            case UIA_AutomationIdPropertyId:
                return setUtf8Bstr(result, node.id);
            case UIA_HelpTextPropertyId:
                return setUtf8Bstr(result, node.hint);
            case UIA_FrameworkIdPropertyId:
                return setBstr(result, L"CUI");
            case UIA_ClassNamePropertyId:
                return setBstr(result, roleClassName(node.role));
            case UIA_ControlTypePropertyId:
                result->vt = VT_I4;
                result->lVal = roleControlType(node.role);
                return S_OK;
            case UIA_IsEnabledPropertyId:
                return setBool(result, node.enabled);
            case UIA_IsKeyboardFocusablePropertyId:
                return setBool(result, (node.actionMask & kActionFocus) != 0);
            case UIA_HasKeyboardFocusPropertyId: {
                const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
                return setBool(result, snapshot && snapshot->focusedToken == token_);
            }
            case UIA_IsOffscreenPropertyId:
                return setBool(result, !node.bounds.hasArea());
            case UIA_IsControlElementPropertyId:
            case UIA_IsContentElementPropertyId:
                return setBool(result, true);
            case UIA_ValueValuePropertyId:
                return setUtf8Bstr(result, node.value);
            case UIA_ValueIsReadOnlyPropertyId:
                return setBool(result, (node.actionMask & kActionSetValue) == 0);
            case UIA_ToggleToggleStatePropertyId:
                if (node.checked >= 0) {
                    result->vt = VT_I4;
                    result->lVal = node.checked == 0 ? ToggleState_Off : ToggleState_On;
                }
                return S_OK;
            default:
                return S_OK;
        }
    }

    HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(IRawElementProviderSimple** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        if (!isRoot()) {
            return S_OK;
        }
        const HWND window = state_->window();
        return window == nullptr ? UIA_E_ELEMENTNOTAVAILABLE : UiaHostProviderFromHwnd(window, result);
    }

    HRESULT STDMETHODCALLTYPE Navigate(NavigateDirection direction, IRawElementProviderFragment** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
        if (!snapshot) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        std::int64_t target = -1;
        if (isRoot()) {
            if (direction == NavigateDirection_FirstChild) {
                target = snapshot->firstRoot;
            } else if (direction == NavigateDirection_LastChild) {
                target = snapshot->lastRoot;
            }
        } else {
            const auto found = snapshot->indexByToken.find(token_);
            if (found == snapshot->indexByToken.end()) {
                return UIA_E_ELEMENTNOTAVAILABLE;
            }
            const Node& node = snapshot->nodes[static_cast<std::size_t>(found->second)];
            switch (direction) {
                case NavigateDirection_Parent:
                    if (node.parent < 0) {
                        *result = new (std::nothrow) Provider(state_, 0);
                        return *result == nullptr ? E_OUTOFMEMORY : S_OK;
                    }
                    target = node.parent;
                    break;
                case NavigateDirection_NextSibling:
                    target = node.nextSibling;
                    break;
                case NavigateDirection_PreviousSibling:
                    target = node.previousSibling;
                    break;
                case NavigateDirection_FirstChild:
                    target = node.firstChild;
                    break;
                case NavigateDirection_LastChild:
                    target = node.lastChild;
                    break;
                default:
                    break;
            }
        }
        return providerAt(snapshot, target, result);
    }

    HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        if (isRoot()) {
            return S_OK;
        }
        if (!nodeCopy(nullptr, nullptr)) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        SAFEARRAY* value = SafeArrayCreateVector(VT_I4, 0, 3);
        if (value == nullptr) {
            return E_OUTOFMEMORY;
        }
        LONG indices[] = {0, 1, 2};
        std::int32_t parts[] = {UiaAppendRuntimeId, static_cast<std::int32_t>(token_ & 0xffffffffu),
                                static_cast<std::int32_t>((token_ >> 32) & 0xffffffffu)};
        for (int index = 0; index < 3; ++index) {
            if (FAILED(SafeArrayPutElement(value, &indices[index], &parts[index]))) {
                SafeArrayDestroy(value);
                return E_FAIL;
            }
        }
        *result = value;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
        if (!snapshot) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        RectD logical;
        if (isRoot()) {
            logical = {0.0, 0.0, snapshot->viewportWidth, snapshot->viewportHeight};
        } else {
            const auto found = snapshot->indexByToken.find(token_);
            if (found == snapshot->indexByToken.end()) {
                return UIA_E_ELEMENTNOTAVAILABLE;
            }
            logical = snapshot->nodes[static_cast<std::size_t>(found->second)].bounds;
        }
        *result = toScreenRect(*snapshot, logical);
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE SetFocus() override {
        if (isRoot()) {
            const HWND window = state_->window();
            if (window == nullptr) {
                return UIA_E_ELEMENTNOTAVAILABLE;
            }
            ::SetFocus(window);
            return S_OK;
        }
        return state_->enqueue(token_, ActionKind::Focus, kActionFocus) ? S_OK : UIA_E_NOTSUPPORTED;
    }

    HRESULT STDMETHODCALLTYPE get_FragmentRoot(IRawElementProviderFragmentRoot** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = new (std::nothrow) Provider(state_, 0);
        return *result == nullptr ? E_OUTOFMEMORY : S_OK;
    }

    HRESULT STDMETHODCALLTYPE ElementProviderFromPoint(
        double screenX,
        double screenY,
        IRawElementProviderFragment** result
    ) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
        if (!snapshot) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        double logicalX = 0.0;
        double logicalY = 0.0;
        if (!fromScreenPoint(*snapshot, screenX, screenY, &logicalX, &logicalY)) {
            return S_OK;
        }
        const std::int64_t hit = hitTest(*snapshot, logicalX, logicalY, snapshot->spatialRoot);
        if (hit >= 0) {
            return providerAt(snapshot, hit, result);
        }
        *result = new (std::nothrow) Provider(state_, 0);
        return *result == nullptr ? E_OUTOFMEMORY : S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetFocus(IRawElementProviderFragment** result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
        if (!snapshot) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        const auto found = snapshot->indexByToken.find(snapshot->focusedToken);
        return found == snapshot->indexByToken.end() ? S_OK : providerAt(snapshot, found->second, result);
    }

    HRESULT STDMETHODCALLTYPE Invoke() override {
        return state_->enqueue(token_, ActionKind::Activate, kActionActivate) ? S_OK : UIA_E_NOTSUPPORTED;
    }

    HRESULT STDMETHODCALLTYPE SetValue(LPCWSTR value) override {
        return state_->enqueue(token_, ActionKind::SetValue, kActionSetValue, wideToUtf8(value)) ? S_OK
                                                                                               : UIA_E_NOTSUPPORTED;
    }

    HRESULT STDMETHODCALLTYPE get_Value(BSTR* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        *result = nullptr;
        Node node;
        if (!nodeCopy(&node, nullptr)) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        const std::wstring wideValue = utf8ToWide(node.value.c_str());
        *result = SysAllocStringLen(wideValue.data(), static_cast<UINT>(wideValue.size()));
        return *result == nullptr && !wideValue.empty() ? E_OUTOFMEMORY : S_OK;
    }

    HRESULT STDMETHODCALLTYPE get_IsReadOnly(BOOL* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        Node node;
        if (!nodeCopy(&node, nullptr)) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        *result = (node.actionMask & kActionSetValue) == 0 ? TRUE : FALSE;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE Toggle() override {
        return state_->enqueue(token_, ActionKind::Activate, kActionActivate) ? S_OK : UIA_E_NOTSUPPORTED;
    }

    HRESULT STDMETHODCALLTYPE get_ToggleState(ToggleState* result) override {
        if (result == nullptr) {
            return E_INVALIDARG;
        }
        Node node;
        if (!nodeCopy(&node, nullptr)) {
            return UIA_E_ELEMENTNOTAVAILABLE;
        }
        if (node.checked < 0) {
            return UIA_E_NOTSUPPORTED;
        }
        *result = node.checked == 0 ? ToggleState_Off : ToggleState_On;
        return S_OK;
    }

private:
    ~Provider() = default;

    bool isRoot() const noexcept { return token_ == 0; }

    bool nodeCopy(Node* result, std::shared_ptr<const Snapshot>* snapshotResult) const {
        const std::shared_ptr<const Snapshot> snapshot = state_->snapshot();
        if (!snapshot) {
            return false;
        }
        if (isRoot()) {
            if (result != nullptr) {
                *result = Node{};
            }
            if (snapshotResult != nullptr) {
                *snapshotResult = snapshot;
            }
            return true;
        }
        const auto found = snapshot->indexByToken.find(token_);
        if (found == snapshot->indexByToken.end()) {
            return false;
        }
        if (result != nullptr) {
            *result = snapshot->nodes[static_cast<std::size_t>(found->second)];
        }
        if (snapshotResult != nullptr) {
            *snapshotResult = snapshot;
        }
        return true;
    }

    HRESULT rootProperty(PROPERTYID property, VARIANT* result) const {
        switch (property) {
            case UIA_FrameworkIdPropertyId:
                return setBstr(result, L"CUI");
            case UIA_ClassNamePropertyId:
                return setBstr(result, L"CUI.Window");
            case UIA_AutomationIdPropertyId:
                return setBstr(result, L"cui-root");
            case UIA_ControlTypePropertyId:
                result->vt = VT_I4;
                result->lVal = UIA_PaneControlTypeId;
                return S_OK;
            case UIA_IsEnabledPropertyId:
            case UIA_IsKeyboardFocusablePropertyId:
            case UIA_IsControlElementPropertyId:
            case UIA_IsContentElementPropertyId:
                return setBool(result, true);
            case UIA_NamePropertyId: {
                wchar_t title[512] = {};
                const HWND window = state_->window();
                if (window != nullptr) {
                    GetWindowTextW(window, title, static_cast<int>(std::size(title)));
                }
                return setBstr(result, title);
            }
            default:
                return S_OK;
        }
    }

    static HRESULT setBstr(VARIANT* result, const std::wstring& value) {
        result->vt = VT_BSTR;
        result->bstrVal = SysAllocStringLen(value.data(), static_cast<UINT>(value.size()));
        return result->bstrVal == nullptr && !value.empty() ? E_OUTOFMEMORY : S_OK;
    }

    static HRESULT setBstr(VARIANT* result, const wchar_t* value) {
        return setBstr(result, value == nullptr ? std::wstring() : std::wstring(value));
    }

    static HRESULT setUtf8Bstr(VARIANT* result, const std::string& value) {
        return setBstr(result, utf8ToWide(value.c_str()));
    }

    static HRESULT setBool(VARIANT* result, bool value) {
        result->vt = VT_BOOL;
        result->boolVal = value ? VARIANT_TRUE : VARIANT_FALSE;
        return S_OK;
    }

    static const wchar_t* roleClassName(std::int32_t role) {
        static constexpr const wchar_t* names[] = {
            L"CUI.Generic", L"CUI.Text",     L"CUI.Button", L"CUI.TextField", L"CUI.Checkbox",
            L"CUI.Switch",  L"CUI.Slider",   L"CUI.List",   L"CUI.ListItem",  L"CUI.Image",
            L"CUI.Dialog",  L"CUI.Menu",     L"CUI.MenuItem",
        };
        return role >= 0 && role < static_cast<std::int32_t>(std::size(names)) ? names[role] : names[0];
    }

    static CONTROLTYPEID roleControlType(std::int32_t role) {
        static constexpr CONTROLTYPEID types[] = {
            UIA_GroupControlTypeId,    UIA_TextControlTypeId,     UIA_ButtonControlTypeId,
            UIA_EditControlTypeId,     UIA_CheckBoxControlTypeId, UIA_CheckBoxControlTypeId,
            UIA_SliderControlTypeId,   UIA_ListControlTypeId,     UIA_ListItemControlTypeId,
            UIA_ImageControlTypeId,    UIA_WindowControlTypeId,   UIA_MenuControlTypeId,
            UIA_MenuItemControlTypeId,
        };
        return role >= 0 && role < static_cast<std::int32_t>(std::size(types)) ? types[role] : types[0];
    }

    template <typename Interface>
    HRESULT providerAt(
        const std::shared_ptr<const Snapshot>& snapshot,
        std::int64_t index,
        Interface** result
    ) const {
        if (index < 0 || index >= static_cast<std::int64_t>(snapshot->nodes.size())) {
            return S_OK;
        }
        Provider* provider = new (std::nothrow) Provider(state_, snapshot->nodes[static_cast<std::size_t>(index)].token);
        if (provider == nullptr) {
            return E_OUTOFMEMORY;
        }
        *result = static_cast<Interface*>(provider);
        return S_OK;
    }

    UiaRect toScreenRect(const Snapshot& snapshot, const RectD& logical) const {
        UiaRect result{};
        const HWND window = state_->window();
        RECT client{};
        POINT origin{};
        if (window == nullptr || !GetClientRect(window, &client) || !ClientToScreen(window, &origin)) {
            return result;
        }
        const double scaleX = snapshot.viewportWidth > 0.0
                                  ? static_cast<double>(client.right - client.left) / snapshot.viewportWidth
                                  : 1.0;
        const double scaleY = snapshot.viewportHeight > 0.0
                                  ? static_cast<double>(client.bottom - client.top) / snapshot.viewportHeight
                                  : 1.0;
        result.left = static_cast<double>(origin.x) + logical.x * scaleX;
        result.top = static_cast<double>(origin.y) + logical.y * scaleY;
        result.width = (std::max)(0.0, logical.width * scaleX);
        result.height = (std::max)(0.0, logical.height * scaleY);
        return result;
    }

    bool fromScreenPoint(
        const Snapshot& snapshot,
        double screenX,
        double screenY,
        double* logicalX,
        double* logicalY
    ) const {
        const HWND window = state_->window();
        RECT client{};
        POINT point{static_cast<LONG>(screenX), static_cast<LONG>(screenY)};
        if (window == nullptr || !GetClientRect(window, &client) || !ScreenToClient(window, &point)) {
            return false;
        }
        const double width = static_cast<double>(client.right - client.left);
        const double height = static_cast<double>(client.bottom - client.top);
        if (point.x < client.left || point.y < client.top || point.x >= client.right || point.y >= client.bottom ||
            width <= 0.0 || height <= 0.0) {
            return false;
        }
        *logicalX = static_cast<double>(point.x - client.left) * snapshot.viewportWidth / width;
        *logicalY = static_cast<double>(point.y - client.top) * snapshot.viewportHeight / height;
        return true;
    }

    std::atomic<ULONG> references_{1};
    std::shared_ptr<BridgeState> state_;
    const std::uint64_t token_;
};

Provider* BridgeState::acquireRoot() {
    std::lock_guard<std::mutex> guard(mutex_);
    if (closed_ || root_ == nullptr) {
        return nullptr;
    }
    root_->AddRef();
    return root_;
}

LRESULT CALLBACK subclassProcedure(
    HWND window,
    UINT message,
    WPARAM wParam,
    LPARAM lParam,
    UINT_PTR,
    DWORD_PTR reference
) {
    auto* state = reinterpret_cast<BridgeState*>(reference);
    if (message == WM_GETOBJECT && static_cast<LONG>(lParam) == UiaRootObjectId && state != nullptr) {
        Provider* root = state->acquireRoot();
        if (root != nullptr) {
            const LRESULT result = UiaReturnRawElementProvider(
                window, wParam, lParam, static_cast<IRawElementProviderSimple*>(root));
            root->Release();
            return result;
        }
    } else if (message == WM_NCDESTROY && state != nullptr) {
        state->closeWindow();
        RemoveWindowSubclass(window, subclassProcedure, kSubclassId);
    }
    return DefSubclassProc(window, message, wParam, lParam);
}

struct SdlWindowAccess {
    HWND window = nullptr;
    std::uint32_t wakeEventType = 0;
    PushSdlEvent pushEvent = nullptr;
};

SdlWindowAccess windowAccessFromSdlId(std::uint32_t windowId) {
    using GetWindowFromId = void* (*)(std::uint32_t);
    using GetWindowProperties = std::uint32_t (*)(void*);
    using GetPointerProperty = void* (*)(std::uint32_t, const char*, void*);
    using RegisterEvents = std::uint32_t (*)(std::int32_t);

    HMODULE sdl = GetModuleHandleW(L"SDL3.dll");
    if (sdl == nullptr) {
        sdl = GetModuleHandleW(L"libSDL3.dll");
    }
    if (sdl == nullptr) {
        return {};
    }
    const auto getWindow = reinterpret_cast<GetWindowFromId>(GetProcAddress(sdl, "SDL_GetWindowFromID"));
    const auto getProperties = reinterpret_cast<GetWindowProperties>(GetProcAddress(sdl, "SDL_GetWindowProperties"));
    const auto getPointer = reinterpret_cast<GetPointerProperty>(GetProcAddress(sdl, "SDL_GetPointerProperty"));
    const auto registerEvents = reinterpret_cast<RegisterEvents>(GetProcAddress(sdl, "SDL_RegisterEvents"));
    const auto pushEvent = reinterpret_cast<PushSdlEvent>(GetProcAddress(sdl, "SDL_PushEvent"));
    if (getWindow == nullptr || getProperties == nullptr || getPointer == nullptr) {
        return {};
    }
    void* window = getWindow(windowId);
    if (window == nullptr) {
        return {};
    }
    const std::uint32_t properties = getProperties(window);
    if (properties == 0) {
        return {};
    }
    HWND result = static_cast<HWND>(getPointer(properties, "SDL.window.win32.hwnd", nullptr));
    if (!IsWindow(result)) {
        return {};
    }
    std::uint32_t wakeEventType = 0;
    if (registerEvents != nullptr && pushEvent != nullptr) {
        const std::uint32_t registered = registerEvents(1);
        if (registered != 0xffffffffu) {
            wakeEventType = registered;
        }
    }
    return {result, wakeEventType, pushEvent};
}

struct BridgeHandle {
    std::shared_ptr<BridgeState> state;
    bool uninitializeCom = false;
};

bool copyArenaString(
    const char* strings,
    std::int64_t stringByteCount,
    std::int64_t offset,
    std::string* result
) {
    if (strings == nullptr || result == nullptr || stringByteCount <= 0 || offset < 0 || offset >= stringByteCount) {
        return false;
    }
    const char* begin = strings + offset;
    const std::size_t available = static_cast<std::size_t>(stringByteCount - offset);
    const void* terminator = std::memchr(begin, 0, available);
    if (terminator == nullptr) {
        return false;
    }
    result->assign(begin, static_cast<const char*>(terminator));
    return true;
}

std::shared_ptr<Snapshot> copySnapshot(
    std::uint64_t revision,
    double viewportWidth,
    double viewportHeight,
    std::uint64_t focusedToken,
    const char* strings,
    std::int64_t stringByteCount,
    const CuiUiaNode* input,
    std::int64_t count
) {
    if (count < 0 || stringByteCount < 0 ||
        (count > 0 && (input == nullptr || strings == nullptr || stringByteCount == 0))) {
        return nullptr;
    }
    auto result = std::make_shared<Snapshot>();
    result->revision = revision;
    result->viewportWidth = (std::max)(0.0, viewportWidth);
    result->viewportHeight = (std::max)(0.0, viewportHeight);
    result->focusedToken = focusedToken;
    result->nodes.reserve(static_cast<std::size_t>(count));
    result->indexByToken.reserve(static_cast<std::size_t>(count));
    for (std::int64_t index = 0; index < count; ++index) {
        const CuiUiaNode& source = input[index];
        if (source.token == 0 || result->indexByToken.find(source.token) != result->indexByToken.end()) {
            return nullptr;
        }
        Node node;
        node.token = source.token;
        if (!copyArenaString(strings, stringByteCount, source.id_offset, &node.id) ||
            !copyArenaString(strings, stringByteCount, source.label_offset, &node.label) ||
            !copyArenaString(strings, stringByteCount, source.value_offset, &node.value) ||
            !copyArenaString(strings, stringByteCount, source.hint_offset, &node.hint)) {
            return nullptr;
        }
        node.role = source.role;
        node.enabled = source.enabled != 0;
        node.selected = source.selected;
        node.checked = source.checked;
        node.actionMask = source.action_mask;
        node.bounds = {source.x, source.y, (std::max)(0.0, source.width), (std::max)(0.0, source.height)};
        node.parent = source.parent_index;
        result->indexByToken.emplace(node.token, index);
        result->nodes.push_back(std::move(node));
    }
    if (!validateParents(result->nodes)) {
        return nullptr;
    }
    if (focusedToken != 0 && result->indexByToken.find(focusedToken) == result->indexByToken.end()) {
        result->focusedToken = 0;
    }
    linkTopology(*result);
    if (!result->nodes.empty()) {
        result->spatialNodes.reserve(result->nodes.size() * 2 - 1);
        result->spatialRoot = buildSpatialNode(*result, 0, count);
    }
    return result;
}

void raiseChanges(
    const std::shared_ptr<BridgeState>& state,
    const std::shared_ptr<const Snapshot>& previous,
    const std::shared_ptr<const Snapshot>& next,
    const CuiUiaChange* changes,
    std::int64_t changeCount
) {
    if (!UiaClientsAreListening()) {
        return;
    }
    Provider* root = state->acquireRoot();
    if (root == nullptr) {
        return;
    }
    bool structureChanged = false;
    for (std::int64_t index = 0; index < changeCount; ++index) {
        if (changes[index].kind == 1 || changes[index].kind == 2 || changes[index].kind == 4) {
            structureChanged = true;
            break;
        }
    }
    if (structureChanged) {
        UiaRaiseStructureChangedEvent(static_cast<IRawElementProviderSimple*>(root),
                                      StructureChangeType_ChildrenInvalidated, nullptr, 0);
    }
    if (previous && previous->focusedToken != next->focusedToken && next->focusedToken != 0) {
        Provider* focused = new (std::nothrow) Provider(state, next->focusedToken);
        if (focused != nullptr) {
            UiaRaiseAutomationEvent(static_cast<IRawElementProviderSimple*>(focused),
                                    UIA_AutomationFocusChangedEventId);
            focused->Release();
        }
    }
    if (previous) {
        for (std::int64_t index = 0; index < changeCount; ++index) {
            if (changes[index].kind != 3) {
                continue;
            }
            const auto oldFound = previous->indexByToken.find(changes[index].token);
            const auto newFound = next->indexByToken.find(changes[index].token);
            if (oldFound == previous->indexByToken.end() || newFound == next->indexByToken.end()) {
                continue;
            }
            const Node& oldNode = previous->nodes[static_cast<std::size_t>(oldFound->second)];
            const Node& newNode = next->nodes[static_cast<std::size_t>(newFound->second)];
            Provider* provider = new (std::nothrow) Provider(state, newNode.token);
            if (provider == nullptr) {
                continue;
            }
            auto raiseString = [&](PROPERTYID property, const std::string& oldValue, const std::string& newValue) {
                if (oldValue == newValue) {
                    return;
                }
                const std::wstring oldWide = utf8ToWide(oldValue.c_str());
                const std::wstring newWide = utf8ToWide(newValue.c_str());
                VARIANT oldVariant;
                VARIANT newVariant;
                VariantInit(&oldVariant);
                VariantInit(&newVariant);
                oldVariant.vt = VT_BSTR;
                oldVariant.bstrVal = SysAllocStringLen(oldWide.data(), static_cast<UINT>(oldWide.size()));
                newVariant.vt = VT_BSTR;
                newVariant.bstrVal = SysAllocStringLen(newWide.data(), static_cast<UINT>(newWide.size()));
                UiaRaiseAutomationPropertyChangedEvent(static_cast<IRawElementProviderSimple*>(provider), property,
                                                       oldVariant, newVariant);
                VariantClear(&oldVariant);
                VariantClear(&newVariant);
            };
            auto raiseBool = [&](PROPERTYID property, bool oldValue, bool newValue) {
                if (oldValue == newValue) {
                    return;
                }
                VARIANT oldVariant;
                VARIANT newVariant;
                VariantInit(&oldVariant);
                VariantInit(&newVariant);
                oldVariant.vt = VT_BOOL;
                oldVariant.boolVal = oldValue ? VARIANT_TRUE : VARIANT_FALSE;
                newVariant.vt = VT_BOOL;
                newVariant.boolVal = newValue ? VARIANT_TRUE : VARIANT_FALSE;
                UiaRaiseAutomationPropertyChangedEvent(static_cast<IRawElementProviderSimple*>(provider), property,
                                                       oldVariant, newVariant);
            };
            auto raiseInt = [&](PROPERTYID property, std::int32_t oldValue, std::int32_t newValue) {
                if (oldValue == newValue) {
                    return;
                }
                VARIANT oldVariant;
                VARIANT newVariant;
                VariantInit(&oldVariant);
                VariantInit(&newVariant);
                oldVariant.vt = VT_I4;
                oldVariant.lVal = oldValue;
                newVariant.vt = VT_I4;
                newVariant.lVal = newValue;
                UiaRaiseAutomationPropertyChangedEvent(static_cast<IRawElementProviderSimple*>(provider), property,
                                                       oldVariant, newVariant);
            };
            raiseString(UIA_NamePropertyId, oldNode.label, newNode.label);
            raiseString(UIA_ValueValuePropertyId, oldNode.value, newNode.value);
            raiseString(UIA_HelpTextPropertyId, oldNode.hint, newNode.hint);
            raiseBool(UIA_IsEnabledPropertyId, oldNode.enabled, newNode.enabled);
            raiseBool(UIA_IsOffscreenPropertyId, !oldNode.bounds.hasArea(), !newNode.bounds.hasArea());
            raiseBool(UIA_IsInvokePatternAvailablePropertyId, (oldNode.actionMask & kActionActivate) != 0,
                      (newNode.actionMask & kActionActivate) != 0);
            raiseBool(UIA_IsValuePatternAvailablePropertyId, (oldNode.actionMask & kActionSetValue) != 0,
                      (newNode.actionMask & kActionSetValue) != 0);
            raiseBool(UIA_IsTogglePatternAvailablePropertyId,
                      oldNode.checked >= 0 && (oldNode.actionMask & kActionActivate) != 0,
                      newNode.checked >= 0 && (newNode.actionMask & kActionActivate) != 0);
            raiseInt(UIA_ToggleToggleStatePropertyId,
                     oldNode.checked <= 0 ? ToggleState_Off : ToggleState_On,
                     newNode.checked <= 0 ? ToggleState_Off : ToggleState_On);
            provider->Release();
        }
    }
    root->Release();
}

}  // namespace

CUI_UIA_EXPORT std::uint64_t cui_uia_abi_version() noexcept {
    return kUiaAbiVersion;
}

CUI_UIA_EXPORT std::uint64_t cui_uia_node_layout() noexcept {
    return layoutFingerprint(sizeof(CuiUiaNode), alignof(CuiUiaNode));
}

CUI_UIA_EXPORT std::uint64_t cui_uia_change_layout() noexcept {
    return layoutFingerprint(sizeof(CuiUiaChange), alignof(CuiUiaChange));
}

CUI_UIA_EXPORT void* cui_uia_create(std::uint32_t sdlWindowId) noexcept {
    try {
        const SdlWindowAccess access = windowAccessFromSdlId(sdlWindowId);
        if (access.window == nullptr) {
            return nullptr;
        }
        const HRESULT comResult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        const bool uninitializeCom = SUCCEEDED(comResult);
        if (FAILED(comResult) && comResult != RPC_E_CHANGED_MODE) {
            return nullptr;
        }
        auto state = std::make_shared<BridgeState>(
            access.window, sdlWindowId, access.wakeEventType, access.pushEvent);
        Provider* root = new (std::nothrow) Provider(state, 0);
        if (root == nullptr) {
            if (uninitializeCom) {
                CoUninitialize();
            }
            return nullptr;
        }
        state->setRoot(root);
        if (!SetWindowSubclass(access.window, subclassProcedure, kSubclassId,
                               reinterpret_cast<DWORD_PTR>(state.get()))) {
            state->detachRoot();
            root->Release();
            if (uninitializeCom) {
                CoUninitialize();
            }
            return nullptr;
        }
        return new BridgeHandle{std::move(state), uninitializeCom};
    } catch (...) {
        return nullptr;
    }
}

CUI_UIA_EXPORT std::int32_t cui_uia_update(
    void* bridge,
    std::uint64_t revision,
    double viewportWidth,
    double viewportHeight,
    std::uint64_t focusedToken,
    const char* strings,
    std::int64_t stringByteCount,
    const CuiUiaNode* nodes,
    std::int64_t nodeCount,
    const CuiUiaChange* changes,
    std::int64_t changeCount
) noexcept {
    if (bridge == nullptr || changeCount < 0 || (changeCount > 0 && changes == nullptr)) {
        return 0;
    }
    try {
        auto* handle = static_cast<BridgeHandle*>(bridge);
        std::shared_ptr<Snapshot> snapshot = copySnapshot(
            revision, viewportWidth, viewportHeight, focusedToken, strings, stringByteCount, nodes, nodeCount);
        if (!snapshot) {
            return 0;
        }
        const std::shared_ptr<const Snapshot> previous = handle->state->snapshot();
        if (!handle->state->publish(snapshot)) {
            return 0;
        }
        raiseChanges(handle->state, previous, snapshot, changes, changeCount);
        return 1;
    } catch (...) {
        return 0;
    }
}

CUI_UIA_EXPORT std::int64_t cui_uia_next_action_value_size(void* bridge) noexcept {
    if (bridge == nullptr) {
        return -1;
    }
    try {
        return static_cast<BridgeHandle*>(bridge)->state->nextActionValueSize();
    } catch (...) {
        return -1;
    }
}

CUI_UIA_EXPORT std::int32_t cui_uia_pop_action(
    void* bridge,
    std::uint64_t* token,
    std::int32_t* kind,
    char* value,
    std::int64_t valueCapacity
) noexcept {
    if (bridge == nullptr) {
        return 0;
    }
    try {
        return static_cast<BridgeHandle*>(bridge)->state->popAction(token, kind, value, valueCapacity) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

CUI_UIA_EXPORT void cui_uia_complete_action(
    void* bridge,
    std::uint64_t token,
    std::int32_t kind,
    std::int32_t succeeded
) noexcept {
    if (bridge == nullptr || succeeded == 0 || kind != static_cast<std::int32_t>(ActionKind::Activate) ||
        !UiaClientsAreListening()) {
        return;
    }
    try {
        auto* handle = static_cast<BridgeHandle*>(bridge);
        const std::shared_ptr<const Snapshot> snapshot = handle->state->snapshot();
        if (!snapshot || snapshot->indexByToken.find(token) == snapshot->indexByToken.end()) {
            return;
        }
        Provider* provider = new (std::nothrow) Provider(handle->state, token);
        if (provider != nullptr) {
            UiaRaiseAutomationEvent(static_cast<IRawElementProviderSimple*>(provider), UIA_Invoke_InvokedEventId);
            provider->Release();
        }
    } catch (...) {
        return;
    }
}

CUI_UIA_EXPORT std::uint64_t cui_uia_revision(void* bridge) noexcept {
    if (bridge == nullptr) {
        return 0;
    }
    try {
        const std::shared_ptr<const Snapshot> snapshot = static_cast<BridgeHandle*>(bridge)->state->snapshot();
        return snapshot ? snapshot->revision : 0;
    } catch (...) {
        return 0;
    }
}

CUI_UIA_EXPORT std::int64_t cui_uia_node_count(void* bridge) noexcept {
    if (bridge == nullptr) {
        return -1;
    }
    try {
        const std::shared_ptr<const Snapshot> snapshot = static_cast<BridgeHandle*>(bridge)->state->snapshot();
        return snapshot ? static_cast<std::int64_t>(snapshot->nodes.size()) : -1;
    } catch (...) {
        return -1;
    }
}

CUI_UIA_EXPORT void cui_uia_close(void* bridge) noexcept {
    if (bridge == nullptr) {
        return;
    }
    try {
        auto* handle = static_cast<BridgeHandle*>(bridge);
        const HWND window = handle->state->window();
        if (window != nullptr) {
            RemoveWindowSubclass(window, subclassProcedure, kSubclassId);
        }
        handle->state->closeWindow();
        Provider* root = handle->state->detachRoot();
        if (root != nullptr) {
            UiaDisconnectProvider(static_cast<IRawElementProviderSimple*>(root));
            root->Release();
        }
        const bool uninitializeCom = handle->uninitializeCom;
        delete handle;
        if (uninitializeCom) {
            CoUninitialize();
        }
    } catch (...) {
        return;
    }
}
