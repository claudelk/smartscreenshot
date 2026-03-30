#!/usr/bin/env swift
// Renders the SF Symbol "camera.viewfinder" as a 1024x1024 PNG.
// Usage: swift scripts/generate-icon-png.swift

import AppKit

let size = NSSize(width: 1024, height: 1024)
let padding: CGFloat = 140 // padding around the symbol

// Load the SF Symbol
guard let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil) else {
    fputs("ERROR: SF Symbol 'camera.viewfinder' not found\n", stderr)
    exit(1)
}

// Create the output image
let image = NSImage(size: size)
image.lockFocus()

// Background: rounded rect with gradient
let bgRect = NSRect(origin: .zero, size: size)
let cornerRadius: CGFloat = 220
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Dark gradient background
let gradient = NSGradient(
    starting: NSColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0),
    ending: NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
)!
gradient.draw(in: bgPath, angle: -90)

// Draw the symbol in white, centered
let symbolRect = NSRect(
    x: padding,
    y: padding,
    width: size.width - padding * 2,
    height: size.height - padding * 2
)

let config = NSImage.SymbolConfiguration(pointSize: 500, weight: .regular)
    .applying(.init(paletteColors: [.white]))
let configured = symbol.withSymbolConfiguration(config)!

configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)

image.unlockFocus()

// Convert to PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("ERROR: Failed to create PNG\n", stderr)
    exit(1)
}

// Write to Distribution/AppIcon-1024.png
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputPath = projectRoot.appendingPathComponent("Distribution/AppIcon-1024.png")

do {
    try png.write(to: outputPath)
    print("Wrote \(outputPath.path) (\(png.count) bytes)")
} catch {
    fputs("ERROR: \(error.localizedDescription)\n", stderr)
    exit(1)
}
