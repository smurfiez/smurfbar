import AppKit
import SwiftUI
import Combine

/// Represents a single target snap zone within a layout template.
struct SnapLayoutZone: Identifiable, Equatable {
    let id: String
    /// Normalized coordinates (0.0 ... 1.0) with Cocoa convention: origin (0,0) at bottom-left
    let relativeRect: CGRect

    func targetScreenFrame(in usable: CGRect) -> CGRect {
        let x = usable.minX + relativeRect.origin.x * usable.width
        let y = usable.minY + relativeRect.origin.y * usable.height
        let width = relativeRect.width * usable.width
        let height = relativeRect.height * usable.height
        return CGRect(x: round(x), y: round(y), width: round(width), height: round(height))
    }
}

/// Predefined workflow layout templates inspired by Windows 11 Snap Layouts.
enum SnapLayoutTemplate: String, CaseIterable, Identifiable {
    case split = "50 / 50"
    case priority = "67 / 33"
    case threeColumns = "33 / 33 / 33"
    case focusAndStack = "Focus & Stack"
    case stackAndFocus = "Stack & Focus"
    case fourGrid = "2 x 2"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: return "Split"
        case .priority: return "Priority"
        case .threeColumns: return "Three Columns"
        case .focusAndStack: return "Focus & Stack"
        case .stackAndFocus: return "Stack & Focus"
        case .fourGrid: return "Quad Grid"
        }
    }

    var zones: [SnapLayoutZone] {
        switch self {
        case .split:
            return [
                SnapLayoutZone(id: "\(id)-left", relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)),
                SnapLayoutZone(id: "\(id)-right", relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0))
            ]
        case .priority:
            return [
                SnapLayoutZone(id: "\(id)-left", relativeRect: CGRect(x: 0, y: 0, width: 0.67, height: 1.0)),
                SnapLayoutZone(id: "\(id)-right", relativeRect: CGRect(x: 0.67, y: 0, width: 0.33, height: 1.0))
            ]
        case .threeColumns:
            return [
                SnapLayoutZone(id: "\(id)-left", relativeRect: CGRect(x: 0, y: 0, width: 0.333, height: 1.0)),
                SnapLayoutZone(id: "\(id)-center", relativeRect: CGRect(x: 0.333, y: 0, width: 0.334, height: 1.0)),
                SnapLayoutZone(id: "\(id)-right", relativeRect: CGRect(x: 0.667, y: 0, width: 0.333, height: 1.0))
            ]
        case .focusAndStack:
            return [
                SnapLayoutZone(id: "\(id)-main", relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)),
                SnapLayoutZone(id: "\(id)-topRight", relativeRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-bottomRight", relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
            ]
        case .stackAndFocus:
            return [
                SnapLayoutZone(id: "\(id)-topLeft", relativeRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-bottomLeft", relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-main", relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0))
            ]
        case .fourGrid:
            return [
                SnapLayoutZone(id: "\(id)-topLeft", relativeRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-topRight", relativeRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-bottomLeft", relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
                SnapLayoutZone(id: "\(id)-bottomRight", relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
            ]
        }
    }
}

/// Observable state for the Snap Layouts Bar.
class SnapLayoutsBarState: ObservableObject {
    static let shared = SnapLayoutsBarState()

    @Published var hoveredZoneID: String? = nil
    @Published var currentScreen: NSScreen? = nil

    private init() {}
}

/// Floating drop-down bar at top of screen for Windows 11-style Snap Layouts.
class SnapLayoutsBarWindow: NSPanel {
    static let shared = SnapLayoutsBarWindow()

    private let state = SnapLayoutsBarState.shared
    private let barWidth: CGFloat = 640
    private let barHeight: CGFloat = 110
    private let cardWidth: CGFloat = 84
    private let cardHeight: CGFloat = 52
    private let cardSpacing: CGFloat = 12
    private let cardBottomY: CGFloat = 12

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating + 2
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hostingView = NSHostingView(rootView: SnapLayoutsBarContentView())
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }

    /// Present the Snap Layouts bar at the top center of the specified screen.
    func show(on screen: NSScreen) {
        state.currentScreen = screen
        let frame = calculateFrame(for: screen)
        self.setFrame(frame, display: true)
        self.orderFront(nil)
    }

    /// Hide the Snap Layouts bar.
    func hide() {
        state.hoveredZoneID = nil
        self.orderOut(nil)
    }

    var isVisibleOnScreen: Bool {
        self.isVisible
    }

    private func calculateFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let x = screenFrame.midX - (barWidth / 2)
        // Position at top edge of screen
        let y = screenFrame.maxY - barHeight - 4
        return NSRect(x: x, y: y, width: barWidth, height: barHeight)
    }

    /// Tests if a mouse location (in Cocoa screen coordinates) falls into any layout zone card.
    /// Returns the matched zone and its target frame on the usable workspace.
    func hitTestZone(at mouseLocation: CGPoint, on screen: NSScreen, usable: CGRect) -> (SnapLayoutZone, CGRect)? {
        let winFrame = self.frame
        guard winFrame.contains(mouseLocation) else {
            state.hoveredZoneID = nil
            return nil
        }

        let localX = mouseLocation.x - winFrame.minX
        let localY = mouseLocation.y - winFrame.minY

        // Check vertical bounds for cards
        guard localY >= cardBottomY && localY <= (cardBottomY + cardHeight) else {
            state.hoveredZoneID = nil
            return nil
        }

        let templates = SnapLayoutTemplate.allCases
        let totalCardsWidth = CGFloat(templates.count) * cardWidth + CGFloat(templates.count - 1) * cardSpacing
        let startX = (barWidth - totalCardsWidth) / 2

        for (index, template) in templates.enumerated() {
            let cardX = startX + CGFloat(index) * (cardWidth + cardSpacing)
            if localX >= cardX && localX <= (cardX + cardWidth) {
                // Inside template card
                let relX = (localX - cardX) / cardWidth
                let relY = (localY - cardBottomY) / cardHeight

                for zone in template.zones {
                    if zone.relativeRect.contains(CGPoint(x: relX, y: relY)) {
                        state.hoveredZoneID = zone.id
                        let targetFrame = zone.targetScreenFrame(in: usable)
                        return (zone, targetFrame)
                    }
                }
            }
        }

        state.hoveredZoneID = nil
        return nil
    }
}

/// SwiftUI visual content of the Snap Layouts Bar.
struct SnapLayoutsBarContentView: View {
    @ObservedObject var state = SnapLayoutsBarState.shared
    @ObservedObject var prefs = PreferencesService.shared

    var body: some View {
        VStack(spacing: 6) {
            // Header bar
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(prefs.accentColorChoice.color)

                Text("Snap Layouts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                Text("• Drag and drop into a layout to organize your workflow")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Layout template cards
            HStack(spacing: 12) {
                ForEach(SnapLayoutTemplate.allCases) { template in
                    SnapLayoutTemplateCardView(template: template, hoveredZoneID: state.hoveredZoneID)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(width: 640, height: 110)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                    .background(
                        VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    )

                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

/// An individual layout template card showing its constituent zones.
struct SnapLayoutTemplateCardView: View {
    let template: SnapLayoutTemplate
    let hoveredZoneID: String?
    @ObservedObject var prefs = PreferencesService.shared

    private let cardWidth: CGFloat = 84
    private let cardHeight: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            templateGrid
                .padding(4)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    @ViewBuilder
    private var templateGrid: some View {
        switch template {
        case .split:
            HStack(spacing: 3) {
                zoneBlock(id: "\(template.id)-left")
                zoneBlock(id: "\(template.id)-right")
            }

        case .priority:
            HStack(spacing: 3) {
                zoneBlock(id: "\(template.id)-left")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(2)
                zoneBlock(id: "\(template.id)-right")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }

        case .threeColumns:
            HStack(spacing: 3) {
                zoneBlock(id: "\(template.id)-left")
                zoneBlock(id: "\(template.id)-center")
                zoneBlock(id: "\(template.id)-right")
            }

        case .focusAndStack:
            HStack(spacing: 3) {
                zoneBlock(id: "\(template.id)-main")
                VStack(spacing: 3) {
                    zoneBlock(id: "\(template.id)-topRight")
                    zoneBlock(id: "\(template.id)-bottomRight")
                }
            }

        case .stackAndFocus:
            HStack(spacing: 3) {
                VStack(spacing: 3) {
                    zoneBlock(id: "\(template.id)-topLeft")
                    zoneBlock(id: "\(template.id)-bottomLeft")
                }
                zoneBlock(id: "\(template.id)-main")
            }

        case .fourGrid:
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    zoneBlock(id: "\(template.id)-topLeft")
                    zoneBlock(id: "\(template.id)-topRight")
                }
                HStack(spacing: 3) {
                    zoneBlock(id: "\(template.id)-bottomLeft")
                    zoneBlock(id: "\(template.id)-bottomRight")
                }
            }
        }
    }

    private func zoneBlock(id: String) -> some View {
        let isHovered = (hoveredZoneID == id)
        return RoundedRectangle(cornerRadius: 4)
            .fill(isHovered ? prefs.accentColorChoice.color.opacity(0.85) : Color.primary.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovered ? Color.white.opacity(0.9) : Color.primary.opacity(0.15), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
