package cui.symbols.trash

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared trash template icon; initialized once without I/O or decoding. */
public let ICON_TRASH: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M3.5 6.5h17M9 6V3.5h6V6M6 7l1 13.5h10L18 7M10 10v7m4-7v7\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
