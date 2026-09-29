import AppKit
import Foundation
let name = CommandLine.arguments[1], folder = URL(fileURLWithPath:CommandLine.arguments[2])
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
for (label,size) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    let cg = NSGraphicsContext.current!.cgContext; cg.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    let rect = NSRect(x:42,y:42,width:940,height:940), background = NSBezierPath(roundedRect:rect,xRadius:210,yRadius:210)
    let colors:[NSColor] = name == "FocusDock" ? [.systemTeal,NSColor(red:0.04,green:0.34,blue:0.38,alpha:1)] : name == "PortPeek" ? [.systemIndigo,NSColor(red:0.12,green:0.12,blue:0.42,alpha:1)] : [.systemBlue,NSColor(red:0.04,green:0.24,blue:0.60,alpha:1)]
    NSGradient(colors:colors)!.draw(in:background,angle:-90)
    NSColor.white.setStroke(); NSColor.white.setFill()
    if name == "FocusDock" {
        let circle=NSBezierPath(ovalIn:NSRect(x:245,y:245,width:534,height:534)); circle.lineWidth=44; circle.stroke()
        let hand=NSBezierPath(); hand.move(to:NSPoint(x:512,y:704));hand.line(to:NSPoint(x:512,y:512));hand.line(to:NSPoint(x:640,y:420)); hand.lineWidth=48;hand.lineCapStyle = .round;hand.lineJoinStyle = .round;hand.stroke()
        NSBezierPath(ovalIn:NSRect(x:485,y:485,width:54,height:54)).fill()
    } else if name == "PortPeek" {
        for (index,x) in [300,512,724].enumerated() { let column=NSBezierPath(roundedRect:NSRect(x:CGFloat(x-38),y:260,width:76,height:CGFloat([245,400,310][index])),xRadius:38,yRadius:38);column.fill();NSBezierPath(ovalIn:NSRect(x:CGFloat(x-48),y:CGFloat([570,725,635][index]),width:96,height:96)).fill() }
    } else {
        let page=NSBezierPath(roundedRect:NSRect(x:270,y:230,width:484,height:564),xRadius:48,yRadius:48);page.lineWidth=34;page.stroke()
        for (y,w) in [(635,300),(520,228),(405,300)] { let line=NSBezierPath();line.move(to:NSPoint(x:360,y:y));line.line(to:NSPoint(x:360+w,y:y));line.lineWidth=36;line.lineCapStyle = .round;line.stroke() }
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("icon_\(label).png"))
}
