import ManagedSettingsUI
import ManagedSettings
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let orange    = UIColor(red: 0.961, green: 0.329, blue: 0.149, alpha: 1)
    private static let primary   = UIColor { t in t.userInterfaceStyle == .dark ? .white : .black }
    private static let secondary = UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white: 0.65, alpha: 1) : UIColor(white: 0.3, alpha: 1) }
    private static let darkText  = UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white: 0.85, alpha: 1) : UIColor(white: 0.15, alpha: 1) }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        SharedDefaults.resetIfNewDay()
        let appName = application.localizedDisplayName ?? "застосунок"
        return makeShield(appName: appName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        return configuration(shielding: application)
    }

    private func makeShield(appName: String) -> ShieldConfiguration {
        let debt    = SharedDefaults.dailyDebtUAH
        let isFirst = SharedDefaults.isFirstShieldToday

        let subtitleText = (isFirst || debt <= 0)
            ? "час трохи відпочити від скролінгу"
            : "сьогодні вже наскролено \(Int(debt))₴ на донати"

        let illustration = UIImage(named: "shield-illustration",
                                   in: Bundle(for: type(of: self)),
                                   compatibleWith: nil)

        let title      = ShieldConfiguration.Label(text: "\(appName) – ліміт вичерпано", color: Self.primary)
        let subtitle   = ShieldConfiguration.Label(text: subtitleText, color: Self.secondary)
        let closeButton = ShieldConfiguration.Label(text: "закрити", color: .white)

        if #available(iOS 26.4, *) {
            return ShieldConfiguration(
                icon: illustration,
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: closeButton,
                primaryButtonBackgroundColor: Self.orange,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "ще трохи часу", color: Self.darkText),
                secondaryButtonSubmenuItems: ["1 хвилина", "5 хвилин", "30 хвилин"]
            )
        } else {
            return ShieldConfiguration(
                icon: illustration,
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: closeButton,
                primaryButtonBackgroundColor: Self.orange,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "ще 5 хвилин", color: Self.darkText)
            )
        }
    }
}
