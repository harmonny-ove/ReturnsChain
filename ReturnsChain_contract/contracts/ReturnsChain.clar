
;; title: ReturnsChain
;; version: 1.0.0
;; summary: Decentralized platform for profit-sharing decisions and investor payout approvals
;; description: Smart contract that manages investor registrations, profit distribution proposals,
;;              voting mechanisms, and automated payouts based on consensus decisions.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-proposal-not-active (err u106))
(define-constant err-already-voted (err u107))
(define-constant err-proposal-expired (err u108))

;; Voting thresholds
(define-constant min-approval-percentage u60) ;; 60% approval required
(define-constant proposal-duration u144) ;; ~24 hours in blocks (assuming 10min blocks)

;; data vars
(define-data-var next-investor-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-investors uint u0)
(define-data-var total-investment uint u0)

;; data maps

;; Investor registry
(define-map investors
    { investor-id: uint }
    {
        address: principal,
        investment-amount: uint,
        share-percentage: uint,
        is-active: bool,
        joined-at: uint
    }
)

;; Address to investor ID mapping
(define-map investor-addresses
    { address: principal }
    { investor-id: uint }
)

;; Profit distribution proposals
(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        total-profit: uint,
        created-at: uint,
        expires-at: uint,
        is-executed: bool,
        votes-for: uint,
        votes-against: uint,
        total-voting-power: uint
    }
)

;; Proposal votes tracking
(define-map proposal-votes
    { proposal-id: uint, voter: principal }
    { vote: bool, voting-power: uint }
)

;; Individual payout amounts per proposal
(define-map proposal-payouts
    { proposal-id: uint, investor-id: uint }
    { payout-amount: uint }
)

;; public functions

;; Register a new investor
(define-public (register-investor (investment-amount uint))
    (let
        (
            (investor-id (var-get next-investor-id))
            (caller tx-sender)
            (new-total (+ (var-get total-investment) investment-amount))
            (share-percentage (/ (* investment-amount u10000) new-total)) ;; Using basis points for precision
        )
        (asserts! (> investment-amount u0) err-invalid-amount)
        (asserts! (is-none (map-get? investor-addresses { address: caller })) err-already-exists)

        ;; Store investor data
        (begin
            (map-set investors
                { investor-id: investor-id }
                {
                    address: caller,
                    investment-amount: investment-amount,
                    share-percentage: share-percentage,
                    is-active: true,
                    joined-at: block-height
                }
            )

            ;; Store address mapping
            (map-set investor-addresses
                { address: caller }
                { investor-id: investor-id }
            )

            ;; Update counters
            (var-set next-investor-id (+ investor-id u1))
            (var-set total-investors (+ (var-get total-investors) u1))
            (var-set total-investment new-total)

            ;; Recalculate all share percentages
            (unwrap-panic (recalculate-shares))

            (ok investor-id)
        )
    )
)

;; Create a profit distribution proposal
(define-public (create-proposal (total-profit uint))
    (let
        (
            (proposal-id (var-get next-proposal-id))
            (caller tx-sender)
        )
        (asserts! (> total-profit u0) err-invalid-amount)
        (asserts! (is-some (map-get? investor-addresses { address: caller })) err-unauthorized)

        ;; Create proposal
        (map-set proposals
            { proposal-id: proposal-id }
            {
                proposer: caller,
                total-profit: total-profit,
                created-at: block-height,
                expires-at: (+ block-height proposal-duration),
                is-executed: false,
                votes-for: u0,
                votes-against: u0,
                total-voting-power: (var-get total-investment)
            }
        )

        ;; Calculate individual payouts based on share percentages
        (unwrap-panic (calculate-proposal-payouts proposal-id total-profit))

        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let
        (
            (caller tx-sender)
            (investor-data (unwrap! (get-investor-by-address caller) err-unauthorized))
            (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
            (voting-power (get investment-amount investor-data))
        )
        (asserts! (< block-height (get expires-at proposal-data)) err-proposal-expired)
        (asserts! (not (get is-executed proposal-data)) err-proposal-not-active)
        (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: caller })) err-already-voted)

        ;; Record vote
        (map-set proposal-votes
            { proposal-id: proposal-id, voter: caller }
            { vote: vote, voting-power: voting-power }
        )

        ;; Update proposal vote counts
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal-data
                {
                    votes-for: (if vote
                                  (+ (get votes-for proposal-data) voting-power)
                                  (get votes-for proposal-data)),
                    votes-against: (if vote
                                     (get votes-against proposal-data)
                                     (+ (get votes-against proposal-data) voting-power))
                }
            )
        )

        (ok true)
    )
)

;; Execute a proposal if it has enough votes
(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
            (approval-percentage (/ (* (get votes-for proposal-data) u100) (get total-voting-power proposal-data)))
        )
        (asserts! (not (get is-executed proposal-data)) err-proposal-not-active)
        (asserts! (>= approval-percentage min-approval-percentage) err-unauthorized)

        ;; Mark as executed
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal-data { is-executed: true })
        )

        ;; TODO: In a real implementation, this would trigger actual STX transfers
        ;; For now, we just mark the proposal as executed
        (ok true)
    )
)

;; Deactivate an investor (only owner)
(define-public (deactivate-investor (investor-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let
            (
                (investor-data (unwrap! (map-get? investors { investor-id: investor-id }) err-not-found))
            )
            (map-set investors
                { investor-id: investor-id }
                (merge investor-data { is-active: false })
            )
            (ok true)
        )
    )
)

;; read only functions

;; Get investor by ID
(define-read-only (get-investor (investor-id uint))
    (map-get? investors { investor-id: investor-id })
)

;; Get investor by address
(define-read-only (get-investor-by-address (address principal))
    (match (map-get? investor-addresses { address: address })
        investor-mapping (map-get? investors { investor-id: (get investor-id investor-mapping) })
        none
    )
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

;; Get investor's vote on a proposal
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

;; Get payout amount for investor in a specific proposal
(define-read-only (get-payout (proposal-id uint) (investor-id uint))
    (map-get? proposal-payouts { proposal-id: proposal-id, investor-id: investor-id })
)

;; Get contract statistics
(define-read-only (get-contract-stats)
    {
        total-investors: (var-get total-investors),
        total-investment: (var-get total-investment),
        next-investor-id: (var-get next-investor-id),
        next-proposal-id: (var-get next-proposal-id)
    }
)

;; Check if proposal is approved
(define-read-only (is-proposal-approved (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal-data
        (let
            (
                (approval-percentage (/ (* (get votes-for proposal-data) u100) (get total-voting-power proposal-data)))
            )
            (>= approval-percentage min-approval-percentage)
        )
        false
    )
)

;; private functions

;; Recalculate share percentages for all investors
(define-private (recalculate-shares)
    (let
        (
            (total-inv (var-get total-investment))
        )
        ;; This is a simplified version - in a real implementation,
        ;; you'd iterate through all investors and update their share percentages
        (ok u0)
    )
)

;; Calculate payout amounts for all investors in a proposal
(define-private (calculate-proposal-payouts (proposal-id uint) (total-profit uint))
    (let
        (
            (total-inv (var-get total-investment))
        )
        ;; This would iterate through all investors and calculate their individual payouts
        ;; based on their share percentages. Simplified for this implementation.
        (ok u0)
    )
)

