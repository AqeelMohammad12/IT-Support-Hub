# IT Service Hub

A low-code IT ticketing system built with **Power Apps**, **Power Automate**, and **SharePoint lists**. Employees submit tickets or try a self-service troubleshooter first. Tickets are routed to a team by category, given a priority-based SLA deadline, escalated automatically if they go overdue, and closed out with a resolution notice to the requester.

> Built as a portfolio project using lab and synthetic data only. No real organizational data is included.

## Why I built it

IT support teams lose time on three things: tickets that land with no owner, deadlines nobody tracks, and requesters who never hear back. This project automates each of those and gives technicians a single queue to work from.

## Demo

- Demo video: `<add link>`
- Screenshots: see the `/screenshots` folder

## Architecture

```
Employee ──► Canvas app ──► Tickets list ──► Flow 1: Set SLA and Notify
                │                               (SLA deadline, routing, notification)
                │
                ├─► Troubleshooter ──► KnowledgeArticles list
                │      └─ "Still need help" pre-fills the ticket form
                │
Technician ─► Technician queue ──► Tickets list ──► Flow 3: Resolution Notice
                                        ▲              (resolved date, resolved by, email)
                                        │
                         Flow 2: SLA Breach Check (scheduled, every 15 min)
                                        │
                         Routing list ◄─┘ (category → team, notify address)
                         Technicians list (who sees the queue)
```

**Components**

| Component | Purpose |
|---|---|
| Canvas app | Employee view (submit and browse own tickets), troubleshooter, and technician queue |
| `Tickets` list | System of record for tickets |
| `Routing` list | Maps each category to a team and notification address, so routing rules are data, not flow logic |
| `Technicians` list | Controls who sees the technician queue |
| `KnowledgeArticles` list | Powers the self-service troubleshooter |
| Flow: Set SLA and Notify | Runs on ticket creation |
| Flow: SLA Breach Check | Runs every 15 minutes |
| Flow: Resolution Notice | Runs when a ticket is marked Resolved |

## Features

- **Ticket submission** with category, priority, and description. The requester is filled in automatically.
- **Self-service troubleshooter.** Users pick a category, search by symptom, read step-by-step fixes, and can open a pre-filled ticket if the fix doesn't work.
- **Priority-based SLA deadlines:** Critical 4 hours, High 8, Medium 24, Low 72.
- **Routing by category** through a lookup table. Tickets with no category fall back to an `Unassigned` route (Triage) instead of being silently dropped.
- **Automatic escalation.** A scheduled flow finds overdue tickets that are not resolved or closed, emails an alert, and flags the ticket so it only alerts once.
- **Technician queue.** Open tickets sorted newest first, with status, assignee, and resolution notes. Includes a refresh button.
- **Resolution notice.** Records the resolved date and who resolved it, and emails the requester the resolution notes. Works whether the technician uses the Mark as Resolved button or the form's Save changes.

## Data model

**Tickets**

| Column | Type | Notes |
|---|---|---|
| Title | Single line | Built-in |
| Description | Multiple lines | |
| Priority | Choice | Low, Medium, High, Critical |
| Status | Choice | New, In Progress, Waiting on User, Resolved, Closed |
| Category | Choice | Windows, macOS, Network/Wi-Fi, Identity/MFA, Email, Software, Hardware, Vendor. Required |
| Requester | Person | Set automatically by the app |
| Assigned to | Person | Set by technicians |
| AssignedTeam | Single line | Set by the routing flow |
| SLA Due | Date and time | Set by the routing flow |
| Escalated | Yes/No | Prevents duplicate breach alerts |
| ResolutionNotified | Yes/No | Prevents duplicate resolution emails |
| Resolved On | Date and time | Set by the resolution flow |
| ResolvedBy | Single line | Set by the resolution flow |
| Resolution notes | Multiple lines | Entered by technicians |

**Routing:** Title (category), Team, NotifyEmail.
**Technicians:** Title (email address, lowercase).
**KnowledgeArticles:** Title (symptom), Category (choice), Steps (plain text, one step per line), EscalateWhen (plain text).

## Design decisions

- **Routing as data.** Changing who handles a category is a one-cell edit in a list, with no flow changes.
- **Once-only guards.** `Escalated` and `ResolutionNotified` flags stop the scheduled and edit-triggered flows from sending repeat emails.
- **Flow owns the resolution logic.** The resolved date and notice live in a flow that watches the Status column, so behavior is identical whichever way a ticket gets resolved.
- **Create-triggered, not modified-triggered, for the first flow.** A modified trigger would re-fire every time the flow updated the item.
- **Fallback route.** Found through testing (see below) and fixed with an `Unassigned` row.

## Testing

| Test | Result |
|---|---|
| Four priorities produce SLA deadlines of 4, 8, 24, and 72 hours | Pass |
| One ticket per category routes to the right team and email | Pass |
| Notification email contains ticket number, priority, category, requester, team, and SLA | Pass |
| Employee view shows only the signed-in user's tickets | Pass |
| Technician can update status and notes and resolve a ticket | Pass |
| Overdue ticket triggers one breach email and is flagged | Pass |
| Re-running the breach check sends no duplicate | Pass |
| Resolved tickets are ignored by the breach check | Pass |
| Ticket with no category | Found a silent failure: the flow reported success but sent no email. Fixed with an `Unassigned` fallback route and a required Category field |
| Resolution via the button and via the form both send the notice with notes and resolver | Pass after moving the logic into a flow |

Other issues found and fixed during the build: list refresh behavior in the app, choice-column filtering in the flow query, an expired connection that silently stopped the flows, and a loop wrapped around an action that could skip emails on an empty lookup.

## Limitations

- **Security.** The technician queue is hidden by a lookup against a list, which controls the interface but is not real access control. A production version would use Dataverse security roles.
- **Why SharePoint, not Dataverse.** Table creation was not available in the tenant used to build this, so the data layer is SharePoint lists.
- **Connections.** Flows run on a personal user connection and stop if that sign-in expires. A production version would use a service account.
- **Reopened tickets** do not trigger a second resolution email because of the once-only guard.
- **AI agent.** I prototyped a Copilot Studio triage agent, but testing it required Copilot Credit capacity that was not available in the tenant. The self-service troubleshooter covers that need without AI.
- **Polling.** SharePoint-triggered flows poll, so notifications can take a minute or two.

## Possible next steps

- Active Directory health findings imported from a PowerShell scan and tracked as tickets
- A vendor and hardware warranty tracker
- Item-level permissions on the Tickets list
- A service-account connection and Dataverse migration

## Tech used

Power Apps (canvas), Power Automate (cloud flows), SharePoint lists, Office 365 Outlook connector, Power Fx.
