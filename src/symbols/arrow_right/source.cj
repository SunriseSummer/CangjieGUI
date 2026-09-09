package cui.symbols.arrow_right

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared arrow right template icon; initialized once without I/O or decoding. */
public let ICON_ARROW_RIGHT: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M4 12h16m-7-7 7 7-7 7\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
