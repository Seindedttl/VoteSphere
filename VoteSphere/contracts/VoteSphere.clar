;; ----------------------------------------------------------
;; VoteSphere: Blockchain-Powered Consensus Platform
;; ----------------------------------------------------------
;; Description:
;; This smart contract implements a decentralized voting system
;; allowing users to create proposals, vote on them, and close
;; proposals once voting has ended. Additional features include
;; vote revocation and extending voting periods.
;; ----------------------------------------------------------

;; ----------------------------
;; Data Structures
;; ----------------------------
(define-map proposals
  { id: uint }
  { creator: principal, description: (string-ascii 256), votes-for: uint, votes-against: uint, active: bool, created-at: uint, ends-at: uint, quorum: uint })

(define-map voters
  { proposal-id: uint, voter: principal }
  { voted-for: bool })

(define-data-var proposal-count uint u0)
(define-constant voting-duration u1000)
(define-constant min-quorum u10)

;; ----------------------------
;; Proposal Management
;; ----------------------------
(define-public (create-proposal (desc (string-ascii 256)) (quorum uint))
  (if (>= quorum min-quorum)
    (let ((proposal-id (+ (var-get proposal-count) u1)))
      (var-set proposal-count proposal-id)
      (map-set proposals { id: proposal-id }
        { creator: tx-sender, description: desc, votes-for: u0, votes-against: u0, active: true, created-at: block-height, ends-at: (+ block-height voting-duration), quorum: quorum })
      (ok proposal-id))
    (err "Quorum too low")))

(define-public (close-proposal (proposal-id uint))
  (match (map-get? proposals { id: proposal-id })
    proposal
    (if (or (is-eq tx-sender (get creator proposal)) (>= block-height (get ends-at proposal)))
      (begin
        (map-set proposals { id: proposal-id }
          (merge proposal { active: false }))
        (ok "Proposal closed"))
      (err "Only creator can close proposal or voting period expired"))
    (err "Proposal not found")))

;; ----------------------------
;; Voting Functions
;; ----------------------------
(define-public (vote (proposal-id uint) (in-favor bool))
  (match (map-get? proposals { id: proposal-id })
    proposal
    (if (or (not (get active proposal)) (>= block-height (get ends-at proposal)))
      (err "Proposal is closed")
      (let ((voter-record (map-get? voters { proposal-id: proposal-id, voter: tx-sender })))
        (match voter-record
          voted
          (err "Already voted")
          (begin
            (map-set voters { proposal-id: proposal-id, voter: tx-sender }
              { voted-for: in-favor })
            (let ((updated-proposal
                  { creator: (get creator proposal),
                    description: (get description proposal),
                    votes-for: (if in-favor (+ (get votes-for proposal) u1) (get votes-for proposal)),
                    votes-against: (if (not in-favor) (+ (get votes-against proposal) u1) (get votes-against proposal)),
                    active: (get active proposal),
                    created-at: (get created-at proposal),
                    ends-at: (get ends-at proposal),
                    quorum: (get quorum proposal) }))
              (map-set proposals { id: proposal-id } updated-proposal))
            (ok "Vote cast")))))
    (err "Proposal not found")))

(define-public (revoke-vote (proposal-id uint))
  (match (map-get? voters { proposal-id: proposal-id, voter: tx-sender })
    vote-record
    (match (map-get? proposals { id: proposal-id })
      proposal
      (if (get active proposal)
        (begin
          (map-delete voters { proposal-id: proposal-id, voter: tx-sender })
          (let ((updated-proposal
                { creator: (get creator proposal),
                  description: (get description proposal),
                  votes-for: (if (get voted-for vote-record)
                                (- (get votes-for proposal) u1)
                                (get votes-for proposal)),
                  votes-against: (if (not (get voted-for vote-record))
                                    (- (get votes-against proposal) u1)
                                    (get votes-against proposal)),
                  active: (get active proposal),
                  created-at: (get created-at proposal),
                  ends-at: (get ends-at proposal),
                  quorum: (get quorum proposal) }))
            (map-set proposals { id: proposal-id } updated-proposal)
            (ok "Vote revoked")))
        (err "Proposal is closed"))
      (err "Proposal not found"))
    (err "No vote found")))


