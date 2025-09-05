;; Virtual Event Hosting Smart Contract
;; A comprehensive contract for managing virtual events with tickets, refunds, and access control

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-EVENT-NOT-ACTIVE (err u103))
(define-constant ERR-EVENT-FULL (err u104))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u105))
(define-constant ERR-ALREADY-REGISTERED (err u106))
(define-constant ERR-REFUND-NOT-ALLOWED (err u107))
(define-constant ERR-EVENT-STARTED (err u108))
(define-constant ERR-INVALID-TIME (err u109))
(define-constant ERR-INVALID-CAPACITY (err u110))
(define-constant ERR-INVALID-INPUT (err u115))
(define-constant ERR-INVALID-AMOUNT (err u116))
(define-constant ERR-EMPTY-STRING (err u117))

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% in basis points

;; Event status enumeration
(define-constant EVENT-STATUS-ACTIVE u1)
(define-constant EVENT-STATUS-CANCELLED u2)
(define-constant EVENT-STATUS-COMPLETED u3)

;; Data Maps
(define-map events
    { event-id: uint }
    {
        organizer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        start-time: uint,
        end-time: uint,
        ticket-price: uint,
        max-capacity: uint,
        current-attendees: uint,
        status: uint,
        refund-deadline: uint,
        meeting-link: (string-ascii 200),
        created-at: uint
    }
)

(define-map tickets
    { event-id: uint, attendee: principal }
    {
        purchased-at: uint,
        access-granted: bool,
        refunded: bool,
        ticket-type: (string-ascii 20)
    }
)

(define-map organizer-stats
    { organizer: principal }
    {
        events-created: uint,
        total-revenue: uint,
        rating: uint,
        total-ratings: uint
    }
)

(define-map event-ratings
    { event-id: uint, attendee: principal }
    {
        rating: uint,
        review: (string-ascii 200),
        created-at: uint
    }
)

;; Read-only functions

(define-read-only (get-event (event-id uint))
    (map-get? events { event-id: event-id })
)

(define-read-only (get-ticket (event-id uint) (attendee principal))
    (map-get? tickets { event-id: event-id, attendee: attendee })
)

(define-read-only (get-organizer-stats (organizer principal))
    (default-to 
        { events-created: u0, total-revenue: u0, rating: u0, total-ratings: u0 }
        (map-get? organizer-stats { organizer: organizer })
    )
)

(define-read-only (get-event-rating (event-id uint) (attendee principal))
    (map-get? event-ratings { event-id: event-id, attendee: attendee })
)

(define-read-only (is-event-active (event-id uint))
    (match (get-event event-id)
        event-data (is-eq (get status event-data) EVENT-STATUS-ACTIVE)
        false
    )
)

(define-read-only (has-ticket (event-id uint) (attendee principal))
    (match (get-ticket event-id attendee)
        ticket-data (and 
            (not (get refunded ticket-data))
            (get access-granted ticket-data)
        )
        false
    )
)

(define-read-only (can-refund-ticket (event-id uint) (attendee principal))
    (match (get-event event-id)
        event-data 
        (match (get-ticket event-id attendee)
            ticket-data (and
                (not (get refunded ticket-data))
                (<= stacks-block-height (get refund-deadline event-data))
                (< stacks-block-height (get start-time event-data))
            )
            false
        )
        false
    )
)

(define-read-only (get-platform-fee-percentage)
    (var-get platform-fee-percentage)
)

(define-read-only (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-percentage)) u10000)
)

(define-read-only (get-available-spots (event-id uint))
    (match (get-event event-id)
        event-data (- (get max-capacity event-data) (get current-attendees event-data))
        u0
    )
)

;; Input validation helpers

(define-private (is-valid-string (input (string-ascii 100)))
    (> (len input) u0)
)

(define-private (is-valid-long-string (input (string-ascii 500)))
    (> (len input) u0)
)

(define-private (is-valid-link (input (string-ascii 200)))
    (> (len input) u0)
)

(define-private (is-valid-review (input (string-ascii 200)))
    (> (len input) u0)
)

(define-private (is-reasonable-price (price uint))
    (and (>= price u0) (<= price u1000000000)) ;; Max 1 billion microSTX
)

(define-private (is-reasonable-amount (amount uint))
    (and (> amount u0) (<= amount u1000000000)) ;; Max 1 billion microSTX for withdrawals
)

;; Public functions

(define-public (create-event 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (start-time uint)
    (end-time uint)
    (ticket-price uint)
    (max-capacity uint)
    (refund-deadline uint)
    (meeting-link (string-ascii 200))
)
    (let 
        (
            (event-id (var-get next-event-id))
            (current-time stacks-block-height)
        )
        ;; Input validation
        (asserts! (is-valid-string title) ERR-EMPTY-STRING)
        (asserts! (is-valid-long-string description) ERR-EMPTY-STRING)
        (asserts! (is-reasonable-price ticket-price) ERR-INVALID-INPUT)
        (asserts! (is-valid-link meeting-link) ERR-EMPTY-STRING)
        
        ;; Business logic validation
        (asserts! (> start-time current-time) ERR-INVALID-TIME)
        (asserts! (> end-time start-time) ERR-INVALID-TIME)
        (asserts! (> max-capacity u0) ERR-INVALID-CAPACITY)
        (asserts! (<= refund-deadline start-time) ERR-INVALID-TIME)
        
        ;; Create event
        (map-set events 
            { event-id: event-id }
            {
                organizer: tx-sender,
                title: title,
                description: description,
                start-time: start-time,
                end-time: end-time,
                ticket-price: ticket-price,
                max-capacity: max-capacity,
                current-attendees: u0,
                status: EVENT-STATUS-ACTIVE,
                refund-deadline: refund-deadline,
                meeting-link: meeting-link,
                created-at: current-time
            }
        )
        
        ;; Update organizer stats
        (update-organizer-stats tx-sender u1 u0)
        
        ;; Increment next event ID
        (var-set next-event-id (+ event-id u1))
        
        (ok event-id)
    )
)

(define-public (purchase-ticket (event-id uint))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
            (ticket-price (get ticket-price event-data))
            (platform-fee (calculate-platform-fee ticket-price))
            (total-cost (+ ticket-price platform-fee))
        )
        ;; Validation
        (asserts! (is-eq (get status event-data) EVENT-STATUS-ACTIVE) ERR-EVENT-NOT-ACTIVE)
        (asserts! (< (get current-attendees event-data) (get max-capacity event-data)) ERR-EVENT-FULL)
        (asserts! (is-none (get-ticket event-id tx-sender)) ERR-ALREADY-REGISTERED)
        (asserts! (< stacks-block-height (get start-time event-data)) ERR-EVENT-STARTED)
        
        ;; Transfer payment to organizer
        (try! (stx-transfer? ticket-price tx-sender (get organizer event-data)))
        
        ;; Transfer platform fee to contract owner (if fee > 0)
        (if (> platform-fee u0)
            (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
            true
        )
        
        ;; Create ticket
        (map-set tickets 
            { event-id: event-id, attendee: tx-sender }
            {
                purchased-at: stacks-block-height,
                access-granted: true,
                refunded: false,
                ticket-type: "standard"
            }
        )
        
        ;; Update event attendee count
        (map-set events 
            { event-id: event-id }
            (merge event-data { current-attendees: (+ (get current-attendees event-data) u1) })
        )
        
        ;; Update organizer revenue
        (update-organizer-stats (get organizer event-data) u0 ticket-price)
        
        (ok true)
    )
)

(define-public (refund-ticket (event-id uint))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
            (ticket-data (unwrap! (get-ticket event-id tx-sender) ERR-NOT-FOUND))
            (refund-amount (get ticket-price event-data))
        )
        ;; Validation
        (asserts! (not (get refunded ticket-data)) ERR-REFUND-NOT-ALLOWED)
        (asserts! (<= stacks-block-height (get refund-deadline event-data)) ERR-REFUND-NOT-ALLOWED)
        (asserts! (< stacks-block-height (get start-time event-data)) ERR-EVENT-STARTED)
        
        ;; Process refund from organizer to attendee
        (try! (stx-transfer? refund-amount (get organizer event-data) tx-sender))
        
        ;; Update ticket status
        (map-set tickets 
            { event-id: event-id, attendee: tx-sender }
            (merge ticket-data { refunded: true, access-granted: false })
        )
        
        ;; Update event attendee count
        (map-set events 
            { event-id: event-id }
            (merge event-data { current-attendees: (- (get current-attendees event-data) u1) })
        )
        
        ;; Update organizer stats (subtract revenue)
        (update-organizer-stats (get organizer event-data) u0 (- u0 refund-amount))
        
        (ok true)
    )
)

(define-public (cancel-event (event-id uint))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
        )
        ;; Only organizer can cancel
        (asserts! (is-eq tx-sender (get organizer event-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status event-data) EVENT-STATUS-ACTIVE) ERR-EVENT-NOT-ACTIVE)
        (asserts! (< stacks-block-height (get start-time event-data)) ERR-EVENT-STARTED)
        
        ;; Update event status
        (map-set events 
            { event-id: event-id }
            (merge event-data { status: EVENT-STATUS-CANCELLED })
        )
        
        (ok true)
    )
)

(define-public (complete-event (event-id uint))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
        )
        ;; Only organizer can mark as complete
        (asserts! (is-eq tx-sender (get organizer event-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status event-data) EVENT-STATUS-ACTIVE) ERR-EVENT-NOT-ACTIVE)
        (asserts! (>= stacks-block-height (get end-time event-data)) ERR-INVALID-TIME)
        
        ;; Update event status
        (map-set events 
            { event-id: event-id }
            (merge event-data { status: EVENT-STATUS-COMPLETED })
        )
        
        (ok true)
    )
)

(define-public (rate-event (event-id uint) (rating uint) (review (string-ascii 200)))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
            (ticket-data (unwrap! (get-ticket event-id tx-sender) ERR-UNAUTHORIZED))
        )
        ;; Input validation
        (asserts! (is-valid-review review) ERR-EMPTY-STRING)
        
        ;; Business logic validation
        (asserts! (and (>= rating u1) (<= rating u5)) (err u111)) ;; Rating must be 1-5
        (asserts! (is-eq (get status event-data) EVENT-STATUS-COMPLETED) (err u112))
        (asserts! (has-ticket event-id tx-sender) ERR-UNAUTHORIZED)
        (asserts! (is-none (get-event-rating event-id tx-sender)) (err u113)) ;; Already rated
        
        ;; Create rating
        (map-set event-ratings 
            { event-id: event-id, attendee: tx-sender }
            {
                rating: rating,
                review: review,
                created-at: stacks-block-height
            }
        )
        
        ;; Update organizer rating
        (update-organizer-rating (get organizer event-data) rating)
        
        (ok true)
    )
)

(define-public (update-meeting-link (event-id uint) (new-link (string-ascii 200)))
    (let 
        (
            (event-data (unwrap! (get-event event-id) ERR-NOT-FOUND))
        )
        ;; Input validation
        (asserts! (is-valid-link new-link) ERR-EMPTY-STRING)
        
        ;; Authorization validation
        (asserts! (is-eq tx-sender (get organizer event-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status event-data) EVENT-STATUS-ACTIVE) ERR-EVENT-NOT-ACTIVE)
        
        ;; Update meeting link
        (map-set events 
            { event-id: event-id }
            (merge event-data { meeting-link: new-link })
        )
        
        (ok true)
    )
)

;; Admin functions (only contract owner)

(define-public (set-platform-fee (new-fee-percentage uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (<= new-fee-percentage u1000) (err u114)) ;; Max 10%
        (var-set platform-fee-percentage new-fee-percentage)
        (ok true)
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        ;; Input validation
        (asserts! (is-reasonable-amount amount) ERR-INVALID-AMOUNT)
        
        ;; Authorization validation
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        
        ;; Execute withdrawal
        (try! (stx-transfer? amount (as-contract tx-sender) CONTRACT-OWNER))
        (ok true)
    )
)

;; Private helper functions

(define-private (update-organizer-stats (organizer principal) (events-increment uint) (revenue-change uint))
    (let 
        (
            (current-stats (get-organizer-stats organizer))
        )
        (map-set organizer-stats 
            { organizer: organizer }
            {
                events-created: (+ (get events-created current-stats) events-increment),
                total-revenue: (+ (get total-revenue current-stats) revenue-change),
                rating: (get rating current-stats),
                total-ratings: (get total-ratings current-stats)
            }
        )
    )
)

(define-private (update-organizer-rating (organizer principal) (new-rating uint))
    (let 
        (
            (current-stats (get-organizer-stats organizer))
            (current-rating (get rating current-stats))
            (total-ratings (get total-ratings current-stats))
            (updated-total-ratings (+ total-ratings u1))
            (updated-rating (/ (+ (* current-rating total-ratings) new-rating) updated-total-ratings))
        )
        (map-set organizer-stats 
            { organizer: organizer }
            (merge current-stats {
                rating: updated-rating,
                total-ratings: updated-total-ratings
            })
        )
    )
)