package cui.symbols.download

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared download template icon; initialized once without I/O or decoding. */
public let ICON_DOWNLOAD: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M12 3v12m-5-5 5 5 5-5M4 16v4h16v-4\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
