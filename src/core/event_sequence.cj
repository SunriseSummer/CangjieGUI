package cui.core

import sdl.{UiEvent, UiEventRecord}

/*
 * Runs the shell's per-event lifecycle in one place. DesktopApp and WidgetTestHost supply their
 * routing policies, while pointer preparation and completion remain guaranteed to bracket every
 * event in arrival order.
 */
protected func dispatchEventSequence(
    events: Iterable<UiEvent>,
    prepare: (UiEvent) -> Unit,
    route: (UiEvent) -> Unit,
    complete: (UiEvent) -> Unit
): Unit {
    for (event in events) {
        prepare(event)
        route(event)
        complete(event)
    }
}

/** Dispatches deferred native events while installing each event-time metadata snapshot. */
protected func dispatchEventRecordSequence(
    events: Iterable<UiEventRecord>,
    context: UiContext,
    prepare: (UiEvent) -> Unit,
    route: (UiEvent) -> Unit,
    complete: (UiEvent) -> Unit
): Unit {
    for (record in events) {
        context.beginEvent(record.metadata)
        try {
            prepare(record.event)
            route(record.event)
            complete(record.event)
        } finally {
            context.endEvent()
        }
    }
}
