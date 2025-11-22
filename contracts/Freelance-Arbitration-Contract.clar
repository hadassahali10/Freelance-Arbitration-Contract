
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CONTRACT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_DISPUTE_EXPIRED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_NOT_ARBITRATOR (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_MILESTONE_NOT_FOUND (err u108))
(define-constant ERR_MILESTONE_ALREADY_RELEASED (err u109))
(define-constant ERR_INVALID_MILESTONE_COUNT (err u110))
(define-constant ERR_AMENDMENT_NOT_FOUND (err u111))
(define-constant ERR_AMENDMENT_ALREADY_EXISTS (err u112))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u113))
(define-constant ERR_AMENDMENT_EXPIRED (err u114))

(define-constant STATUS_ACTIVE u0)
(define-constant STATUS_COMPLETED u1)
(define-constant STATUS_DISPUTED u2)
(define-constant STATUS_RESOLVED u3)
(define-constant STATUS_CANCELLED u4)

(define-constant DISPUTE_DURATION u144)
(define-constant MIN_ARBITRATORS u3)

(define-data-var next-contract-id uint u1)
(define-data-var dao-enabled bool false)
(define-data-var arbitration-fee uint u10)
(define-data-var next-milestone-id uint u1)
(define-data-var next-amendment-id uint u1)
(define-data-var amendment-validity-period uint u1440)

(define-map amendments
  { amendment-id: uint }
  {
    contract-id: uint,
    proposer: principal,
    new-amount: uint,
    amount-change: int,
    new-description: (string-ascii 256),
    created-at: uint,
    expires-at: uint,
    accepted: bool
  }
)

(define-map pending-amendments
  { contract-id: uint }
  { amendment-id: uint }
)

(define-map contracts
  { contract-id: uint }
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    arbitrator: (optional principal),
    status: uint,
    created-at: uint,
    dispute-deadline: (optional uint),
    description: (string-ascii 256)
  }
)

(define-map arbitrators
  { arbitrator: principal }
  { active: bool, reputation: uint }
)

(define-map dispute-votes
  { contract-id: uint, voter: principal }
  { vote: bool }
)

(define-map dispute-tallies
  { contract-id: uint }
  { votes-for-freelancer: uint, votes-for-client: uint, total-votes: uint }
)

(define-map milestones
  { milestone-id: uint }
  {
    contract-id: uint,
    amount: uint,
    description: (string-ascii 256),
    released: bool,
    sequence: uint
  }
)

(define-map contract-milestones
  { contract-id: uint }
  { milestone-count: uint, total-released: uint, has-milestones: bool }
)

(define-public (create-contract (freelancer principal) (amount uint) (arbitrator (optional principal)) (description (string-ascii 256)))
  (let (
    (contract-id (var-get next-contract-id))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? contracts { contract-id: contract-id })) ERR_CONTRACT_NOT_FOUND)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set contracts
      { contract-id: contract-id }
      {
        client: tx-sender,
        freelancer: freelancer,
        amount: amount,
        arbitrator: arbitrator,
        status: STATUS_ACTIVE,
        created-at: current-block,
        dispute-deadline: none,
        description: description
      }
    )
    (map-set contract-milestones
      { contract-id: contract-id }
      { milestone-count: u0, total-released: u0, has-milestones: false }
    )
    (var-set next-contract-id (+ contract-id u1))
    (ok contract-id)
  )
)

(define-public (create-contract-with-milestones 
  (freelancer principal) 
  (arbitrator (optional principal)) 
  (description (string-ascii 256))
  (milestone-amounts (list 10 uint))
  (milestone-descriptions (list 10 (string-ascii 256))))
  (let (
    (contract-id (var-get next-contract-id))
    (current-block stacks-block-height)
    (total-amount (fold + milestone-amounts u0))
    (milestone-count (len milestone-amounts))
  )
    (asserts! (> milestone-count u0) ERR_INVALID_MILESTONE_COUNT)
    (asserts! (is-eq milestone-count (len milestone-descriptions)) ERR_INVALID_MILESTONE_COUNT)
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? contracts { contract-id: contract-id })) ERR_CONTRACT_NOT_FOUND)
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    (map-set contracts
      { contract-id: contract-id }
      {
        client: tx-sender,
        freelancer: freelancer,
        amount: total-amount,
        arbitrator: arbitrator,
        status: STATUS_ACTIVE,
        created-at: current-block,
        dispute-deadline: none,
        description: description
      }
    )
    (map-set contract-milestones
      { contract-id: contract-id }
      { milestone-count: milestone-count, total-released: u0, has-milestones: true }
    )
    (let (
      (result (fold create-milestone-entry
        (zip milestone-amounts milestone-descriptions)
        { contract-id: contract-id, sequence: u0, success: true }))
    )
      (asserts! (get success result) ERR_INVALID_AMOUNT)
      (var-set next-contract-id (+ contract-id u1))
      (ok contract-id)
    )
  )
)

(define-private (create-milestone-entry 
  (data { amount: uint, description: (string-ascii 256) })
  (state { contract-id: uint, sequence: uint, success: bool }))
  (let (
    (milestone-id (var-get next-milestone-id))
  )
    (if (get success state)
      (begin
        (map-set milestones
          { milestone-id: milestone-id }
          {
            contract-id: (get contract-id state),
            amount: (get amount data),
            description: (get description data),
            released: false,
            sequence: (get sequence state)
          }
        )
        (var-set next-milestone-id (+ milestone-id u1))
        { contract-id: (get contract-id state), sequence: (+ (get sequence state) u1), success: true }
      )
      state
    )
  )
)

(define-private (zip (amounts (list 10 uint)) (descriptions (list 10 (string-ascii 256))))
  (map pair-items amounts descriptions)
)

(define-private (pair-items (amount uint) (description (string-ascii 256)))
  { amount: amount, description: description }
)

(define-public (release-milestone (milestone-id uint))
  (let (
    (milestone-data (unwrap! (map-get? milestones { milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
    (contract-data (unwrap! (map-get? contracts { contract-id: (get contract-id milestone-data) }) ERR_CONTRACT_NOT_FOUND))
    (contract-milestone-info (unwrap! (map-get? contract-milestones { contract-id: (get contract-id milestone-data) }) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get client contract-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (not (get released milestone-data)) ERR_MILESTONE_ALREADY_RELEASED)
    (try! (as-contract (stx-transfer? (get amount milestone-data) tx-sender (get freelancer contract-data))))
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone-data { released: true })
    )
    (map-set contract-milestones
      { contract-id: (get contract-id milestone-data) }
      (merge contract-milestone-info { total-released: (+ (get total-released contract-milestone-info) u1) })
    )
    (ok true)
  )
)

(define-public (complete-contract (contract-id uint))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get client contract-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (try! (as-contract (stx-transfer? (get amount contract-data) tx-sender (get freelancer contract-data))))
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { status: STATUS_COMPLETED })
    )
    (ok true)
  )
)

(define-public (initiate-dispute (contract-id uint))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (current-block stacks-block-height)
  )
    (asserts! (or (is-eq tx-sender (get client contract-data)) (is-eq tx-sender (get freelancer contract-data))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data {
        status: STATUS_DISPUTED,
        dispute-deadline: (some (+ current-block DISPUTE_DURATION))
      })
    )
    (if (var-get dao-enabled)
      (map-set dispute-tallies
        { contract-id: contract-id }
        { votes-for-freelancer: u0, votes-for-client: u0, total-votes: u0 }
      )
      true
    )
    (ok true)
  )
)

(define-public (resolve-dispute-single (contract-id uint) (favor-freelancer bool))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (arbitrator (unwrap! (get arbitrator contract-data) ERR_NOT_AUTHORIZED))
  )
    (asserts! (not (var-get dao-enabled)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender arbitrator) ERR_NOT_ARBITRATOR)
    (asserts! (is-eq (get status contract-data) STATUS_DISPUTED) ERR_INVALID_STATUS)
    (let (
      (recipient (if favor-freelancer (get freelancer contract-data) (get client contract-data)))
      (fee-amount (/ (get amount contract-data) (var-get arbitration-fee)))
      (transfer-amount (- (get amount contract-data) fee-amount))
    )
      (try! (as-contract (stx-transfer? transfer-amount tx-sender recipient)))
      (try! (as-contract (stx-transfer? fee-amount tx-sender arbitrator)))
      (map-set contracts
        { contract-id: contract-id }
        (merge contract-data { status: STATUS_RESOLVED })
      )
      (ok true)
    )
  )
)

(define-public (vote-on-dispute (contract-id uint) (favor-freelancer bool))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (voter-data (unwrap! (map-get? arbitrators { arbitrator: tx-sender }) ERR_NOT_ARBITRATOR))
    (current-tally (unwrap! (map-get? dispute-tallies { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (var-get dao-enabled) ERR_NOT_AUTHORIZED)
    (asserts! (get active voter-data) ERR_NOT_ARBITRATOR)
    (asserts! (is-eq (get status contract-data) STATUS_DISPUTED) ERR_INVALID_STATUS)
    (asserts! (is-none (map-get? dispute-votes { contract-id: contract-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    (map-set dispute-votes
      { contract-id: contract-id, voter: tx-sender }
      { vote: favor-freelancer }
    )
    (let (
      (new-freelancer-votes (if favor-freelancer (+ (get votes-for-freelancer current-tally) u1) (get votes-for-freelancer current-tally)))
      (new-client-votes (if favor-freelancer (get votes-for-client current-tally) (+ (get votes-for-client current-tally) u1)))
      (new-total-votes (+ (get total-votes current-tally) u1))
    )
      (map-set dispute-tallies
        { contract-id: contract-id }
        {
          votes-for-freelancer: new-freelancer-votes,
          votes-for-client: new-client-votes,
          total-votes: new-total-votes
        }
      )
      (ok true)
    )
  )
)

(define-public (finalize-dao-dispute (contract-id uint))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (tally (unwrap! (map-get? dispute-tallies { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (current-block stacks-block-height)
    (deadline (unwrap! (get dispute-deadline contract-data) ERR_DISPUTE_EXPIRED))
  )
    (asserts! (var-get dao-enabled) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status contract-data) STATUS_DISPUTED) ERR_INVALID_STATUS)
    (asserts! (>= current-block deadline) ERR_DISPUTE_EXPIRED)
    (asserts! (>= (get total-votes tally) MIN_ARBITRATORS) ERR_INVALID_STATUS)
    (let (
      (favor-freelancer (> (get votes-for-freelancer tally) (get votes-for-client tally)))
      (recipient (if favor-freelancer (get freelancer contract-data) (get client contract-data)))
    )
      (try! (as-contract (stx-transfer? (get amount contract-data) tx-sender recipient)))
      (map-set contracts
        { contract-id: contract-id }
        (merge contract-data { status: STATUS_RESOLVED })
      )
      (ok favor-freelancer)
    )
  )
)

(define-public (cancel-contract (contract-id uint))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get client contract-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (try! (as-contract (stx-transfer? (get amount contract-data) tx-sender (get client contract-data))))
    (map-set contracts
      { contract-id: contract-id }
      (merge contract-data { status: STATUS_CANCELLED })
    )
    (ok true)
  )
)

(define-public (add-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set arbitrators
      { arbitrator: arbitrator }
      { active: true, reputation: u100 }
    )
    (ok true)
  )
)

(define-public (remove-arbitrator (arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set arbitrators
      { arbitrator: arbitrator }
      { active: false, reputation: u0 }
    )
    (ok true)
  )
)

(define-public (toggle-dao-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set dao-enabled (not (var-get dao-enabled)))
    (ok (var-get dao-enabled))
  )
)

(define-public (set-arbitration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-fee u0) ERR_INVALID_AMOUNT)
    (var-set arbitration-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-contract (contract-id uint))
  (map-get? contracts { contract-id: contract-id })
)

(define-read-only (get-arbitrator-info (arbitrator principal))
  (map-get? arbitrators { arbitrator: arbitrator })
)

(define-read-only (get-dispute-tally (contract-id uint))
  (map-get? dispute-tallies { contract-id: contract-id })
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-dao-status)
  (var-get dao-enabled)
)

(define-read-only (get-arbitration-fee)
  (var-get arbitration-fee)
)

(define-read-only (get-next-contract-id)
  (var-get next-contract-id)
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

(define-read-only (get-contract-milestone-info (contract-id uint))
  (map-get? contract-milestones { contract-id: contract-id })
)

(define-public (propose-amendment (contract-id uint) (new-amount uint) (new-description (string-ascii 256)))
  (let (
    (contract-data (unwrap! (map-get? contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (current-block stacks-block-height)
    (amendment-id (var-get next-amendment-id))
    (current-amount (get amount contract-data))
    (amount-diff (if (>= new-amount current-amount) 
                     (to-int (- new-amount current-amount))
                     (- (to-int (- current-amount new-amount)))))
  )
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (or (is-eq tx-sender (get client contract-data)) 
                  (is-eq tx-sender (get freelancer contract-data))) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? pending-amendments { contract-id: contract-id })) ERR_AMENDMENT_ALREADY_EXISTS)
    (asserts! (> new-amount u0) ERR_INVALID_AMOUNT)
    (if (> new-amount current-amount)
        (begin
          (asserts! (is-eq tx-sender (get client contract-data)) ERR_NOT_AUTHORIZED)
          (try! (stx-transfer? (- new-amount current-amount) tx-sender (as-contract tx-sender)))
        )
        true
    )
    (map-set amendments
      { amendment-id: amendment-id }
      {
        contract-id: contract-id,
        proposer: tx-sender,
        new-amount: new-amount,
        amount-change: amount-diff,
        new-description: new-description,
        created-at: current-block,
        expires-at: (+ current-block (var-get amendment-validity-period)),
        accepted: false
      }
    )
    (map-set pending-amendments
      { contract-id: contract-id }
      { amendment-id: amendment-id }
    )
    (var-set next-amendment-id (+ amendment-id u1))
    (ok amendment-id)
  )
)

(define-public (accept-amendment (amendment-id uint))
  (let (
    (amendment-data (unwrap! (map-get? amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND))
    (contract-data (unwrap! (map-get? contracts { contract-id: (get contract-id amendment-data) }) ERR_CONTRACT_NOT_FOUND))
    (current-block stacks-block-height)
  )
    (asserts! (< current-block (get expires-at amendment-data)) ERR_AMENDMENT_EXPIRED)
    (asserts! (not (get accepted amendment-data)) ERR_INVALID_STATUS)
    (asserts! (is-eq (get status contract-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (or 
                (and (is-eq (get proposer amendment-data) (get client contract-data)) 
                     (is-eq tx-sender (get freelancer contract-data)))
                (and (is-eq (get proposer amendment-data) (get freelancer contract-data)) 
                     (is-eq tx-sender (get client contract-data)))) ERR_NOT_AUTHORIZED)
    (let (
      (current-amount (get amount contract-data))
      (new-amount (get new-amount amendment-data))
    )
      (if (< new-amount current-amount)
          (try! (as-contract (stx-transfer? (- current-amount new-amount) tx-sender (get client contract-data))))
          true
      )
      (map-set contracts
        { contract-id: (get contract-id amendment-data) }
        (merge contract-data {
          amount: new-amount,
          description: (get new-description amendment-data)
        })
      )
      (map-set amendments
        { amendment-id: amendment-id }
        (merge amendment-data { accepted: true })
      )
      (map-delete pending-amendments { contract-id: (get contract-id amendment-data) })
      (ok true)
    )
  )
)

(define-public (reject-amendment (amendment-id uint))
  (let (
    (amendment-data (unwrap! (map-get? amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND))
    (contract-data (unwrap! (map-get? contracts { contract-id: (get contract-id amendment-data) }) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (not (get accepted amendment-data)) ERR_INVALID_STATUS)
    (asserts! (or 
                (and (is-eq (get proposer amendment-data) (get client contract-data)) 
                     (is-eq tx-sender (get freelancer contract-data)))
                (and (is-eq (get proposer amendment-data) (get freelancer contract-data)) 
                     (is-eq tx-sender (get client contract-data)))) ERR_NOT_AUTHORIZED)
    (let (
      (current-amount (get amount contract-data))
      (new-amount (get new-amount amendment-data))
    )
      (if (> new-amount current-amount)
          (try! (as-contract (stx-transfer? (- new-amount current-amount) tx-sender (get proposer amendment-data))))
          true
      )
      (map-delete amendments { amendment-id: amendment-id })
      (map-delete pending-amendments { contract-id: (get contract-id amendment-data) })
      (ok true)
    )
  )
)

(define-read-only (get-amendment (amendment-id uint))
  (map-get? amendments { amendment-id: amendment-id })
)

(define-read-only (get-pending-amendment (contract-id uint))
  (map-get? pending-amendments { contract-id: contract-id })
)

(define-read-only (get-amendment-validity-period)
  (var-get amendment-validity-period)
)
