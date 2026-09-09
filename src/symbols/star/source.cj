package cui.symbols.star

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared star template icon; initialized once without I/O or decoding. */
public let ICON_STAR: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"m12 2.5 3 6.1 6.7 1-4.8 4.7 1.1 6.7-6-3.2-6 3.2 1.1-6.7-4.8-4.7 6.7-1z\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
