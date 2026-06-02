import AppKit
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make-rounded-icon.swift <input> <output>")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024
let iconSize = 900
let iconInset = (size - iconSize) / 2
let cornerRadius: CGFloat = 198
let blackThreshold: UInt8 = 18

guard let source = NSImage(contentsOf: inputURL) else {
    fatalError("Could not read icon at \(inputURL.path)")
}

var proposedRect = NSRect(origin: .zero, size: source.size)
guard let sourceImage = source.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
    fatalError("Could not decode icon at \(inputURL.path)")
}

var pixels = [UInt8](repeating: 0, count: size * size * 4)

guard let context = CGContext(
    data: &pixels,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGImageByteOrderInfo.order32Big.rawValue
) else {
    fatalError("Could not create icon render context")
}

let canvasRect = CGRect(x: 0, y: 0, width: size, height: size)
let iconRect = CGRect(x: iconInset, y: iconInset, width: iconSize, height: iconSize)

context.clear(canvasRect)
context.addPath(CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
context.clip()
context.draw(sourceImage, in: iconRect)

for index in stride(from: 0, to: pixels.count, by: 4) {
    let red = pixels[index]
    let green = pixels[index + 1]
    let blue = pixels[index + 2]

    if red <= blackThreshold && green <= blackThreshold && blue <= blackThreshold {
        pixels[index] = 0
        pixels[index + 1] = 0
        pixels[index + 2] = 0
        pixels[index + 3] = 0
    }
}

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
