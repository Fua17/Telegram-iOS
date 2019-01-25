import Foundation
import Postbox
import SwiftSignalKit

public enum NotificationTokenType {
    case aps
    case voip
}

public func registerNotificationToken(account: Account, token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [Int32]) -> Signal<Never, NoError> {
    return masterNotificationsKey(account: account, ignoreDisabled: false)
    |> mapToSignal { masterKey -> Signal<Never, NoError> in
        let mappedType: Int32
        switch type {
            case .aps:
                mappedType = 1
            case .voip:
                mappedType = 9
        }
        return account.network.request(Api.functions.account.registerDevice(tokenType: mappedType, token: hexString(token), appSandbox: sandbox ? .boolTrue : .boolFalse, secret: Buffer(data: type == .voip ? masterKey.data : Data()), otherUids: otherAccountUserIds))
        |> retryRequest
        |> ignoreValues
    }
}
