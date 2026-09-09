package cui.symbols.external_link

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared external link template icon; initialized once without I/O or decoding. */
public let ICON_EXTERNAL_LINK: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M13 4h7v7m0-7-9 9M9 5H5a1 1 0 0 0-1 1v13a1 1 0 0 0 1 1h13a1 1 0 0 0 1-1v-4\"/>" + "</g></svg>")
        .toArray(),
    typeHint: "SVG"
)
