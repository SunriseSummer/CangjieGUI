package cui.symbols.warning

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared warning template icon; initialized once without I/O or decoding. */
public let ICON_WARNING: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M10.3 4a2 2 0 0 1 3.4 0L22 18.5a1.3 1.3 0 0 1-1.2 2H3.2a1.3 1.3 0 0 1-1.2-2zM12 9v4m0 3.5v.1\"/>" +
        "</g></svg>").toArray(),
    typeHint: "SVG"
)
