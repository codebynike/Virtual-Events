# Virtual Event Hosting Smart Contract

A comprehensive Clarity smart contract for managing virtual events with tickets, refunds, ratings, and access control on the Stacks blockchain.

## Overview

This smart contract enables users to create and manage virtual events with built-in ticketing functionality. Event organizers can create events, set ticket prices, manage capacity, and handle refunds. Attendees can purchase tickets, request refunds within specified deadlines, and rate completed events.

## Features

### Core Functionality
- **Event Creation**: Organizers can create virtual events with detailed information
- **Ticket Sales**: Automated ticket purchasing with STX payments
- **Refund System**: Time-based refund mechanism before event starts
- **Access Control**: Meeting link access for ticket holders only
- **Event Management**: Cancel, complete, and update events
- **Rating System**: Post-event rating and review system

### Platform Features
- **Platform Fees**: Configurable percentage-based platform fees
- **Organizer Statistics**: Track events created, revenue, and ratings
- **Event Status Management**: Active, cancelled, and completed states
- **Emergency Controls**: Admin functions for platform management

## Contract Structure

### Data Maps
- `events`: Stores event information and metadata
- `tickets`: Tracks ticket purchases and access rights
- `organizer-stats`: Maintains organizer performance metrics
- `event-ratings`: Stores attendee ratings and reviews

### Constants
- `CONTRACT-OWNER`: The contract deployer with admin privileges
- Error codes ranging from u100 to u117 for different failure scenarios
- Event status constants for state management

## Public Functions

### Event Management

#### create-event
Creates a new virtual event with specified parameters.

**Parameters:**
- `title` (string-ascii 100): Event title
- `description` (string-ascii 500): Event description
- `start-time` (uint): Event start time in block height
- `end-time` (uint): Event end time in block height
- `ticket-price` (uint): Price per ticket in microSTX
- `max-capacity` (uint): Maximum number of attendees
- `refund-deadline` (uint): Last block for refund requests
- `meeting-link` (string-ascii 200): Virtual meeting access link

**Returns:** Event ID on success

#### cancel-event
Allows organizers to cancel their events before they start.

**Parameters:**
- `event-id` (uint): ID of the event to cancel

**Access:** Event organizer only

#### complete-event
Marks an event as completed after it ends.

**Parameters:**
- `event-id` (uint): ID of the event to complete

**Access:** Event organizer only

#### update-meeting-link
Updates the meeting link for an active event.

**Parameters:**
- `event-id` (uint): ID of the event
- `new-link` (string-ascii 200): New meeting link

**Access:** Event organizer only

### Ticket Operations

#### purchase-ticket
Purchases a ticket for a specified event.

**Parameters:**
- `event-id` (uint): ID of the event

**Payment:** Automatically transfers ticket price + platform fee

#### refund-ticket
Requests a refund for a purchased ticket.

**Parameters:**
- `event-id` (uint): ID of the event

**Conditions:** Must be before refund deadline and event start time

### Rating System

#### rate-event
Submit a rating and review for a completed event.

**Parameters:**
- `event-id` (uint): ID of the completed event
- `rating` (uint): Rating from 1 to 5
- `review` (string-ascii 200): Written review

**Access:** Ticket holders only, after event completion

### Admin Functions

#### set-platform-fee
Updates the platform fee percentage.

**Parameters:**
- `new-fee-percentage` (uint): New fee in basis points (max 1000 = 10%)

**Access:** Contract owner only

#### emergency-withdraw
Withdraws STX from the contract in emergencies.

**Parameters:**
- `amount` (uint): Amount to withdraw in microSTX

**Access:** Contract owner only

## Read-Only Functions

### Event Information
- `get-event`: Retrieve event details
- `is-event-active`: Check if event is active
- `get-available-spots`: Get remaining capacity

### Ticket Information
- `get-ticket`: Retrieve ticket details
- `has-ticket`: Check if user has valid ticket
- `can-refund-ticket`: Check refund eligibility

### Statistics
- `get-organizer-stats`: Get organizer metrics
- `get-event-rating`: Get specific event rating

### Platform Information
- `get-platform-fee-percentage`: Get current platform fee
- `calculate-platform-fee`: Calculate fee for given amount

## Error Codes

- `u100`: Owner only operation
- `u101`: Event/ticket not found
- `u102`: Unauthorized access
- `u103`: Event not active
- `u104`: Event at full capacity
- `u105`: Insufficient payment
- `u106`: Already registered
- `u107`: Refund not allowed
- `u108`: Event already started
- `u109`: Invalid time specification
- `u110`: Invalid capacity
- `u111`: Invalid rating (must be 1-5)
- `u112`: Event not completed
- `u113`: Already rated
- `u114`: Invalid fee percentage
- `u115`: Invalid input
- `u116`: Invalid amount
- `u117`: Empty string

## Usage Examples

### Creating an Event
```clarity
(contract-call? .virtual-events create-event
    "Tech Conference 2024"
    "Annual technology conference featuring blockchain innovations"
    u1000000  ;; start-time
    u1000100  ;; end-time
    u5000000  ;; ticket-price (5 STX)
    u100      ;; max-capacity
    u999990   ;; refund-deadline
    "https://zoom.us/meeting/abc123"
)
```

### Purchasing a Ticket
```clarity
(contract-call? .virtual-events purchase-ticket u1)
```

### Requesting a Refund
```clarity
(contract-call? .virtual-events refund-ticket u1)
```

### Rating an Event
```clarity
(contract-call? .virtual-events rate-event u1 u5 "Excellent presentation and networking!")
```

## Security Features

- **Input Validation**: Comprehensive validation for all user inputs
- **Access Control**: Role-based permissions for organizers and attendees
- **Time-based Restrictions**: Enforced deadlines for refunds and operations
- **Payment Security**: Direct STX transfers with proper error handling
- **State Management**: Consistent event status tracking

## Deployment Notes

1. The contract deployer becomes the `CONTRACT-OWNER` with admin privileges
2. Platform fee is initially set to 2.5% (250 basis points)
3. All monetary amounts are in microSTX (1 STX = 1,000,000 microSTX)
4. Block heights are used for time-based operations

## Integration Guidelines

### Frontend Integration
- Use read-only functions to display event information
- Implement proper error handling for all error codes
- Show platform fees during ticket purchase flow
- Validate user inputs before contract calls

### Backend Integration
- Monitor contract events for real-time updates
- Implement proper STX balance checks before transactions
- Handle asynchronous transaction confirmations
- Store off-chain data (images, detailed descriptions) separately