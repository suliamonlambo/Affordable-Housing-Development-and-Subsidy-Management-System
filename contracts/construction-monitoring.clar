;; Construction Monitoring Contract
;; Tracks construction progress and quality assurance for affordable housing developments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-COMPLIANCE-VIOLATION (err u106))
(define-constant ERR-EXPIRED (err u107))

;; Data Variables
(define-data-var next-inspection-id uint u1)
(define-data-var next-contractor-id uint u1)
(define-data-var inspection-fee uint u100000) ;; Inspection fee in microSTX

;; Data Maps
(define-map construction-phases
  { development-id: uint, phase: (string-ascii 50) }
  {
    phase-name: (string-ascii 100),
    start-date: (optional uint),
    target-completion: uint,
    actual-completion: (optional uint),
    status: (string-ascii 20),
    budget-allocated: uint,
    budget-spent: uint,
    contractor-id: uint,
    progress-percentage: uint,
    quality-score: uint
  }
)

(define-map inspections
  { inspection-id: uint }
  {
    development-id: uint,
    phase: (string-ascii 50),
    inspector: principal,
    inspection-type: (string-ascii 30),
    scheduled-date: uint,
    completed-date: (optional uint),
    status: (string-ascii 20),
    passed: bool,
    score: uint,
    notes: (string-ascii 1000),
    violations: (list 10 (string-ascii 200)),
    follow-up-required: bool,
    follow-up-date: (optional uint)
  }
)

(define-map contractors
  { contractor-id: uint }
  {
    principal: principal,
    company-name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialties: (list 5 (string-ascii 50)),
    rating: uint,
    total-projects: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map contractor-principals
  { principal: principal }
  { contractor-id: uint }
)

(define-map quality-standards
  { standard-type: (string-ascii 50) }
  {
    description: (string-ascii 200),
    minimum-score: uint,
    weight: uint,
    mandatory: bool
  }
)

(define-map payment-milestones
  { development-id: uint, milestone: (string-ascii 50) }
  {
    amount: uint,
    contractor-id: uint,
    requirements-met: bool,
    inspection-passed: bool,
    payment-released: bool,
    released-at: (optional uint),
    released-by: (optional principal)
  }
)

(define-map compliance-violations
  { development-id: uint, violation-id: uint }
  {
    violation-type: (string-ascii 50),
    description: (string-ascii 500),
    severity: (string-ascii 20),
    discovered-at: uint,
    discovered-by: principal,
    resolved: bool,
    resolved-at: (optional uint),
    resolution-notes: (string-ascii 500)
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-inspector (inspector principal))
  ;; In a real implementation, this would check against a list of certified inspectors
  (is-contract-owner)
)

(define-private (is-registered-contractor (contractor principal))
  (is-some (map-get? contractor-principals { principal: contractor }))
)

(define-private (get-contractor-id (contractor principal))
  (get contractor-id (unwrap! (map-get? contractor-principals { principal: contractor }) u0))
)

;; Contractor Management
(define-public (register-contractor
  (company-name (string-ascii 100))
  (license-number (string-ascii 50))
  (specialties (list 5 (string-ascii 50))))
  (let
    (
      (contractor-id (var-get next-contractor-id))
      (current-block-height block-height)
    )
    (asserts! (> (len company-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len license-number) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? contractor-principals { principal: tx-sender })) ERR-ALREADY-EXISTS)

    (map-set contractors
      { contractor-id: contractor-id }
      {
        principal: tx-sender,
        company-name: company-name,
        license-number: license-number,
        specialties: specialties,
        rating: u100,
        total-projects: u0,
        active: true,
        registered-at: current-block-height
      }
    )

    (map-set contractor-principals
      { principal: tx-sender }
      { contractor-id: contractor-id }
    )

    (var-set next-contractor-id (+ contractor-id u1))
    (ok contractor-id)
  )
)

(define-public (update-contractor-status (contractor-id uint) (active bool))
  (let
    (
      (contractor-data (unwrap! (map-get? contractors { contractor-id: contractor-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set contractors
      { contractor-id: contractor-id }
      (merge contractor-data { active: active })
    )
    (ok true)
  )
)

;; Construction Phase Management
(define-public (create-construction-phase
  (development-id uint)
  (phase (string-ascii 50))
  (phase-name (string-ascii 100))
  (target-completion uint)
  (budget-allocated uint)
  (contractor-id uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> development-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len phase) u0) ERR-INVALID-INPUT)
    (asserts! (> (len phase-name) u0) ERR-INVALID-INPUT)
    (asserts! (> target-completion block-height) ERR-INVALID-INPUT)
    (asserts! (> budget-allocated u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? contractors { contractor-id: contractor-id })) ERR-NOT-FOUND)
    (asserts! (is-none (map-get? construction-phases { development-id: development-id, phase: phase })) ERR-ALREADY-EXISTS)

    (map-set construction-phases
      { development-id: development-id, phase: phase }
      {
        phase-name: phase-name,
        start-date: none,
        target-completion: target-completion,
        actual-completion: none,
        status: "planned",
        budget-allocated: budget-allocated,
        budget-spent: u0,
        contractor-id: contractor-id,
        progress-percentage: u0,
        quality-score: u0
      }
    )
    (ok true)
  )
)

(define-public (start-construction-phase (development-id uint) (phase (string-ascii 50)))
  (let
    (
      (phase-data (unwrap! (map-get? construction-phases { development-id: development-id, phase: phase }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status phase-data) "planned") ERR-INVALID-STATUS)

    (map-set construction-phases
      { development-id: development-id, phase: phase }
      (merge phase-data {
        start-date: (some current-block-height),
        status: "in-progress"
      })
    )
    (ok true)
  )
)

(define-public (update-phase-progress
  (development-id uint)
  (phase (string-ascii 50))
  (progress-percentage uint)
  (budget-spent uint))
  (let
    (
      (phase-data (unwrap! (map-get? construction-phases { development-id: development-id, phase: phase }) ERR-NOT-FOUND))
      (contractor-id (get contractor-id phase-data))
    )
    (asserts! (or (is-contract-owner) (is-eq tx-sender (get-contractor-principal contractor-id))) ERR-NOT-AUTHORIZED)
    (asserts! (<= progress-percentage u100) ERR-INVALID-INPUT)
    (asserts! (<= budget-spent (get budget-allocated phase-data)) ERR-INVALID-INPUT)

    (map-set construction-phases
      { development-id: development-id, phase: phase }
      (merge phase-data {
        progress-percentage: progress-percentage,
        budget-spent: budget-spent
      })
    )
    (ok true)
  )
)

(define-public (complete-construction-phase (development-id uint) (phase (string-ascii 50)))
  (let
    (
      (phase-data (unwrap! (map-get? construction-phases { development-id: development-id, phase: phase }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status phase-data) "in-progress") ERR-INVALID-STATUS)
    (asserts! (is-eq (get progress-percentage phase-data) u100) ERR-INVALID-STATUS)

    (map-set construction-phases
      { development-id: development-id, phase: phase }
      (merge phase-data {
        actual-completion: (some current-block-height),
        status: "completed"
      })
    )
    (ok true)
  )
)

;; Inspection Management
(define-public (schedule-inspection
  (development-id uint)
  (phase (string-ascii 50))
  (inspector principal)
  (inspection-type (string-ascii 30))
  (scheduled-date uint))
  (let
    (
      (inspection-id (var-get next-inspection-id))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> development-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len phase) u0) ERR-INVALID-INPUT)
    (asserts! (is-authorized-inspector inspector) ERR-NOT-AUTHORIZED)
    (asserts! (> scheduled-date block-height) ERR-INVALID-INPUT)

    (map-set inspections
      { inspection-id: inspection-id }
      {
        development-id: development-id,
        phase: phase,
        inspector: inspector,
        inspection-type: inspection-type,
        scheduled-date: scheduled-date,
        completed-date: none,
        status: "scheduled",
        passed: false,
        score: u0,
        notes: "",
        violations: (list),
        follow-up-required: false,
        follow-up-date: none
      }
    )

    (var-set next-inspection-id (+ inspection-id u1))
    (ok inspection-id)
  )
)

(define-public (complete-inspection
  (inspection-id uint)
  (passed bool)
  (score uint)
  (notes (string-ascii 1000))
  (violations (list 10 (string-ascii 200)))
  (follow-up-required bool))
  (let
    (
      (inspection-data (unwrap! (map-get? inspections { inspection-id: inspection-id }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-eq tx-sender (get inspector inspection-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status inspection-data) "scheduled") ERR-INVALID-STATUS)
    (asserts! (<= score u100) ERR-INVALID-INPUT)

    (map-set inspections
      { inspection-id: inspection-id }
      (merge inspection-data {
        completed-date: (some current-block-height),
        status: "completed",
        passed: passed,
        score: score,
        notes: notes,
        violations: violations,
        follow-up-required: follow-up-required,
        follow-up-date: (if follow-up-required (some (+ current-block-height u144)) none) ;; 1 day follow-up
      })
    )

    ;; Update phase quality score
    (try! (update-phase-quality-score (get development-id inspection-data) (get phase inspection-data) score))

    (ok true)
  )
)

;; Payment Management
(define-public (create-payment-milestone
  (development-id uint)
  (milestone (string-ascii 50))
  (amount uint)
  (contractor-id uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> development-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len milestone) u0) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? contractors { contractor-id: contractor-id })) ERR-NOT-FOUND)
    (asserts! (is-none (map-get? payment-milestones { development-id: development-id, milestone: milestone })) ERR-ALREADY-EXISTS)

    (map-set payment-milestones
      { development-id: development-id, milestone: milestone }
      {
        amount: amount,
        contractor-id: contractor-id,
        requirements-met: false,
        inspection-passed: false,
        payment-released: false,
        released-at: none,
        released-by: none
      }
    )
    (ok true)
  )
)

(define-public (release-milestone-payment (development-id uint) (milestone (string-ascii 50)))
  (let
    (
      (milestone-data (unwrap! (map-get? payment-milestones { development-id: development-id, milestone: milestone }) ERR-NOT-FOUND))
      (current-block-height block-height)
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (get requirements-met milestone-data) ERR-INVALID-STATUS)
    (asserts! (get inspection-passed milestone-data) ERR-INVALID-STATUS)
    (asserts! (not (get payment-released milestone-data)) ERR-INVALID-STATUS)

    (map-set payment-milestones
      { development-id: development-id, milestone: milestone }
      (merge milestone-data {
        payment-released: true,
        released-at: (some current-block-height),
        released-by: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Helper Functions
(define-private (get-contractor-principal (contractor-id uint))
  (get principal (unwrap! (map-get? contractors { contractor-id: contractor-id }) tx-sender))
)

(define-private (update-phase-quality-score (development-id uint) (phase (string-ascii 50)) (inspection-score uint))
  (let
    (
      (phase-data (unwrap! (map-get? construction-phases { development-id: development-id, phase: phase }) ERR-NOT-FOUND))
      (current-score (get quality-score phase-data))
      (new-score (if (is-eq current-score u0) inspection-score (/ (+ current-score inspection-score) u2)))
    )
    (map-set construction-phases
      { development-id: development-id, phase: phase }
      (merge phase-data { quality-score: new-score })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-construction-phase (development-id uint) (phase (string-ascii 50)))
  (map-get? construction-phases { development-id: development-id, phase: phase })
)

(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections { inspection-id: inspection-id })
)

(define-read-only (get-contractor (contractor-id uint))
  (map-get? contractors { contractor-id: contractor-id })
)

(define-read-only (get-contractor-by-principal (contractor principal))
  (match (map-get? contractor-principals { principal: contractor })
    contractor-info (map-get? contractors { contractor-id: (get contractor-id contractor-info) })
    none
  )
)

(define-read-only (get-payment-milestone (development-id uint) (milestone (string-ascii 50)))
  (map-get? payment-milestones { development-id: development-id, milestone: milestone })
)

(define-read-only (get-next-inspection-id)
  (var-get next-inspection-id)
)

(define-read-only (get-next-contractor-id)
  (var-get next-contractor-id)
)

(define-read-only (is-phase-ready-for-payment (development-id uint) (phase (string-ascii 50)))
  (match (map-get? construction-phases { development-id: development-id, phase: phase })
    phase-data (and
      (is-eq (get status phase-data) "completed")
      (>= (get quality-score phase-data) u70)
    )
    false
  )
)
