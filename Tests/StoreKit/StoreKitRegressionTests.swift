import StoreKit
import StoreKitTest
import XCTest

/// Local Apple StoreKit contract tests. These do not exercise RevenueCat's server.
@available(macOS 14.0, *)
final class StoreKitRegressionTests: XCTestCase {
  private let productID = "ios_openccman_pro_lifetime_3"
  private var session: SKTestSession!

  override func setUp() async throws {
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
    session = try SKTestSession(contentsOf: url)
    session.resetToDefaultState()
    session.disableDialogs = true
    session.clearTransactions()
    try await waitForEntitlement(false)
  }

  override func tearDownWithError() throws {
    session.clearTransactions()
    session.resetToDefaultState()
    session = nil
  }

  private func product() async throws -> Product {
    let products = try await Product.products(for: [productID])
    return try XCTUnwrap(products.first)
  }

  private func buy() async throws -> Transaction {
    let product = try await product()
    let result = try await product.purchase()
    guard case .success(.verified(let transaction)) = result else {
      throw NSError(domain: "StoreKitRegression", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Expected a verified purchase"])
    }
    await transaction.finish()
    try await waitForEntitlement(true)
    return transaction
  }

  private func hasLifetime() async -> Bool {
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result,
         transaction.productID == productID, transaction.revocationDate == nil {
        return true
      }
    }
    return false
  }

  private func waitForEntitlement(_ expected: Bool) async throws {
    for _ in 0..<50 {
      if await hasLifetime() == expected { return }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw NSError(domain: "StoreKitRegression", code: 2,
                  userInfo: [NSLocalizedDescriptionKey: "StoreKit entitlement did not become \(expected) in 5 seconds"])
  }

  func testCatalogMatchesApprovedLifetimeProduct() async throws {
    let product = try await product()
    XCTAssertEqual(product.id, productID)
    XCTAssertEqual(product.type, .nonConsumable)
    XCTAssertFalse(product.displayName.isEmpty)
    XCTAssertFalse(product.displayPrice.isEmpty)
    XCTAssertNil(product.subscription)
  }

  func testPurchaseGrantsVerifiedLifetimeWithoutExpiration() async throws {
    let transaction = try await buy()
    XCTAssertEqual(transaction.productID, productID)
    XCTAssertNil(transaction.expirationDate)
    let entitled = await hasLifetime()
    XCTAssertTrue(entitled)
  }

  func testUserCancellationDoesNotCreateEntitlement() async throws {
    try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
    let product = try await product()
    let result = try await product.purchase()
    guard case .userCancelled = result else { return XCTFail("Expected cancellation, not success") }
    let entitled = await hasLifetime()
    XCTAssertFalse(entitled)
  }

  func testPurchaseFailureDoesNotCreateEntitlement() async throws {
    try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
    let product = try await product()
    do {
      _ = try await product.purchase()
      XCTFail("Expected the injected StoreKit error")
    } catch {
      XCTAssertTrue(error is StoreKitError)
    }
    let entitled = await hasLifetime()
    XCTAssertFalse(entitled)
  }

  func testExplicitRestoreRetainsVerifiedPurchase() async throws {
    _ = try await buy()
    try await AppStore.sync()
    // Re-query the store instead of reusing the purchase callback's transaction.
    let entitled = await hasLifetime()
    XCTAssertTrue(entitled)
  }

  func testRepeatPurchaseDoesNotDuplicateLifetimeEntitlement() async throws {
    _ = try await buy()
    _ = try await buy()
    var matching = 0
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == productID {
        matching += 1
      }
    }
    XCTAssertEqual(matching, 1)
  }

  func testRefundRemovesVerifiedEntitlement() async throws {
    _ = try await buy()
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.refundTransaction(identifier: transaction.identifier)
    try await waitForEntitlement(false)
  }
}
