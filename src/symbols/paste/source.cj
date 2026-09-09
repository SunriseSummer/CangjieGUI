package cui.symbols.paste

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared paste template icon; initialized once without I/O or decoding. */
public let ICON_PASTE: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M8 5H5a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1h-3\"/><rect x=\"8\" y=\"3\" width=\"8\" height=\"4\" rx=\"1\"/><path d=\"M8 12h8m-8 4h6\"/>" +
        "</g></svg>").toArray(),
    typeHint: "SVG"
)
