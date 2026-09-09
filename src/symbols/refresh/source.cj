package cui.symbols.refresh

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared refresh template icon; initialized once without I/O or decoding. */
public let ICON_REFRESH: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M19.5 8A8 8 0 0 0 5 6l-2 4m0-5v5h5m-3.5 6A8 8 0 0 0 19 18l2-4m0 5v-5h-5\"/>" + "</g></svg>")
        .toArray(),
    typeHint: "SVG"
)
