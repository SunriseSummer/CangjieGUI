package cui.symbols.document

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared document template icon; initialized once without I/O or decoding. */
public let ICON_DOCUMENT: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M6 3h8l4 4v14H6zM14 3v5h4M9 12h6m-6 4h6\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
