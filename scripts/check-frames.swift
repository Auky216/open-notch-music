import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
var failures: [String] = []
var checked = 0
for tag in ["open", "close"] {
    let data = try Data(contentsOf: directory.appendingPathComponent("\(tag)-frames.json"))
    let frames = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
    for frame in frames {
        let name = frame["file"] as! String
        let width = frame["width"] as! Double
        let height = frame["height"] as! Double
        let canvasWidth = frame["canvasWidth"] as? Double ?? 548
        let canvasHeight = frame["canvasHeight"] as? Double ?? 298
        let image = NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(name)))!
        let scale = Double(image.pixelsWide) / canvasWidth
        let left = (canvasWidth - width) / 2
        func alpha(_ x: Double, _ y: Double) -> CGFloat {
            let px = min(image.pixelsWide - 1, max(0, Int(x * scale)))
            let py = min(image.pixelsHigh - 1, max(0, Int(y * scale)))
            return image.colorAt(x: px, y: py)?.alphaComponent ?? 0
        }
        // Outside the moving silhouette must stay transparent in every intermediate frame.
        var leaks = 0
        for y in stride(from: 2.0, to: canvasHeight, by: 7) {
            for x in stride(from: 2.0, to: canvasWidth, by: 7) {
                if x < left - 2 || x > left + width + 2 || y > height + 2 {
                    if alpha(x, y) > 0.02 { leaks += 1 }
                }
            }
        }
        if leaks > 0 { failures.append("\(name): \(leaks) píxeles de muestra fuera del contorno") }
        if alpha(274, min(height / 2, 15)) < 0.95 { failures.append("\(name): centro transparente") }
        if alpha(left + 35, 15) < 0.95 || alpha(left + width - 35, 15) < 0.95 {
            failures.append("\(name): franja superior de la isla no opaca")
        }
        if alpha(left + 14, height - 2) > 0.05 { failures.append("\(name): esquina inferior rectangular") }
        checked += 1
    }
}
let report: [String: Any] = ["framesChecked": checked, "failures": failures, "allPassed": failures.isEmpty]
let output = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try output.write(to: directory.appendingPathComponent("silhouette.json"))
print(String(data: output, encoding: .utf8)!)
if !failures.isEmpty { exit(1) }
