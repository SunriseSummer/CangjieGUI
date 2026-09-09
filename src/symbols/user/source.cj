package cui.symbols.user

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared user template icon; initialized once without I/O or decoding. */
public let ICON_USER: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<circle cx=\"12\" cy=\"7.5\" r=\"4\"/><path d=\"M4.5 21v-2a7.5 7.5 0 0 1 15 0v2\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
