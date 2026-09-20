import Foundation

public struct Lesson: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let track: String
    public let minutes: Int
    public let subtitle: String
    public let paragraphs: [String]
    public let question: String
    public let answer: String
    public let source: URL
}

public enum Library {
    public static let lessons: [Lesson] = [
        Lesson(id: "idempotency", title: "When a retry becomes a second payment", track: "SYSTEMS", minutes: 4,
               subtitle: "The small idea behind reliable imports and safe retries.", paragraphs: [
                "A client sends a request. The server completes the work, but the response gets lost. The client now knows less than the server: it cannot tell whether the operation failed or succeeded. Retrying is useful only if repeating the request does not repeat the effect.",
                "An idempotent operation has the same intended effect when applied again. Setting a profile name to a fixed value is naturally idempotent. Adding ₹250 to a balance is not. For operations like charging or creating an order, a stable request identifier lets the server remember that the logical operation already happened.",
                "The important part is where that memory lives. If the server inserts the order and then separately records the request ID, a crash between those steps can still create a duplicate. The deduplication record and the effect must be committed together, or the system needs another recovery mechanism with an explicit consistency contract.",
                "Daybook encounters the same problem when you import overlapping statements. An amount and a timestamp are not a trustworthy identity: two coffees can cost the same. A stable reference, scoped to the correct account and event, is stronger. When an identity is ambiguous, review it instead of silently merging.",
                "Idempotency also has a lifetime. A server that forgets keys after a day cannot promise safe retries forever. Decide how long clients can retry, what happens when a key is reused with different parameters, and whether a previously failed request can be tried again."
               ], question: "Why is recording an idempotency key after creating an order unsafe?",
               answer: "A crash between creating the order and saving the key leaves a completed effect with no deduplication record. The retry can create another order.",
               source: URL(string: "https://pdos.csail.mit.edu/6.824/")!),
        Lesson(id: "indexes", title: "An index is a second view of your data", track: "CS FOUNDATIONS", minutes: 3,
               subtitle: "Faster reads come with a write-time bill.", paragraphs: [
                "Imagine finding one receipt in a box. Scanning every receipt is simple and needs no extra structure. Sorting a separate list by merchant makes a merchant lookup cheaper, but every new receipt now needs a second piece of work: updating that list.",
                "A database index is a maintained access path. A B-tree keeps keys ordered and supports equality lookups as well as ranges. A hash-based structure is a different tradeoff, usually oriented toward equality. The right choice follows the queries the system must answer.",
                "Column order matters in a composite index. An index ordered by account and then date is convenient for asking for one account's payments within a date range. It does not offer the same direct access path for a date range across every account. Think about the ordering, not just which columns appear in the index.",
                "An index is not free storage or free CPU. Inserts, deletes, and updates may modify it. Extra indexes can improve a dashboard while slowing the ingestion pipeline. Measure realistic reads and writes before adding an index to every column.",
                "A useful exercise: list the three most common queries in a product, sketch an index for each, and then ask whether two can share one access path. Read the query plan to verify the engine actually uses the structure you expected."
               ], question: "What new work does a secondary index add to an insert?",
               answer: "The database must update the additional access structure consistently with the row, increasing write, storage and often locking or maintenance costs.",
               source: URL(string: "https://www.postgresql.org/docs/current/indexes.html")!),
        Lesson(id: "eth-transactions", title: "What happens after you sign?", track: "BLOCKCHAIN", minutes: 4,
               subtitle: "A transaction moves through several different promises.", paragraphs: [
                "An Ethereum transaction expresses an authorized state transition. Signing proves control of the relevant key; it does not prove that the network has accepted, executed, or finalized the transaction. Those are separate stages.",
                "A node receiving a transaction validates it against rules and its current view of the chain. The transaction may wait in a pool before a block includes it. The sender's nonce orders transactions from that account and helps prevent replay within the same account sequence.",
                "Execution consumes gas. A smart contract call can revert even when the transaction itself is valid for inclusion. A revert rolls back the call's state changes, but the computation still has a cost. An app therefore needs to inspect the execution result, not merely the presence of a transaction hash.",
                "Inclusion is also different from finality. A wallet can present the transaction as included while still explaining the chain's confirmation or finality status. Applications should choose the status required by their use case rather than treating a single Boolean as a universal definition of success.",
                "When designing a transaction screen, name the state: awaiting signature, submitted, included, failed execution, or finalized. Good interfaces communicate what is known and what can still change. This principle also improves ordinary payment trackers."
               ], question: "Does having a transaction hash prove a contract call succeeded?",
               answer: "No. A hash identifies a transaction; execution may still be pending or may have reverted. Inspect the receipt and the required finality state.",
               source: URL(string: "https://ethereum.org/developers/docs/transactions/")!),
        Lesson(id: "amm", title: "Why a bigger swap gets a different price", track: "DEFI", minutes: 4,
               subtitle: "Price impact in a simple constant-product pool.", paragraphs: [
                "Consider a simplified pool containing 10 units of token X and 1,000 units of token Y. Ignore fees and assume the pool maintains x × y = 10,000. The pool price near its current reserves is related to the ratio y/x, but a finite trade changes that ratio.",
                "If a trader adds one X, the new X reserve is 11. Keeping the product constant leaves roughly 909.09 Y in the pool, so the trader receives roughly 90.91 Y. The average execution price is lower than the initial marginal ratio of 100 Y per X.",
                "That difference is price impact: the trade itself moves the reserve ratio. A deeper pool generally experiences less price impact for the same trade size. Slippage tolerance is different: it bounds how much worse execution may become relative to the quoted conditions, including changes before the transaction executes.",
                "Real protocols introduce fees and may concentrate liquidity within price ranges. The simple formula is a starting model, not a complete simulator of every AMM. Always state which version and assumptions a numerical example uses.",
                "For a liquidity provider, fee income is only one component of returns. Inventory changes as prices move, and a position can underperform simply holding the original assets. Learning these mechanics is useful without making any trade."
               ], question: "How does price impact differ from slippage tolerance?",
               answer: "Price impact is the price movement caused by the trade. Slippage tolerance is an execution constraint that limits how far the final result may deviate from a quote.",
               source: URL(string: "https://developers.uniswap.org/docs/get-started/concepts/how-uniswap-works")!),
        Lesson(id: "caching", title: "Your cache has a freshness contract", track: "SYSTEMS", minutes: 3,
               subtitle: "Fast answers still need to describe their age.", paragraphs: [
                "A cache stores a result so the system can avoid repeating expensive work. That result was correct for some state at some time. The design question is not merely how fast the cache is, but how an application knows whether the stored answer remains acceptable.",
                "A time-to-live is a policy, not proof of freshness. Data can change one second after it is cached. If a result is safe to be a few minutes old, a TTL can be enough. If it authorizes a consequential action, the application may need validation against the source.",
                "Invalidation moves the difficulty elsewhere. Events can notify a cache that data changed, but events can be delayed, duplicated, or lost. Version numbers and periodic reconciliation make the contract easier to reason about.",
                "Consider the spending total on a phone. Recomputing the chart every three hours does not make the underlying bank feed fresh. Capture time, processing time, and reconciliation time describe three different things. A clear interface shows which one matters.",
                "When reviewing a cache design, ask what happens after a write, a network partition, a restart, and an empty result. Decide explicitly whether an old answer is better than no answer."
               ], question: "Why doesn't refreshing a chart guarantee fresh source data?",
               answer: "The chart can recompute from the same stale records. Freshness depends on acquiring new source data, not just repeating the calculation.",
               source: URL(string: "https://www.rfc-editor.org/rfc/rfc9111.html")!),
        Lesson(id: "reflection", title: "Describe the day before judging it", track: "WELLBEING", minutes: 2,
               subtitle: "A brief exercise in making a thought more specific.", paragraphs: [
                "When a day feels wasted, separate the events from the conclusion. ‘I did nothing today’ is a conclusion. ‘I was interrupted twice, finished one task, and postponed another’ describes events that are easier to work with.",
                "Write down one thought that has been taking up attention. Then ask what evidence supports it and what evidence complicates it. You do not have to force a positive interpretation. A more balanced description may simply be more specific.",
                "Choose one small next action that fits your actual energy. It might be closing one open loop, preparing tomorrow's first task, or taking a break. The aim is a useful response, not a verdict on your character.",
                "This is a reflection exercise rather than an assessment of your mental health. If an exercise feels unhelpful, leave it and choose another kind of support. You can use the journal without allowing any of its text into an AI review."
               ], question: "What is one event you can describe without adding a judgment?",
               answer: "There isn't a correct answer. Try a concrete event: ‘I read for ten minutes’ or ‘I moved a task to tomorrow.’",
               source: URL(string: "https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/self-help-cbt-techniques/reframing-unhelpful-thoughts/")!)
    ]
}
