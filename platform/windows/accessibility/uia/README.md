# Windows UI Automation provider

This directory contains CUI's production Windows accessibility backend. It exposes the platform-neutral
semantic tree to Windows UI Automation clients such as Narrator, Inspect, assistive technology, and desktop
automation tools. It is an optional runtime component, not a test fixture and not part of the rendering core.

Build it from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .dev/platform/windows/build_uia.ps1
```

The generated DLL is written to `target/native/windows/<arch>/cui_uia.dll`. Release packaging copies that DLL
next to the application executable. `.dev/platform/windows/check_uia.ps1` runs the real out-of-process UIA client
qualification.

The C ABI and ownership rules are documented in [ABI.md](ABI.md).
