struct SecretMatch: Equatable {
    let name: String
    let matchedString: String
    let fileString: String
}


import ArgumentParser
import Foundation

@main
struct SwiftyDurocHog: ParsableCommand {

    @Option(name: .shortAndLong, help: "The path to the directory.")
    var directory: String

    mutating func run() throws {
        print("Hello, SwiftyDurocHog!")

        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: directory)
        let allFiles = fm.listFilesInScope(at: dirURL)
        print("SwiftyDurocHog working dir = \(directory)")

        print("SwiftyDurocHog found \(allFiles.count) files...\nScanning...")

        var allMatches = [SecretMatch]()
        for regex in regexDict() {
            for file in allFiles {
                do {
                    let fileContents = try String(contentsOf: file, encoding: .utf8)
                    let regexObj = try NSRegularExpression(pattern: regex.value)
                    let matches = regexObj.matches(in: fileContents, options: [], range: NSRange(fileContents.startIndex..., in: fileContents))

                    for match in matches {
                        let matchedString = (fileContents as NSString).substring(with: match.range)

                        allMatches.append( SecretMatch(name: regex.key, matchedString: matchedString, fileString: file.absoluteString))
                    }
                }
                catch {
                    
                    //print("error opening file: \(error)")
                }
            }
        }
        for match in allMatches {
            print("Found secret named \(match.name). MATCH: \(match.matchedString), in file: \(match.fileString)")
        }
    }
}

extension FileManager {
    func listFilesInScope(at: URL) -> [URL] {
        var files = [URL]()

        if let enumerator = self.enumerator(at: at, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                files.append(fileURL)
            }
        }
        return files
    }
}

func regexDict() -> [String: String] {
    if let data = regex.data(using: .utf8) {
        do {
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                return dict
            }
        }
        catch {
            print(error)
        }
    }
    return [String: String]()
}

// -------------------------------------------------------------------------------------------------------
// CONFIG via global regex JSON.

let regex = """
{
    "Slack Token": "(xox[p|b|o|a]-[0-9]{12}-[0-9]{12}-[0-9]{12}-[a-z0-9]{32})",
    "RSA private key": "-----BEGIN RSA PRIVATE KEY-----",
    "SSH (DSA) private key": "-----BEGIN DSA PRIVATE KEY-----",
    "SSH (EC) private key": "-----BEGIN EC PRIVATE KEY-----",
    "PGP private key block": "-----BEGIN PGP PRIVATE KEY BLOCK-----",
    "Amazon AWS Access Key ID": "AKIA[0-9A-Z]{16}",
    "Amazon MWS Auth Token": "amzn\\\\.mws\\\\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
    "Facebook Access Token": "EAACEdEose0cBA[0-9A-Za-z]+",
    "Facebook OAuth": "(?i)facebook[\\\\s[[:punct:]]]{1,4}[0-9a-f]{32}[\\\\s[[:punct:]]]?",
    "GitHub": "(?i)(github|access[[:punct:]]token)[\\\\s[[:punct:]]]{1,4}[0-9a-zA-Z]{35,40}",
    "Google API Key": "AIza[0-9A-Za-z\\\\-_]{35}",
    "Google Cloud Platform API Key": "AIza[0-9A-Za-z\\\\-_]{35}",
    "Google Cloud Platform OAuth": "(?i)[0-9]+-[0-9A-Za-z_]{32}\\\\.apps\\\\.googleusercontent\\\\.com",
    "Google Drive API Key": "AIza[0-9A-Za-z\\\\-_]{35}",
    "Google Drive OAuth": "(?i)[0-9]+-[0-9A-Za-z_]{32}\\\\.apps\\\\.googleusercontent\\\\.com",
    "Google (GCP) Service-account": "(?i)\\"type\\": \\"service_account\\"",
    "Google Gmail API Key": "AIza[0-9A-Za-z\\\\-_]{35}",
    "Google Gmail OAuth": "(?i)[0-9]+-[0-9A-Za-z_]{32}\\\\.apps\\\\.googleusercontent\\\\.com",
    "Google OAuth Access Token": "ya29\\\\.[0-9A-Za-z\\\\-_]+",
    "Google YouTube API Key": "AIza[0-9A-Za-z\\\\-_]{35}",
    "Google YouTube OAuth": "(?i)[0-9]+-[0-9A-Za-z_]{32}\\\\.apps\\\\.googleusercontent\\\\.com",
    "Heroku API Key": "[h|H][e|E][r|R][o|O][k|K][u|U][\\\\s[[:punct:]]]{1,4}[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}",
    "MailChimp API Key": "[0-9a-f]{32}-us[0-9]{1,2}",
    "Mailgun API Key": "(?i)key-[0-9a-zA-Z]{32}",
    "Credentials in absolute URL": "(?i)((https?|ftp)://)(([a-z0-9$_\\\\.\\\\+!\\\\*'\\\\(\\\\),;\\\\?&=-]|%[0-9a-f]{2})+(:([a-z0-9$_\\\\.\\\\+!\\\\*'\\\\(\\\\),;\\\\?&=-]|%[0-9a-f]{2})+)@)((([a-z0-9]\\\\.|[a-z0-9][a-z0-9-]*[a-z0-9]\\\\.)*[a-z][a-z0-9-]*[a-z0-9]|((\\\\d|[1-9]\\\\d|1\\\\d{2}|2[0-4][0-9]|25[0-5])\\\\.){3}(\\\\d|[1-9]\\\\d|1\\\\d{2}|2[0-4][0-9]|25[0-5]))(:\\\\d+)?)(((/+([a-z0-9$_\\\\.\\\\+!\\\\*'\\\\(\\\\),;:@&=-]|%[0-9a-f]{2})*)*(\\\\?([a-z0-9$_\\\\.\\\\+!\\\\*'\\\\(\\\\),;:@&=-]|%[0-9a-f]{2})*)?)?)?",
    "PayPal Braintree Access Token": "(?i)access_token\\\\$production\\\\$[0-9a-z]{16}\\\\$[0-9a-f]{32}",
    "Picatic API Key": "(?i)sk_live_[0-9a-z]{32}",
    "Slack Webhook": "(?i)https://hooks.slack.com/services/T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8}/[a-zA-Z0-9_]{24}",
    "Stripe API Key": "(?i)sk_live_[0-9a-zA-Z]{24}",
    "Stripe Restricted API Key": "(?i)rk_live_[0-9a-zA-Z]{24}",
    "Square Access Token": "(?i)sq0atp-[0-9A-Za-z\\\\-_]{22}",
    "Square OAuth Secret": "(?i)sq0csp-[0-9A-Za-z\\\\-_]{43}",
    "New Relic Partner & REST API Key": "[\\\\s[[:punct:]]][A-Fa-f0-9]{47}[\\\\s[[:punct:]][[:cntrl:]]]",
    "New Relic Mobile Application Token": "[\\\\s[[:punct:]]][A-Fa-f0-9]{42}[\\\\s[[:punct:]][[:cntrl:]]]",
    "New Relic Synthetics Private Location": "(?i)minion_private_location_key",
    "New Relic Insights Key (specific)": "(?i)insights[\\\\s[[:punct:]]]?(key|query|insert)[\\\\s[[:punct:]]]{1,4}\\\\b[\\\\w-]{32,40}\\\\b",
    "New Relic Insights Key (vague)": "(?i)(query|insert)[\\\\s[[:punct:]]]?key[\\\\s[[:punct:]]]{1,4}b[\\\\w-]{32,40}\\\\b",
    "New Relic License Key": "(?i)license[\\\\s[[:punct:]]]?key[\\\\s[[:punct:]]]{1,4}\\\\b[\\\\w-]{32,40}\\\\b",
    "New Relic Internal API Key": "(?i)nr-internal-api-key",
    "New Relic HTTP Auth Headers and API Key": "(?i)(x|newrelic|nr)-?(admin|partner|account|query|insert|api|license)-?(id|key)[\\\\s[[:punct:]]]{1,4}\\\\b[\\\\w-]{32,47}\\\\b",
    "New Relic API Key Service Key (new format)": "(?i)NRAK-[A-Z0-9]{27}",
    "New Relic APM License Key (new format)": "(?i)[a-f0-9]{36}NRAL",
    "New Relic APM License Key (new format, region-aware)": "(?i)[a-z]{2}[0-9]{2}xx[a-f0-9]{30}NRAL",
    "New Relic REST API Key (new format)": "(?i)NRRA-[a-f0-9]{42}",
    "New Relic Admin API Key (new format)": "(?i)NRAA-[a-f0-9]{27}",
    "New Relic Insights Insert Key (new format)": "(?i)NRII-[A-Za-z0-9-_]{32}",
    "New Relic Insights Query Key (new format)": "(?i)NRIQ-[A-Za-z0-9-_]{32}",
    "New Relic Synthetics Private Location Key (new format)": "(?i)NRSP-[a-z]{2}[0-9]{2}[a-f0-9]{31}",
    "New Relic Account IDs in URL": "(newrelic\\\\.com/)?accounts/\\\\d{1,10}/",
    "Salary Information": "(?i)(salary|commission|compensation|pay)([\\\\s[[:punct:]]](amount|target))?[\\\\s[[:punct:]]]{1,4}\\\\d+",
}
"""


// Disabled rules.

//    "Account ID": "(?i)account[\\\\s[[:punct:]]]?id[\\\\s[[:punct:]]]{1,4}\\\\b[\\\\d]{1,10}\\\\b",

//    "Email address": "(?i)\\\\b(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*)@[a-z0-9][a-z0-9-]+\\\\.(com|de|cn|net|uk|org|info|nl|eu|ru)([\\\\W&&[^:/]]|\\\\A|\\\\z)",


//"Twilio API Key": "SK[0-9a-fA-F]{32}",
//"Twitter Access Token": "(?i)twitter[\\\\s[[:punct:]]]{1,4}[1-9][0-9]+-[0-9a-zA-Z]{40}",
//"Twitter OAuth": "(?i)twitter[\\\\s[[:punct:]]]{1,4}['|\"]?[0-9a-zA-Z]{35,44}['|\"]?",
/*

 "Generic API Key": {
     "pattern": "(?i)(api|access)[\\\\s[[:punct:]]]?key[\\\\s[[:punct:]]]{1,4}[0-9a-zA-Z\\\\-_]{16,64}[\\\\s[[:punct:]]]?",
     "entropy_filter": true,
     "threshold": "0.6",
     "keyspace": "guess"
 },
 "Generic Account API Key": {
     "pattern": "(?i)account[\\\\s[[:punct:]]]?api[\\\\s[[:punct:]]]{1,4}[0-9a-zA-Z\\\\-_]{16,64}[\\\\s[[:punct:]]]?",
     "entropy_filter": true,
     "threshold": "0.6",
     "keyspace": "guess"
 },
 "Generic Secret": {
     "pattern": "(?i)secret[\\\\s[[:punct:]]]{1,4}[0-9a-zA-Z-_]{16,64}[\\\\s[[:punct:]]]?",
     "entropy_filter": true,
     "threshold": "0.6",
     "keyspace": "guess"
 },
 */
