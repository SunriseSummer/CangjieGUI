package cui.symbols.heart

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared heart template icon; initialized once without I/O or decoding. */
public let ICON_HEART: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M12 20S2.5 14 2.5 8a5 5 0 0 1 9.5-2 5 5 0 0 1 9.5 2C21.5 14 12 20 12 20z\"/>" + "</g></svg>")
        .toArray(),
    typeHint: "SVG"
)
