package cui.core

/* Bridges explicit retained phase invalidation into the nearest automatic render boundary. */
class AutomaticRenderPhaseSink {
    let invalidateMeasure: () -> Unit
    let invalidateLayout: () -> Unit
    let invalidatePaint: () -> Unit

    init(invalidateMeasure: () -> Unit, invalidateLayout: () -> Unit, invalidatePaint: () -> Unit) {
        this.invalidateMeasure = invalidateMeasure
        this.invalidateLayout = invalidateLayout
        this.invalidatePaint = invalidatePaint
    }
}

func noteAutomaticRenderDamage(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.noteDamage()
            case None => ()
        }
    }
}

func invalidateAutomaticRenderMeasure(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.invalidateDescendantMeasure()
            case None => ()
        }
    }
}

func invalidateAutomaticRenderLayout(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.invalidateDescendantLayout()
            case None => ()
        }
    }
}

func invalidateAutomaticRenderPaint(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.invalidateDescendantPaint()
            case None => ()
        }
    }
}
