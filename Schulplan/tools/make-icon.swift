import AppKit

let S = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
// flip so y grows downwards
cg.translateBy(x: 0, y: CGFloat(S)); cg.scaleBy(x: 1, y: -1)

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255,
            blue: CGFloat(h & 255) / 255, alpha: a)
}

// Background: diagonal blue gradient (the app's accent, deepened)
let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                      colors: [rgb(0x5B9CFF), rgb(0x2F6FDF), rgb(0x1E4FB8)] as CFArray,
                      locations: [0, 0.55, 1])!
cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: S, y: S), options: [])

// Soft light from the top for depth
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                      colors: [rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
cg.drawRadialGradient(glow, startCenter: CGPoint(x: 300, y: 120), startRadius: 0,
                      endCenter: CGPoint(x: 300, y: 120), endRadius: 760, options: [])

// Week grid: 3 days x 3 periods
let left: CGFloat = 196, top: CGFloat = 206, width: CGFloat = 632, height: CGFloat = 612
let gap: CGFloat = 30
let colW = (width - 2 * gap) / 3
let rowH = (height - 2 * gap) / 3
let radius: CGFloat = 44

func rect(_ col: Int, _ row: Int, _ span: Int) -> CGRect {
    CGRect(x: left + CGFloat(col) * (colW + gap), y: top + CGFloat(row) * (rowH + gap),
           width: colW, height: CGFloat(span) * rowH + CGFloat(span - 1) * gap)
}

func cell(_ r: CGRect, _ color: CGColor, shadow: Bool = true) {
    cg.saveGState()
    if shadow { cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: rgb(0x0B2A6B, 0.35)) }
    cg.setFillColor(color)
    cg.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    cg.fillPath()
    cg.restoreGState()
}

// day 1: double lesson + single
cell(rect(0, 0, 2), rgb(0xFFFFFF))
cell(rect(0, 2, 1), rgb(0xFFFFFF, 0.38), shadow: false)
// day 2: free period, then the exam (orange) as a double
cell(rect(1, 0, 1), rgb(0xFFFFFF, 0.38), shadow: false)
cell(rect(1, 1, 2), rgb(0xFFA733))
// day 3: lesson, lesson, homework done
cell(rect(2, 0, 1), rgb(0xFFFFFF))
cell(rect(2, 1, 1), rgb(0xFFFFFF, 0.38), shadow: false)
let done = rect(2, 2, 1)
cell(done, rgb(0xFFFFFF))

// Tick in the last cell
let c = CGPoint(x: done.midX, y: done.midY)
let check = CGMutablePath()
check.move(to: CGPoint(x: c.x - 48, y: c.y + 2))
check.addLine(to: CGPoint(x: c.x - 14, y: c.y + 36))
check.addLine(to: CGPoint(x: c.x + 50, y: c.y - 34))
cg.setStrokeColor(rgb(0x2F6FDF))
cg.setLineWidth(30); cg.setLineCap(.round); cg.setLineJoin(.round)
cg.addPath(check); cg.strokePath()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
