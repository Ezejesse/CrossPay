;; Cross-Border Remittance Platform
;; A decentralized remittance system enabling secure international money transfers
;; with multi-currency support, compliance features, and automated exchange rates

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-recipient (err u102))
(define-constant err-transfer-not-found (err u103))
(define-constant err-transfer-already-claimed (err u104))
(define-constant err-transfer-expired (err u105))
(define-constant err-invalid-currency (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-kyc-required (err u108))
(define-constant err-compliance-blocked (err u109))
(define-constant max-transfer-amount u1000000) ;; 1M microSTX
(define-constant min-transfer-amount u1000) ;; 1000 microSTX
(define-constant transfer-expiry-blocks u1440) ;; ~24 hours
(define-constant platform-fee-rate u50) ;; 0.5% in basis points

;; data maps and vars
(define-map user-balances principal uint)
(define-map user-kyc-status principal bool)
(define-map compliance-blocked principal bool)
(define-map currency-rates (string-ascii 3) uint) ;; currency code to rate (in basis points)
(define-map transfers 
    uint 
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        currency: (string-ascii 3),
        exchange-rate: uint,
        recipient-identifier: (string-ascii 50),
        country-code: (string-ascii 2),
        purpose-code: (string-ascii 10),
        created-block: uint,
        claimed: bool,
        compliance-checked: bool
    }
)
(define-map user-transfer-history principal (list 20 uint))
(define-data-var next-transfer-id uint u1)
(define-data-var platform-treasury uint u0)
(define-data-var total-volume uint u0)
(define-data-var compliance-officer principal contract-owner)

;; private functions
(define-private (calculate-fee (amount uint))
    (/ (* amount platform-fee-rate) u10000)
)

(define-private (is-valid-currency (currency (string-ascii 3)))
    (or 
        (is-eq currency "USD")
        (is-eq currency "EUR")
        (is-eq currency "GBP")
        (is-eq currency "JPY")
        (is-eq currency "STX")
    )
)

(define-private (convert-currency (amount uint) (from-currency (string-ascii 3)) (to-currency (string-ascii 3)))
    (let (
        (from-rate (default-to u10000 (map-get? currency-rates from-currency)))
        (to-rate (default-to u10000 (map-get? currency-rates to-currency)))
    )
        (/ (* amount from-rate) to-rate)
    )
)

(define-private (update-user-history (user principal) (transfer-id uint))
    (let (
        (current-history (default-to (list) (map-get? user-transfer-history user)))
    )
        (map-set user-transfer-history user 
            (unwrap! (as-max-len? (append current-history transfer-id) u20) false)
        )
    )
)

(define-private (validate-compliance (sender principal) (recipient principal) (amount uint) (country-code (string-ascii 2)))
    (and 
        (not (default-to false (map-get? compliance-blocked sender)))
        (not (default-to false (map-get? compliance-blocked recipient)))
        (default-to false (map-get? user-kyc-status sender))
        (>= amount min-transfer-amount)
        (<= amount max-transfer-amount)
        (not (is-eq country-code ""))
    )
)

;; public functions
(define-public (deposit (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-balances tx-sender (+ current-balance amount))
        (ok amount)
    )
)

(define-public (withdraw (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-balances tx-sender (- current-balance amount))
        (ok amount)
    )
)

(define-public (set-kyc-status (user principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender (var-get compliance-officer)) err-owner-only)
        (map-set user-kyc-status user status)
        (ok status)
    )
)

(define-public (set-compliance-block (user principal) (blocked bool))
    (begin
        (asserts! (is-eq tx-sender (var-get compliance-officer)) err-owner-only)
        (map-set compliance-blocked user blocked)
        (ok blocked)
    )
)

(define-public (update-currency-rate (currency (string-ascii 3)) (rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-currency currency) err-invalid-currency)
        (map-set currency-rates currency rate)
        (ok rate)
    )
)

(define-public (send-remittance 
    (recipient principal) 
    (amount uint) 
    (currency (string-ascii 3))
    (recipient-identifier (string-ascii 50))
    (country-code (string-ascii 2))
    (purpose-code (string-ascii 10))
)
    (let (
        (sender-balance (default-to u0 (map-get? user-balances tx-sender)))
        (fee (calculate-fee amount))
        (total-cost (+ amount fee))
        (transfer-id (var-get next-transfer-id))
        (exchange-rate (default-to u10000 (map-get? currency-rates currency)))
    )
        (asserts! (validate-compliance tx-sender recipient amount country-code) err-compliance-blocked)
        (asserts! (is-valid-currency currency) err-invalid-currency)
        (asserts! (>= sender-balance total-cost) err-insufficient-balance)
        (asserts! (not (is-eq recipient tx-sender)) err-invalid-recipient)
        
        ;; Update balances
        (map-set user-balances tx-sender (- sender-balance total-cost))
        (var-set platform-treasury (+ (var-get platform-treasury) fee))
        (var-set total-volume (+ (var-get total-volume) amount))
        
        ;; Create transfer record
        (map-set transfers transfer-id {
            sender: tx-sender,
            recipient: recipient,
            amount: amount,
            currency: currency,
            exchange-rate: exchange-rate,
            recipient-identifier: recipient-identifier,
            country-code: country-code,
            purpose-code: purpose-code,
            created-block: block-height,
            claimed: false,
            compliance-checked: true
        })
        
        ;; Update histories and increment ID
        (update-user-history tx-sender transfer-id)
        (var-set next-transfer-id (+ transfer-id u1))
        
        (ok transfer-id)
    )
)

(define-public (claim-remittance (transfer-id uint))
    (let (
        (transfer-data (unwrap! (map-get? transfers transfer-id) err-transfer-not-found))
        (recipient (get recipient transfer-data))
        (amount (get amount transfer-data))
        (created-block (get created-block transfer-data))
        (claimed (get claimed transfer-data))
    )
        (asserts! (is-eq tx-sender recipient) err-invalid-recipient)
        (asserts! (not claimed) err-transfer-already-claimed)
        (asserts! (< (- block-height created-block) transfer-expiry-blocks) err-transfer-expired)
        
        ;; Update recipient balance
        (let (
            (recipient-balance (default-to u0 (map-get? user-balances recipient)))
        )
            (map-set user-balances recipient (+ recipient-balance amount))
        )
        
        ;; Mark as claimed
        (map-set transfers transfer-id (merge transfer-data { claimed: true }))
        (update-user-history recipient transfer-id)
        
        (ok amount)
    )
)

;; Helper function for batch cost calculation
(define-private (calculate-batch-cost 
    (transfer-item {
        recipient: principal,
        amount: uint,
        currency: (string-ascii 3),
        recipient-identifier: (string-ascii 50),
        country-code: (string-ascii 2),
        purpose-code: (string-ascii 10)
    })
    (accumulator uint)
)
    (let (
        (amount (get amount transfer-item))
        (fee (calculate-fee amount))
    )
        (+ accumulator amount fee)
    )
)

;; Helper function for processing individual transfers in batch
(define-private (process-single-transfer
    (transfer-item {
        recipient: principal,
        amount: uint,
        currency: (string-ascii 3),
        recipient-identifier: (string-ascii 50),
        country-code: (string-ascii 2),
        purpose-code: (string-ascii 10)
    })
    (transfer-ids (list 10 uint))
)
    (let (
        (transfer-id (var-get next-transfer-id))
        (exchange-rate (default-to u10000 (map-get? currency-rates (get currency transfer-item))))
    )
        ;; Create transfer record
        (map-set transfers transfer-id {
            sender: tx-sender,
            recipient: (get recipient transfer-item),
            amount: (get amount transfer-item),
            currency: (get currency transfer-item),
            exchange-rate: exchange-rate,
            recipient-identifier: (get recipient-identifier transfer-item),
            country-code: (get country-code transfer-item),
            purpose-code: (get purpose-code transfer-item),
            created-block: block-height,
            claimed: false,
            compliance-checked: true
        })
        
        ;; Update transfer ID for next iteration
        (var-set next-transfer-id (+ transfer-id u1))
        
        ;; Update sender history
        (update-user-history tx-sender transfer-id)
        
        ;; Add transfer ID to the list (handle potential list length limits)
        (match (as-max-len? (append transfer-ids transfer-id) u10)
            success success
            transfer-ids
        )
    )
)

;; Read-only functions
(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-transfer (transfer-id uint))
    (map-get? transfers transfer-id)
)

(define-read-only (get-user-kyc-status (user principal))
    (default-to false (map-get? user-kyc-status user))
)

(define-read-only (get-currency-rate (currency (string-ascii 3)))
    (default-to u10000 (map-get? currency-rates currency))
)

(define-read-only (get-platform-stats)
    {
        total-volume: (var-get total-volume),
        platform-treasury: (var-get platform-treasury),
        next-transfer-id: (var-get next-transfer-id)
    }
)


