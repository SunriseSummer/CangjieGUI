# UIA bridge ABI and ownership

The Cangjie desktop backend loads `cui_uia.dll` dynamically through SDL and validates the ABI version plus the
size and alignment fingerprints of `CuiUiaNode` and `CuiUiaChange` before creating a bridge.

All pointers passed to `cui_uia_update` are borrowed for that call only. Nodes carry validated offsets into one
bounded UTF-8 arena instead of independent raw string pointers. The provider synchronously copies the node
records, strings, and change data it needs before returning and never retains caller-owned pointers. Cangjie
allocates and frees its update buffers; C++ owns every snapshot published after the copy.

Every exported function is a non-throwing C boundary. Native exceptions are converted to the function's
failure sentinel and must never unwind into the Cangjie runtime. COM callbacks read immutable native snapshots
and enqueue bounded actions; they do not enter Cangjie directly. The UI thread drains those actions and reports
completion through the same bridge handle.

Changing an exported signature, structure field layout, ownership rule, or string encoding requires an ABI
version increment and coordinated changes in `src/desktop/windows_uia_abi_raw.cj` and
`src/desktop/windows_uia_raw.cj`.
