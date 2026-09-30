import Foundation

struct LegalDestination: Identifiable {
    let id: String
    let titleKey: String
    let systemImage: String
    let url: URL

    static let all: [LegalDestination] = [
        make(
            id: "legal-notice",
            titleKey: "settings.about.legalNotice",
            systemImage: "person.text.rectangle",
            path: "mentions-legales"
        ),
        make(
            id: "privacy",
            titleKey: "settings.about.privacy",
            systemImage: "hand.raised",
            path: "confidentialite"
        ),
        make(
            id: "terms",
            titleKey: "settings.about.terms",
            systemImage: "doc.text",
            path: "conditions-utilisation"
        ),
        make(
            id: "licenses",
            titleKey: "settings.about.thirdPartyLicenses",
            systemImage: "shippingbox",
            path: "licences"
        ),
    ].compactMap { $0 }

    static var onboarding: [LegalDestination] {
        all.filter { $0.id == "privacy" || $0.id == "terms" }
    }

    private static func make(
        id: String,
        titleKey: String,
        systemImage: String,
        path: String
    ) -> LegalDestination? {
        guard let url = URL(string: "https://ledge-notch.vercel.app/\(path)") else { return nil }
        return LegalDestination(id: id, titleKey: titleKey, systemImage: systemImage, url: url)
    }
}
