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
        dispatchWithCompletion(event, prepare, route, complete)
    }
}

/** Dispatches one deferred native event while installing its event-time metadata snapshot. */
protected func dispatchEventRecord(
    record: UiEventRecord,
    context: UiContext,
    prepare: (UiEvent) -> Unit,
    route: (UiEvent) -> Unit,
    complete: (UiEvent) -> Unit
): Unit {
    context.beginEvent(record.metadata)
    try {
        dispatchWithCompletion(record.event, prepare, route, complete)
    } finally {
        context.endEvent()
    }
}

private func dispatchWithCompletion(event: UiEvent, prepare: (UiEvent) -> Unit, route: (UiEvent) -> Unit,
    complete: (UiEvent) -> Unit): Unit {
    try {
        prepare(event)
        route(event)
    } catch (error: Exception) {
        throw rollbackUiFailure(
            error,
            {
                =>
                complete(event);
                None
            }
        )
    }
    complete(event)
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
        dispatchEventRecord(record, context, prepare, route, complete)
    }
}
