// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Google UserInfo response. Only a matching account may supply its avatar.
/// https://developers.google.com/identity/openid-connect/reference
struct AccountProfile: Decodable {
    let email: String?
    let picture: String?

    func avatarURL(for account: String) throws -> URL? {
        guard email?.lowercased() == account.lowercased() else {
            throw ProfileError.accountMismatch
        }
        guard let picture, !picture.isEmpty else { return nil }
        guard let url = URL(string: picture), url.scheme == "https",
              let host = url.host?.lowercased(),
              host == "googleusercontent.com" || host.hasSuffix(".googleusercontent.com"),
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else {
            throw ProfileError.invalidPictureURL
        }
        return url
    }

    enum ProfileError: Error { case accountMismatch, invalidPictureURL }
}
