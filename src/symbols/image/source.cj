package cui.symbols.image

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared image template icon; initialized once without I/O or decoding. */
public let ICON_IMAGE: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<rect x=\"3\" y=\"3\" width=\"18\" height=\"18\" rx=\"2\"/><circle cx=\"8\" cy=\"8\" r=\"1.5\"/><path d=\"m3 17 5-5 4 4 4-6 5 7\"/>" +
        "</g></svg>").toArray(),
    typeHint: "SVG"
)
