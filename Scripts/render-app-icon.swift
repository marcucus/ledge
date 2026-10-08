#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: render-app-icon.swift <source.png> <output.png>\n".utf8))
    exit(1)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: sourceURL) else {
    FileHandle.standardError.write(Data("Image source illisible : \(sourceURL.path)\n".utf8))
    exit(1)
}

let side: CGFloat = 1_024
let margin: CGFloat = 100
let body = NSRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2)
let cropSide: CGFloat = 650
let sourceCrop = NSRect(x: 187, y: 77, width: cropSide, height: cropSide)
let canvas = NSImage(size: NSSize(width: side, height: side))

canvas.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: canvas.size).fill()

let shape = NSBezierPath(
    roundedRect: body,
    xRadius: body.width * 0.2237,
    yRadius: body.height * 0.2237
)
shape.addClip()
NSGraphicsContext.current?.imageInterpolation = .high
source.draw(in: body, from: sourceCrop, operation: .copy, fraction: 1)
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Impossible d'encoder l'icône en PNG\n".utf8))
    exit(1)
}

do {
    try png.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("Écriture de l'icône impossible : \(error)\n".utf8))
    exit(1)
}
