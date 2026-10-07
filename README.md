# Voybit checkout for Swift

Your server creates the payment and returns `checkout_url`. This package does not take an API key.

```swift
.package(url: "https://github.com/VOYBIT/voybit-payment-gateway-swift", branch: "main")
```

```swift
try VoybitCheckoutPresenter.present(checkoutURL, from: self)

let status = try await VoybitCheckout().status(publicID: publicID)
if status.confirmed {
    // paid or overpaid — refresh the screen only
}
```

`present` opens `https://voybit.com/pay/{id}` in Safari. Fulfil the order from the webhook on your server. `status` calls `GET https://api.voybit.com/api/v1/checkout/{public_id}` and is only for the screen.

Requires iOS 15 or macOS 12. `present` is iOS only.
