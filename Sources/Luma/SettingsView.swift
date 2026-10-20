import AppKit
import SwiftUI
import ServiceManagement
import LumaCore

private enum Palette {
    static let amber = Color(red: 0.90, green: 0.60, blue: 0.29)
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.20)
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.115, blue: 0.14) : Color(red: 0.965, green: 0.959, blue: 0.945)
    }
    static let cream = Color(red: 0.99, green: 0.94, blue: 0.85)
}

struct SettingsView: View {
    @ObservedObject var model: LumaModel
    var width: CGFloat = 440
    @Environment(\.colorScheme) private var scheme
    @State private var showingInfo = false
    private static let icon = Bundle.main.url(forResource: "LumaIcon", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    private var surface: Color { scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.28) }
    private var room: String {
        guard let lux = model.lux else { return "Waiting for the sensor" }
        if lux < model.darkThreshold { return "A darker room" }
        if lux > model.lightThreshold { return "A brighter room" }
        return "Soft ambient light"
    }
    private var status: String {
        if model.issue != nil { return "Permission needed" }
        if model.status.contains("Waiting for steady") { return "Waiting for steady light…" }
        if model.status.contains("lid") { return "Lid closed · switching paused" }
        if model.status.contains("wake") { return "Sleeping · switching paused" }
        if model.lux == nil { return "Keeping your current appearance" }
        return model.enabled ? "Luma is following your room" : "Automatic switching is paused"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                if let image = Self.icon {
                    Image(nsImage: image).resizable().frame(width: 32, height: 32)
                }
                Text("Luma").font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(model.lux == nil ? Color.secondary : Color(red: 0.43, green: 0.68, blue: 0.52)).frame(width: 6, height: 6)
                    Text(model.lux == nil ? "Sensor waiting" : "Sensor connected").font(.system(size: 11, weight: .medium))
                }.foregroundStyle(.secondary)
                Button { showingInfo.toggle() } label: {
                    Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).help("How Luma works")
                    .popover(isPresented: $showingInfo, arrowEdge: .bottom) { information }
            }.padding(.bottom, 12)

            hero

            HStack {
                Text("Appearance").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.enabled ? "Adapts automatically" : "Manual until you choose Auto")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.top, 17).padding(.bottom, 8)
            HStack(spacing: 10) {
                mode("Auto", subtitle: "Follows the room", symbol: "circle.lefthalf.filled", selected: model.enabled) { model.setEnabled(true) }
                mode("Light", subtitle: "Keep things bright", symbol: "sun.max", selected: !model.enabled && model.current == .light) { model.manual(.light) }
                mode("Dark", subtitle: "Keep things dark", symbol: "moon", selected: !model.enabled && model.current == .dark) { model.manual(.dark) }
            }

            HStack {
                Text("Switching points").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Stay as you are in between").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.top, 17).padding(.bottom, 8)
            VStack(spacing: 12) {
                ThresholdControl(title: "Dark below", symbol: "moon.fill", value: $model.darkThreshold, range: 1...500, tint: Color(red: 0.55, green: 0.61, blue: 0.82), onCommit: model.configure)
                ThresholdControl(title: "Light above", symbol: "sun.max.fill", value: $model.lightThreshold, range: (model.darkThreshold + 10)...2000, tint: Palette.amber, onCommit: model.configure)
            }
            .padding(14).background(surface, in: RoundedRectangle(cornerRadius: 15))

            HStack(spacing: 10) {
                Image(systemName: "hourglass").foregroundStyle(.secondary).frame(width: 18)
                Text("Wait for steady light").font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("Wait for steady light", selection: Binding(get: { model.delay }, set: { model.delay = $0; model.configure() })) {
                    ForEach(Array(Set([4.0, 10, 20, 30, 60, model.delay])).sorted(), id: \.self) { delay in
                        Text("\(Int(delay)) seconds").tag(delay)
                    }
                }.labelsHidden().frame(width: 114).controlSize(.small)
            }.padding(.horizontal, 3).padding(.top, 14)

            if let issue = model.issue {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.amber)
                    Text(issue).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Button("Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }.controlSize(.small)
                }.padding(12).background(Palette.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 10)).padding(.top, 14)
            }
            Divider().padding(.top, 16).padding(.bottom, 13)
            HStack {
                Toggle(isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })) {
                    Text("Launch at login").font(.system(size: 11))
                }.toggleStyle(.switch).controlSize(.mini).fixedSize()
                Spacer()
                if model.enabled {
                    Button { model.setEnabled(false) } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                    Divider().frame(height: 12).padding(.horizontal, 8)
                }
                Button("Quit Luma") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let message = model.loginMessage {
                HStack {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    Button("Login Items") { SMAppService.openSystemSettingsLoginItems() }.controlSize(.small)
                }.padding(.top, 10)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 18)
        .frame(width: width)
        .tint(Palette.amber)
        .onAppear { model.refreshLogin() }
    }

    private var hero: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("AMBIENT LIGHT").font(.system(size: 10, weight: .semibold)).tracking(2.3).foregroundStyle(Palette.cream.opacity(0.58))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.lux.map { String(format: "%.0f", $0) } ?? "—")
                        .font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                    Text("lux").font(.system(size: 19, weight: .light)).foregroundStyle(Palette.cream.opacity(0.55))
                }.padding(.top, 6)
                Text(room).font(.system(size: 13, weight: .medium)).padding(.top, 1)
                HStack(spacing: 5) {
                    Image(systemName: model.enabled ? "waveform.path" : "pause.circle").font(.system(size: 10))
                    Text(status).font(.system(size: 11))
                }.foregroundStyle(Palette.cream.opacity(0.6)).padding(.top, 10)
            }
            Spacer()
            LightDial(lux: model.lux, appearance: model.current)
                .frame(width: 182, height: 182).scaleEffect(0.65)
                .frame(width: 118, height: 118).accessibilityHidden(true)
        }
        .padding(.horizontal, 18).padding(.vertical, 18)
        .foregroundStyle(Palette.cream)
        .background {
            RoundedRectangle(cornerRadius: 21).fill(LinearGradient(colors: [Color(red: 0.12, green: 0.17, blue: 0.25), Color(red: 0.055, green: 0.085, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }

    private func mode(_ title: String, subtitle: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 18, weight: .light)).foregroundStyle(selected ? Palette.amber : Color.secondary).frame(width: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.vertical, 13).frame(maxWidth: .infinity)
                .background(selected ? Palette.amber.opacity(scheme == .dark ? 0.10 : 0.08) : surface, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Palette.amber.opacity(0.8) : Color.primary.opacity(0.07), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).accessibilityLabel("\(title) appearance").accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Luma works").font(.system(size: 17, weight: .semibold))
            Text("Luma reads your MacBook’s ambient light sensor every two seconds. A change must last for your chosen waiting period before the appearance switches.")
            Text("Between your two switching points, the current appearance stays put. Switching pauses during sleep or with the lid closed.")
            Text("While Auto is active, Luma suspends macOS’s time-based appearance schedule. Your previous schedule returns when you pause or quit.")
            Text("Sensor readings stay on your Mac.").foregroundStyle(.secondary)
        }.font(.system(size: 12)).lineSpacing(3).padding(22).frame(width: 330)
    }
}

private struct ThresholdControl: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let tint: Color
    let onCommit: () -> Void
    @State private var draft = ""
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: symbol).foregroundStyle(tint).font(.system(size: 11)).frame(width: 14)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                TextField("Lux", text: $draft)
                    .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    .font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                    .frame(width: 42).padding(.vertical, 5).padding(.horizontal, 6)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
                    .focused($editing).onSubmit(commit)
                    .accessibilityLabel("\(title), lux")
                Text("lux").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { log10(min(max(value, range.lowerBound), range.upperBound)) }, set: {
                let selected = min(max(pow(10, $0).rounded(), range.lowerBound), range.upperBound)
                // Replace any focused text draft before releasing focus: its
                // blur handler must never commit the old number over the slider.
                draft = String(Int(selected))
                editing = false
                value = selected
                onCommit()
                draft = String(Int(value))
            }), in: log10(range.lowerBound)...log10(range.upperBound))
                .tint(tint).controlSize(.small).accessibilityLabel(title).accessibilityValue("\(Int(value)) lux")
        }.padding(.horizontal, 5)
            .onAppear { draft = String(Int(value)) }
            // Model changes (including the other threshold's minimum) take
            // precedence over a draft even while the number field has focus.
            .onChange(of: value) { newValue in draft = String(Int(newValue)) }
            .onChange(of: editing) { focused in if !focused { commit() } }
    }
    private func commit() {
        if let number = Double(draft), number.isFinite {
            value = min(max(number.rounded(), range.lowerBound), range.upperBound)
            onCommit()
        }
        draft = String(Int(value))
    }
}

private struct LightDial: View {
    let lux: Double?
    let appearance: Appearance
    private var progress: Double { min(max(log10((lux ?? 0) + 1) / log10(2001), 0), 1) }
    var body: some View {
        ZStack {
            ForEach(0..<60) { index in
                Capsule().fill(Palette.cream.opacity(Double(index) / 59 <= progress && lux != nil ? 0.7 : 0.12))
                    .frame(width: 1.5, height: index % 5 == 0 ? 9 : 4)
                    .offset(y: -84).rotationEffect(.degrees(Double(index) * 6 - 180))
            }
            Circle().fill(RadialGradient(colors: [Palette.amber.opacity(0.22), .clear], center: .center, startRadius: 20, endRadius: 72)).frame(width: 140, height: 140)
            ZStack {
                Circle().fill(LinearGradient(colors: [Palette.cream, Palette.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(LinearGradient(colors: [Color(red: 0.15, green: 0.20, blue: 0.29), Color(red: 0.06, green: 0.095, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78).offset(x: appearance == .dark ? 19 : 49, y: appearance == .dark ? -7 : -21)
            }.frame(width: 84, height: 84).clipShape(Circle()).shadow(color: Palette.amber.opacity(0.25), radius: 20)
            VStack {
                Spacer()
                Text(appearance == .dark ? "DARK" : "LIGHT").font(.system(size: 8, weight: .semibold)).tracking(2).foregroundStyle(Palette.cream.opacity(0.6))
            }.padding(.bottom, 22)
        }.accessibilityLabel("Current appearance: \(appearance.rawValue). Ambient light level on a logarithmic scale.")
    }
}

struct SettingsWindowView: View {
    @ObservedObject var model: LumaModel
    let size: NSSize

    var body: some View {
        ScrollView(.vertical) {
            SettingsView(model: model, width: size.width)
        }
        .frame(width: size.width, height: size.height)
        .modifier(LiquidGlassPanel())
    }
}

/// Extend one rectangular material beneath the transparent title bar. AppKit
/// owns the outer window corners, so there is no second rounded panel inside it.
private struct LiquidGlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            surface.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Palette.background(for: scheme)
        } else if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
