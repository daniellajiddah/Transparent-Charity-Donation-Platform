;; Expense Tracking Contract
;; Records and verifies how funds are spent

;; Structure for expenses
(define-map expenses
  { expense-id: uint }
  {
    project-id: uint,
    milestone-id: (optional uint),
    amount: uint,
    recipient: principal,
    purpose: (string-ascii 500),
    timestamp: uint,
    approved: bool,
    approver: (optional principal)
  }
)

;; Map of project expenses
(define-map project-expenses
  { project-id: uint }
  { expense-ids: (list 100 uint) }
)

;; Total expenses by project
(define-map project-total-expenses
  { project-id: uint }
  { total: uint }
)

;; Counter for expense IDs
(define-data-var expense-id-counter uint u0)

;; Error codes
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-INVALID-PROJECT u402)
(define-constant ERR-INVALID-EXPENSE u403)
(define-constant ERR-ALREADY-APPROVED u404)
(define-constant ERR-INVALID-AMOUNT u405)
(define-constant ERR-LIST-OVERFLOW u406)

;; Record an expense
(define-public (record-expense
  (project-id uint)
  (milestone-id (optional uint))
  (amount uint)
  (recipient principal)
  (purpose (string-ascii 500)))
  (let
    (
      (expense-id (var-get expense-id-counter))
      (project-expense-list (default-to { expense-ids: (list) } (map-get? project-expenses { project-id: project-id })))
      (project-expense-total (default-to { total: u0 } (map-get? project-total-expenses { project-id: project-id })))
    )
    ;; Validate inputs
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))

    ;; Create expense record
    (map-set expenses
      { expense-id: expense-id }
      {
        project-id: project-id,
        milestone-id: milestone-id,
        amount: amount,
        recipient: recipient,
        purpose: purpose,
        timestamp: block-height,
        approved: false,
        approver: none
      }
    )

    ;; Add expense to project's expense list
    (let
      (
        (updated-expense-ids (unwrap! (as-max-len? (append (get expense-ids project-expense-list) expense-id) u100) (err ERR-LIST-OVERFLOW)))
      )
      (map-set project-expenses
        { project-id: project-id }
        { expense-ids: updated-expense-ids }
      )
    )

    ;; Increment expense ID counter
    (var-set expense-id-counter (+ expense-id u1))

    (ok expense-id)
  )
)

;; Approve an expense
(define-public (approve-expense (expense-id uint))
  (let
    (
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) (err ERR-INVALID-EXPENSE)))
      (project-expense-total (default-to { total: u0 } (map-get? project-total-expenses { project-id: (get project-id expense) })))
    )
    ;; Check if already approved
    (asserts! (not (get approved expense)) (err ERR-ALREADY-APPROVED))

    ;; Update expense record
    (map-set expenses
      { expense-id: expense-id }
      (merge expense {
        approved: true,
        approver: (some tx-sender)
      })
    )

    ;; Update project total expenses
    (map-set project-total-expenses
      { project-id: (get project-id expense) }
      { total: (+ (get total project-expense-total) (get amount expense)) }
    )

    (ok true)
  )
)

;; Get expense details
(define-read-only (get-expense (expense-id uint))
  (map-get? expenses { expense-id: expense-id })
)

;; Get project expenses
(define-read-only (get-project-expense-ids (project-id uint))
  (default-to { expense-ids: (list) } (map-get? project-expenses { project-id: project-id }))
)

;; Get project total expenses
(define-read-only (get-project-total-expenses (project-id uint))
  (default-to { total: u0 } (map-get? project-total-expenses { project-id: project-id }))
)

