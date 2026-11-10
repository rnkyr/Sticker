//
//  File.swift
//  Sticker
//
//  Created by Benjamin Pisano on 15/11/2024.
//

#if os(iOS)
import SwiftUI
import CoreMotion

private struct WithAccelerometerViewModifier<ModifiedContent: View>: ViewModifier {
    let updateInterval: TimeInterval
    let makeView: (AnyView, AccelerometerAttitude) -> ModifiedContent

    /// `@State`, not a stored `let`: this modifier is a struct built inside a `body`, so a plain
    /// property mints a fresh `CMMotionManager` on every evaluation. The copy that received
    /// `onAppear` starts updates and CoreMotion retains it, while the `onDisappear` that would
    /// stop it belongs to whichever copy SwiftUI considers current — so managers accumulate, each
    /// still sampling at `updateInterval` for the life of the process. `@State` is keyed to the
    /// view's identity, so the same manager is started and stopped.
    @State private var motionManager = CMMotionManager()

    @State private var attitude: AccelerometerAttitude = .init()
    @State private var referenceAttitude: AccelerometerAttitude?

    func body(content: Content) -> some View {
        makeView(AnyView(content), attitude)
            .onAppear {
                startMotionUpdates()
            }
            .onDisappear {
                stopMotionUpdates()
            }
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion, error == nil else { return }
            var currentAttitude: AccelerometerAttitude = .init(attitude: motion.attitude)

            DispatchQueue.main.async {
                if referenceAttitude == nil {
                    referenceAttitude = currentAttitude
                }

                if let referenceAttitude {
                    currentAttitude = currentAttitude - referenceAttitude
                }

                attitude = currentAttitude
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

extension View {
    func withAccelerometer<ModifiedContent: View>(
        updateInterval: TimeInterval,
        @ViewBuilder _ makeView: @escaping (_ view: AnyView, _ attitude: AccelerometerAttitude) -> ModifiedContent
    ) -> some View {
        modifier(
            WithAccelerometerViewModifier(
                updateInterval: updateInterval,
                makeView: makeView
            )
        )
    }
}

#endif
