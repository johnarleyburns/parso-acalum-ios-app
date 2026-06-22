import SwiftUI

struct ToastData: Equatable {
    let message: String
    let icon: String
}

struct ToastView: View {
    let data: ToastData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: data.icon)
                .font(.system(size: 14, weight: .medium))
            Text(data.message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toastData: ToastData?
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let data = toastData {
                    ToastView(data: data)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                        .zIndex(100)
                        .onAppear {
                            HapticFeedback.medium()
                            scheduleDismiss()
                        }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: toastData)
            .onChange(of: toastData) { _, newValue in
                if newValue != nil {
                    scheduleDismiss()
                }
            }
    }

    private func scheduleDismiss() {
        workItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.35)) {
                toastData = nil
            }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }
}

extension View {
    func toast(data: Binding<ToastData?>) -> some View {
        modifier(ToastModifier(toastData: data))
    }
}
