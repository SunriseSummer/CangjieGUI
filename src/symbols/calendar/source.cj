package cui.symbols.calendar

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared calendar template icon; initialized once without I/O or decoding. */
public let ICON_CALENDAR: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<rect x=\"3.5\" y=\"5\" width=\"17\" height=\"16\" rx=\"2\"/><path d=\"M7.5 3v4m9-4v4M4 10h16M8 14h2m4 0h2m-8 3.5h2\"/>" +
        "</g></svg>").toArray(),
    typeHint: "SVG"
)
