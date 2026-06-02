import AppKit
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make-rounded-icon.swift <input> <output>")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024
let cornerRadius: CGFloat = 224

guard let source = NSImage(contentsOf: inputURL) else {
    fatalError("Could not read icon at \(inputURL.path)")
}

var proposedRect = NSRect(origin: .zero, size: source.size)
guard let sourceImage = source.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
    fatalError("Could not decode icon at \(inputURL.path)")
}

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create icon render context")
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)
context.clear(rect)
context.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
context.clip()
context.draw(sourceImage, in: rect)

guard let outputImage = context.makeImage() else {
    fatalError("Could not render icon image")
}

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create PNG destination")
}

CGImageDestinationAddImage(destination, outputImage, nil)

if !CGImageDestinationFinalize(destination) {
    fatalError("Could not write rounded icon to \(outputURL.path)")
}
