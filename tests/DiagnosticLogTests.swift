import Foundation

@main
struct DiagnosticLogTests {
    static func main() throws {
        let secrets = [
            "Cookie: sessionid=secret",
            "Set-Cookie: other=secret",
            "Authorization: Bearer secret",
            "{'sessionid': 'secret'}",
            "password=secret",
            "access_token: secret",
        ]
        for secret in secrets {
            assert(!DiagnosticLog.sanitized(secret).contains("secret"))
        }
        let url = "https://user:secret@example.com/stories/name/123/?key=secret#secret"
        assert(DiagnosticLog.sanitized(url) == "https://example.com/stories/name/123/")
        assert(DiagnosticLog.sanitized("Extracted 0 cookies from brave (3686 could not be decrypted)")
            == "Extracted 0 cookies from brave (3686 could not be decrypted)")
        assert(DiagnosticLog.sanitized("WARNING: find-generic-password failed")
            == "WARNING: find-generic-password failed")
        let report = "[session-check] cookie=sessionid domain=.instagram.com expires=2027-05-04T00:00:00+00:00 expired=no"
        assert(DiagnosticLog.sanitized(report) == report)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".log")
        defer { try? FileManager.default.removeItem(at: file) }
        DiagnosticLog.append("BEGIN\nCookie: secret", to: file)
        DiagnosticLog.append("END", to: file)
        let content = try String(contentsOf: file, encoding: .utf8)
        assert(content.contains("BEGIN") && content.contains("END") && !content.contains("secret"))
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        assert(permissions == 0o600)
        print("DiagnosticLog: redaction, append and file permissions passed")
    }
}
