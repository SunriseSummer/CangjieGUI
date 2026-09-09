package cui.symbols.help

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared help template icon; initialized once without I/O or decoding. */
public let ICON_HELP: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M9 9a3 3 0 0 1 6 0c0 2-3 2-3 4m0 3.5v.1\"/>" + "</g></svg>")
        .toArray(),
    typeHint: "SVG"
)
