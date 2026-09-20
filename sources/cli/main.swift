import Foundation
import DaybookCore
import Darwin

// Private from the moment a new export is created, before setting final attributes.
umask(0o077)

func option(_ name: String, in args: [String]) throws -> String {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { throw DaybookError.invalid("Missing \(name). See daybook help.") }
    return args[index + 1]
}
func protectedWrite(_ data: Data, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    guard !FileManager.default.fileExists(atPath: path) else { throw DaybookError.invalid("Output already exists; choose a new path to preserve the existing file.") }
    try data.write(to: url, options: .withoutOverwriting)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
}
let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first ?? "help" {
    case "inspect-gpay":
        let data = try Data(contentsOf: URL(fileURLWithPath: option("--file", in: args)))
        let result = try GPayStatementImporter.parse(data: data)
        print("GPay PDF: \(result.statement?.pageCount ?? 0) pages, \(result.entries.count) payments, \(result.issues.count) issues.")
        if let statement = result.statement {
            print("Statement totals: \(statement.totalsMatch ? "MATCH" : "MISMATCH"). Explicit self-transfer rows retained as normal debits: \(statement.selfTransferCount).")
        }
        for issue in result.issues { print(issue) }
        guard result.canImport else { throw DaybookError.invalid("Import is blocked pending review of the issues above.") }
        if args.contains("--out") {
            let output = try option("--out", in: args)
            var snapshot = Snapshot()
            Finance.ingest(result.entries, into: &snapshot)
            snapshot.coverageNote = result.statement?.coverage ?? "GPay PDF import."
            try protectedWrite(DaybookJSON.encode(snapshot), to: output)
            print("Parsed records saved locally at \(output). This is a plaintext validation snapshot, not an AI review packet.")
        }
    case "verify", "archive", "prepare-review":
        let file = try option("--file", in: args)
        let keyPath = try option("--key-file", in: args)
        let encrypted = try Data(contentsOf: URL(fileURLWithPath: file))
        let key = try String(contentsOfFile: keyPath, encoding: .utf8)
        let archive = try Vault.open(encrypted, recoveryKey: key)
        if args[0] == "verify" {
            print("Verified archive \(archive.id.uuidString). \(archive.snapshot.transactions.count) payments, \(archive.snapshot.checkIns.count) check-ins. No files were removed.")
        } else if args[0] == "archive" {
            let directory = URL(fileURLWithPath: try option("--to", in: args), isDirectory: true)
            let output = directory.appendingPathComponent("\(archive.id.uuidString).daybook")
            try protectedWrite(encrypted, to: output.path)
            let reloaded = try Data(contentsOf: output)
            guard reloaded == encrypted else { throw DaybookError.invalid("Archive verification failed after writing.") }
            _ = try Vault.open(reloaded, recoveryKey: key)
            print("Encrypted archive copied and verified at \(output.path). Phone cleanup is not enabled; keep the recovery key separately.")
        } else {
            let scopeText = try option("--scope", in: args)
            guard let scope = ReviewScope(rawValue: scopeText) else { throw DaybookError.invalid("Scope must be finance, wellbeing or learning.") }
            let end = Date(); let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
            let packet = ReviewPacket(snapshot: archive.snapshot, scope: scope, from: start, to: end,
                                      includeExcerpts: args.contains("--include-approved-excerpts"), includeHealth: args.contains("--include-health"))
            let output = try option("--out", in: args)
            try protectedWrite(DaybookJSON.encode(packet), to: output)
            print("Selected \(scope.rawValue) summary saved at \(output). No raw account identifiers or payment notes were printed. Share only this packet for review.")
        }
    case "report-template":
        let packet = try DaybookJSON.decode(ReviewPacket.self, from: Data(contentsOf: URL(fileURLWithPath: try option("--packet", in: args))))
        let output = try option("--out", in: args)
        try protectedWrite(DaybookJSON.encode(packet.localReport()), to: output)
        print("Local report template saved at \(output). It is a deterministic summary, not an AI review. Import through Daybook's Review screen.")
    case "csv-template": print(CSVImporter.template)
    case "help", "--help", "-h":
        print("""
        Daybook — local archive & review tools. No network requests.

        daybook verify --file export.daybook --key-file recovery.key
        daybook archive --file export.daybook --key-file recovery.key --to /path/to/private/archive
        daybook prepare-review --file export.daybook --key-file recovery.key --scope finance --out packet.json
          Optional wellbeing flags: --include-approved-excerpts, --include-health
        daybook report-template --packet packet.json --out result.review.json
        daybook csv-template
        daybook inspect-gpay --file statement.pdf [--out /private/path/parsed.json]

        Save the recovery key in a separate private file, not in command arguments.
        Archives remain encrypted. Review packets are plaintext selected summaries.
        Existing outputs are never overwritten. No command deletes phone data.
        """)
    default: throw DaybookError.invalid("Unknown command. Run daybook help.")
    }
} catch {
    FileHandle.standardError.write(Data("Daybook: \(error.localizedDescription)\n".utf8))
    exit(1)
}
