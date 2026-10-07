#if os(iOS)
import SafariServices
import UIKit

public enum VoybitCheckoutPresenter {
    @MainActor
    public static func present(_ checkoutURL: String, from controller: UIViewController) throws {
        let url = try VoybitCheckout.checkoutURL(publicID: try VoybitCheckout.publicID(from: checkoutURL))
        controller.present(SFSafariViewController(url: url), animated: true)
    }
}
#endif
