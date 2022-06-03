//
//  TokenManager.swift
//  xCreds
//
//  Created by Timothy Perfitt on 4/5/22.
//
import Foundation

struct RefreshTokenResponse: Codable {
    let accessToken, expiresIn, expiresOn, refreshToken, extExpiresIn,tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case expiresOn = "expires_on"
        case refreshToken = "refresh_token"
        case extExpiresIn = "ext_expires_in"
        case tokenType = "token_type"
    }
}

class TokenManager {

    static let shared = TokenManager()

    let defaults = UserDefaults.standard
    var timer: Timer?

    func getNewAccessToken() -> Bool {

        var result = false

        guard let url = URL(string: defaults.string(forKey: PrefKeys.tokenEndpoint.rawValue) ?? "") else { return false }

        let sema = DispatchSemaphore(value: 0)
        var req = URLRequest(url: url)

        let refreshToken = defaults.string(forKey: PrefKeys.refreshToken.rawValue) ?? ""
        let clientID = defaults.string(forKey: PrefKeys.clientID.rawValue) ?? ""

        var parameters = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientID)"
        if let clientSecret = defaults.string(forKey: PrefKeys.clientSecret.rawValue) {
            parameters.append("&client_secret=\(clientSecret)")
        }

        let postData =  parameters.data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        req.httpMethod = "POST"
        req.httpBody = postData

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
          guard let data = data else {
            print(String(describing: error))
            sema.signal()
            return
          }
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    let decoder = JSONDecoder()
                    do {

                        let json = try decoder.decode(RefreshTokenResponse.self, from: data)
                        result = true
                        let expirationDate = Date().addingTimeInterval(TimeInterval(Int(json.expiresIn) ?? 0))
                        UserDefaults.standard.set(expirationDate, forKey: PrefKeys.expirationDate.rawValue)
                        UserDefaults.standard.set(json.refreshToken, forKey: PrefKeys.refreshToken.rawValue)
                        UserDefaults.standard.set(json.accessToken, forKey: PrefKeys.accessToken.rawValue)

                    }
                    catch {
                        print(String(data: data, encoding: .utf8) as Any)                    }
                }
            }
          sema.signal()
        }

        task.resume()
        sema.wait()
        return result
    }
}