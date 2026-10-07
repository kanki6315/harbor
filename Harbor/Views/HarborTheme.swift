import SwiftUI

extension Color {
    static let harborNavy = Color(red: 13/255, green: 39/255, blue: 71/255)
    static let harborBlue = Color(red: 47/255, green: 140/255, blue: 230/255)
    static let harborWave = Color(red: 124/255, green: 195/255, blue: 243/255)
    static let harborSun = Color(red: 1, green: 223/255, blue: 166/255)
}

struct HarborGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else { content.glassEffect(.regular, in: .capsule) }
    }
}

extension View {
    func harborGlass() -> some View { modifier(HarborGlass()) }
}

/// The supplied SVG logo, rendered from its original paths into a resolution-independent SwiftUI canvas.
struct HarborMark: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 1024, y: size.height / 1024)
            var arch = Path()
            arch.move(to: CGPoint(x: 176, y: 680))
            arch.addLine(to: CGPoint(x: 176, y: 494))
            arch.addArc(center: CGPoint(x: 512, y: 494), radius: 336, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            arch.addLine(to: CGPoint(x: 848, y: 680))
            arch.addQuadCurve(to: CGPoint(x: 824, y: 704), control: CGPoint(x: 848, y: 704))
            arch.addLine(to: CGPoint(x: 742, y: 704))
            arch.addQuadCurve(to: CGPoint(x: 718, y: 680), control: CGPoint(x: 718, y: 704))
            arch.addLine(to: CGPoint(x: 718, y: 506))
            arch.addArc(center: CGPoint(x: 512, y: 506), radius: 206, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
            arch.addLine(to: CGPoint(x: 306, y: 680))
            arch.addQuadCurve(to: CGPoint(x: 282, y: 704), control: CGPoint(x: 306, y: 704))
            arch.addLine(to: CGPoint(x: 200, y: 704))
            arch.addQuadCurve(to: CGPoint(x: 176, y: 680), control: CGPoint(x: 176, y: 704))
            arch.closeSubpath()
            context.fill(arch, with: .color(Color(red: 250/255, green: 250/255, blue: 247/255)))
            context.fill(Path(ellipseIn: CGRect(x: 426, y: 450, width: 172, height: 172)), with: .color(.harborSun))
            // Preserve the original water silhouette and proportions.
            var water = Path()
            water.move(to: CGPoint(x: 370, y: 680)); water.addLine(to: CGPoint(x: 654, y: 680))
            water.addArc(center: CGPoint(x: 654, y: 705), radius: 25, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            water.addLine(to: CGPoint(x: 583, y: 730))
            water.addArc(center: CGPoint(x: 583, y: 750), radius: 20, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
            water.addLine(to: CGPoint(x: 709, y: 770))
            water.addArc(center: CGPoint(x: 709, y: 795), radius: 25, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            water.addLine(to: CGPoint(x: 315, y: 820))
            water.addArc(center: CGPoint(x: 315, y: 795), radius: 25, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            water.addLine(to: CGPoint(x: 441, y: 770))
            water.addArc(center: CGPoint(x: 441, y: 750), radius: 20, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
            water.addLine(to: CGPoint(x: 370, y: 730))
            water.addArc(center: CGPoint(x: 370, y: 705), radius: 25, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            water.closeSubpath()
            context.fill(water, with: .color(Color(red: 81/255, green: 181/255, blue: 230/255)))
            context.fill(Path(roundedRect: CGRect(x: 402, y: 850, width: 220, height: 50), cornerRadius: 25), with: .color(.harborBlue))
        }.accessibilityHidden(true)
    }
}

/// Still, locally drawn Horizon artwork. No network assets or motion behind browser controls.
struct HorizonArtwork: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(stops: [
                    .init(color: .harborNavy, location: 0),
                    .init(color: Color(red: 0.12, green: 0.36, blue: 0.57), location: 0.42),
                    .init(color: .harborWave.opacity(0.8), location: 0.66),
                    .init(color: .harborSun, location: 0.78),
                    .init(color: .harborNavy, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                Canvas { context, canvas in
                    let horizon = canvas.height * 0.75
                    let center = canvas.width * 0.58
                    context.fill(Path(ellipseIn: CGRect(x: center - 28, y: horizon - 55, width: 56, height: 56)), with: .color(.harborSun))
                    var hills = Path()
                    hills.move(to: CGPoint(x: 0, y: horizon - 30))
                    hills.addCurve(to: CGPoint(x: center - 20, y: horizon + 3), control1: CGPoint(x: canvas.width * 0.18, y: horizon - 25), control2: CGPoint(x: canvas.width * 0.30, y: horizon + 5))
                    hills.addCurve(to: CGPoint(x: canvas.width, y: horizon - 22), control1: CGPoint(x: canvas.width * 0.82, y: horizon + 4), control2: CGPoint(x: canvas.width * 0.84, y: horizon - 22))
                    hills.addLine(to: CGPoint(x: canvas.width, y: horizon + 20))
                    hills.addLine(to: CGPoint(x: 0, y: horizon + 20)); hills.closeSubpath()
                    context.fill(hills, with: .color(Color(red: 0.08, green: 0.27, blue: 0.44)))
                    let sea = Path(CGRect(x: 0, y: horizon + 6, width: canvas.width, height: canvas.height - horizon))
                    context.fill(sea, with: .linearGradient(Gradient(colors: [.harborBlue.opacity(0.8), .harborNavy]), startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: canvas.height)))
                    for index in 0..<32 {
                        let y = horizon + 8 + CGFloat(index) * 5.3
                        let width = 25 + CGFloat(index % 5) * 10 + CGFloat(index) * 1.1
                        let shift = sin(Double(index) * 2.1) * 12
                        context.fill(Path(ellipseIn: CGRect(x: center - width/2 + shift, y: y, width: width, height: 2 + CGFloat(index % 3))), with: .color(.harborSun.opacity(max(0, 0.7 - Double(index) * 0.025))))
                        var ripple = Path()
                        let start = CGFloat((index * 73) % 200) / 200 * canvas.width
                        ripple.move(to: CGPoint(x: start, y: y + 2))
                        ripple.addLine(to: CGPoint(x: min(canvas.width, start + 70), y: y + 2))
                        context.stroke(ripple, with: .color(.harborWave.opacity(0.16)), lineWidth: 1)
                    }
                }
                if colorScheme == .dark { Color.harborNavy.opacity(0.18) }
            }.frame(width: size.width, height: size.height)
        }.accessibilityHidden(true)
    }
}
