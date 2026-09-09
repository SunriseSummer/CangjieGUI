package cui.symbols.save

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared save template icon; initialized once without I/O or decoding. */
public let ICON_SAVE: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M5 3.5h12l3.5 3.5v13H3.5V5zM8 3.5v6h8v-6M7.5 20v-7h9v7\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
