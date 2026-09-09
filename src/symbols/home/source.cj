package cui.symbols.home

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared home template icon; initialized once without I/O or decoding. */
public let ICON_HOME: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"m3 10 9-7 9 7M5.5 9v11h5v-6h3v6h5V9\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
