;; Donation Management Contract
;; Tracks incoming donations and their allocation to projects

(define-data-var total-donations uint u0)

;; Map of donor address to total amount donated
(define-map donor-totals principal uint)

;; Structure for donation records
(define-map donations
  { donation-id: uint }
  {
    donor: principal,
    amount: uint,
    timestamp: uint,
    project-id: (optional uint),
    allocated: bool
  }
)

;; Map of project allocations
(define-map project-allocations
  { project-id: uint }
  { total-allocated: uint }
)

;; Counter for donation IDs
(define-data-var donation-id-counter uint u0)

;; Error codes
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-INVALID-AMOUNT u402)
(define-constant ERR-INVALID-PROJECT u403)
(define-constant ERR-ALREADY-ALLOCATED u404)

;; Make a donation
(define-public (donate (amount uint))
  (let
    (
      (current-id (var-get donation-id-counter))
      (donor tx-sender)
      (current-donor-total (default-to u0 (map-get? donor-totals donor)))
    )
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))

    ;; Update donation records
    (map-set donations
      { donation-id: current-id }
      {
        donor: donor,
        amount: amount,
        timestamp: block-height,
        project-id: none,
        allocated: false
      }
    )

    ;; Update donor totals
    (map-set donor-totals donor (+ current-donor-total amount))

    ;; Update total donations
    (var-set total-donations (+ (var-get total-donations) amount))

    ;; Increment donation ID counter
    (var-set donation-id-counter (+ current-id u1))

    (ok current-id)
  )
)

;; Allocate donation to a project
(define-public (allocate-donation (donation-id uint) (project-id uint))
  (let
    (
      (donation (unwrap! (map-get? donations { donation-id: donation-id }) (err ERR-INVALID-AMOUNT)))
      (project-allocation (default-to { total-allocated: u0 } (map-get? project-allocations { project-id: project-id })))
    )
    ;; Check if donation is already allocated
    (asserts! (not (get allocated donation)) (err ERR-ALREADY-ALLOCATED))

    ;; Update donation record
    (map-set donations
      { donation-id: donation-id }
      (merge donation {
        project-id: (some project-id),
        allocated: true
      })
    )

    ;; Update project allocation
    (map-set project-allocations
      { project-id: project-id }
      { total-allocated: (+ (get total-allocated project-allocation) (get amount donation)) }
    )

    (ok true)
  )
)

;; Get donation details
(define-read-only (get-donation (donation-id uint))
  (map-get? donations { donation-id: donation-id })
)

;; Get donor total donations
(define-read-only (get-donor-total (donor principal))
  (default-to u0 (map-get? donor-totals donor))
)

;; Get project allocation
(define-read-only (get-project-allocation (project-id uint))
  (default-to { total-allocated: u0 } (map-get? project-allocations { project-id: project-id }))
)

;; Get total donations
(define-read-only (get-total-donations)
  (var-get total-donations)
)

