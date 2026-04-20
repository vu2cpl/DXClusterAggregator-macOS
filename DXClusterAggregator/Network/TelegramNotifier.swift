import Foundation

/// Sends messages via the Telegram Bot HTTP API.
final class TelegramNotifier {
    /// Send a plain-text message to the configured chat. Fails silently with a console log.
    static func send(botToken: String, chatId: String, text: String) {
        guard !botToken.isEmpty, !chatId.isEmpty else { return }

        let urlString = "https://api.telegram.org/bot\(botToken)/sendMessage"
        guard let url = URL(string: urlString) else { return }

        let body: [String: String] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = json
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error = error {
                print("Telegram send error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("Telegram send HTTP \(http.statusCode)")
            }
        }.resume()
    }
}
