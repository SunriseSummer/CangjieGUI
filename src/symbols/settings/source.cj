package cui.symbols.settings

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared settings template icon; initialized once without I/O or decoding. */
public let ICON_SETTINGS: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"m9 3-.5 2.5-2 1.2L4 6l-2 3.5 2 1.8v2.4l-2 1.8L4 19l2.5-.7 2 1.2L9 22h6l.5-2.5 2-1.2 2.5.7 2-3.5-2-1.8v-2.4l2-1.8L20 6l-2.5.7-2-1.2L15 3z\"/><circle cx=\"12\" cy=\"12.5\" r=\"3\"/>" +
        "</g></svg>").toArray(),
    typeHint: "SVG"
)
