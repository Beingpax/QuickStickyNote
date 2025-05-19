import SwiftUI
import StoreKit

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var proManager = ProManager.shared
    @State private var isPurchasing = false
    @State private var selectedProduct: Product?
    
    var body: some View {
        VStack(spacing: 32) {
            // Close Button
            HStack {
                Spacer()
                Button(action: {
                    dismiss()
                    NotificationCenter.default.post(name: NSNotification.Name("UpgradePromptDidClose"), object: nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, -16)
            
            // Header
            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#4ECDC4"), Color(hex: "#556270")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("Unlock All Features")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Personalize your notes with beautiful colors\nand access them instantly with global shortcuts")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Features List
            VStack(alignment: .leading, spacing: 16) {
                PromptFeatureRow(icon: "paintpalette.fill", text: "Beautiful Colors")
                PromptFeatureRow(icon: "keyboard", text: "No nagging when using keyboard shortcuts")
                PromptFeatureRow(icon: "heart.fill", text: "Support Development")
            }
            .padding(.horizontal)
            
            // Pricing
            VStack(spacing: 8) {
                // Purchase Options
                if !proManager.products.isEmpty {
                    ForEach(proManager.products.sorted { $0.price > $1.price }) { product in
                        Button(action: {
                            Task {
                                isPurchasing = true
                                await proManager.purchasePro(product: product)
                                isPurchasing = false
                                if proManager.isProUser {
                                    dismiss()
                                    NotificationCenter.default.post(name: NSNotification.Name("UpgradePromptDidClose"), object: nil)
                                }
                            }
                        }) {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Quick Sticky Notes Pro")
                                        Text("One-time purchase")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#4ECDC4"))
                                    .cornerRadius(4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        }
                        .buttonStyle(PromptPrimaryButtonStyle())
                        .disabled(isPurchasing)
                    }
                } else {
                    ProgressView("Loading products...")
                }
                
                Button("Restore Purchases") {
                    Task {
                        await proManager.restorePurchases()
                        if proManager.isProUser {
                            dismiss()
                            NotificationCenter.default.post(name: NSNotification.Name("UpgradePromptDidClose"), object: nil)
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                
                // Legal Links
                HStack(spacing: 16) {
                    Button("Privacy Policy") {
                        if let url = URL(string: "https://beingpax.github.io/QuickStickyNote/privacy.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Button("Terms of Use") {
                        if let url = URL(string: "https://beingpax.github.io/QuickStickyNote/terms.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            
            if let error = proManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(32)
        .frame(width: 480)
        .background(Color(hex: "#1E1E1E"))
        .preferredColorScheme(.dark)
    }
}

struct PromptFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#4ECDC4"))
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Button Styles
struct PromptPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .background(Color(hex: "#4ECDC4").opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium))
            .cornerRadius(8)
    }
}

struct PromptSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .background(Color(hex: "#2D2D2D").opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium))
            .cornerRadius(8)
    }
} 