package cui.symbols.folder

import cui.media.IconSource

// Original CUI artwork. One immutable source per imported package; decoding remains demand-driven.
/** Shared folder template icon; initialized once without I/O or decoding. */
public let ICON_FOLDER: IconSource = IconSource.memory(
    // cjcheck-ignore: public-endpoint # SVG namespace identifier, not a network endpoint.
    ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\">" +
        "<g fill=\"none\" stroke=\"#000\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\">" +
        "<path d=\"M3.5 9V5.5h6l2 2H20v3M3.5 10H21l-2.5 10H5z\"/>" + "</g></svg>").toArray(),
    typeHint: "SVG"
)
