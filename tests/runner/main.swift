import Foundation
import DaybookTestSupport

let results = CoreChecks().run()
for result in results {
    print("\(result.failures.isEmpty ? "PASS" : "FAIL") \(result.name)")
    for failure in result.failures { print("  \(failure)") }
}
let failed = results.filter { !$0.failures.isEmpty }.count
print("\(results.count - failed)/\(results.count) regression checks passed.")
exit(failed == 0 ? 0 : 1)
