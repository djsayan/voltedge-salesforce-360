# Salesforce CPQ Consulting Artifact — Requirements, User Stories & UAT

## Purpose

This document demonstrates how the implemented VoltEdge Salesforce CPQ solution can be translated from business needs into structured consulting deliverables.

It is a portfolio artifact based on functionality already implemented in VoltEdge 360. It is intended to show the analysis, requirements, acceptance-criteria, solution-mapping, and UAT skills expected from a Salesforce Consultant / CPQ-focused Administrator.

---

# Business Context

VoltEdge sells commercial EV charging solutions that combine:

- charging hardware
- installation services
- software subscriptions
- support packages

The sales team needs to configure technically valid solutions quickly while the commercial team needs consistent pricing, controlled discounting, and reliable approval governance.

The target process is:

```text
Customer / Account
        ↓
Opportunity
        ↓
Configure EV Charging Package
        ↓
Validate Product Compatibility
        ↓
Calculate Volume + Strategic Pricing
        ↓
Apply Additional Discount if Required
        ↓
Evaluate Approval Requirement
        ↓
Approve / Reject / Revise
        ↓
Generate Customer Proposal
```

---

# Stakeholders

| Stakeholder | Responsibility / Need |
| --- | --- |
| Sales Representative | Configure a valid solution and produce a quote quickly |
| Sales Manager | Approve moderate commercial discounts |
| Commercial Director | Approve higher commercial discounts |
| Sales Operations | Maintain products, pricing logic, and commercial policy |
| Finance / Commercial Governance | Ensure discounts and final pricing comply with policy |
| Customer | Receive a consistent and understandable commercial proposal |
| Salesforce Administrator / Consultant | Translate requirements into maintainable CPQ configuration and governance |

---

# Discovery / Workshop Questions

A requirements workshop for this process should clarify questions such as:

1. Which products are mandatory, optional, or mutually exclusive within each commercial package?
2. Which hardware selections require specific installation services?
3. Which software tiers are compatible with each support level?
4. Should quantity discounts be evaluated per line, per product family, or across eligible quote lines?
5. Which customers qualify for strategic pricing and where should this eligibility be maintained?
6. In what order should automated discounts and user-entered discounts affect the final price?
7. What discount thresholds require approval and who is responsible at each level?
8. What is the absolute maximum commercial discount that can be offered?
9. Which quote changes invalidate a previous approval?
10. Which fields should remain editable while a quote is under approval?
11. What information must appear on the customer-facing proposal?
12. Which scenarios must be validated during UAT before release?

These questions separate business policy from Salesforce implementation details and reduce the risk of building rules before the commercial process is understood.

---

# Business Requirements

## BR-001 — Configurable Commercial Package

Sales users must be able to configure a complete commercial EV charging solution from a reusable package containing hardware, installation, software, and support options.

### Business value

Reduces manual quote assembly and gives Sales a consistent product structure.

### Implemented solution

`VoltEdge Commercial Charging Package` with CPQ Product Options.

---

## BR-002 — High-Power Charger Compatibility

When a 150 kW charger is selected, the quote must include the compatible Premium Installation option.

### Business value

Prevents technically invalid or under-scoped customer proposals.

### Implemented solution

CPQ Product Rule enforcing the charger / installation dependency.

---

## BR-003 — Enterprise Support Compatibility

Enterprise / 24x7 Support must only be sold with the compatible Premium Software configuration.

### Business value

Prevents unsupported service commitments and inconsistent commercial packages.

### Implemented solution

CPQ Product Rule preventing the incompatible Basic Software combination and requiring Premium Software where appropriate.

---

## BR-004 — Quantity-Based Pricing

Eligible charger quantities must drive an automatic volume discount according to the defined commercial pricing tiers.

### Business value

Removes manual volume-discount calculations and improves pricing consistency.

### Implemented solution

- CPQ Summary Variable for aggregate quantity logic
- `VE Charger Volume Discount` Discount Schedule

---

## BR-005 — Strategic Customer Pricing

Customers classified for strategic commercial treatment must receive the relevant pricing adjustment automatically.

### Business value

Ensures negotiated customer treatment is applied consistently without relying on Sales users to remember special pricing rules.

### Implemented solution

Account-level commercial attribute evaluated by a CPQ Price Rule.

---

## BR-006 — Pricing Waterfall

The final quote price must reflect the combined effect of standard list pricing, automated volume pricing, account-based pricing, and any permitted additional discount.

### Business value

Provides a predictable and explainable commercial calculation path.

### Implemented pricing flow

```text
Price Book / List Price
        ↓
Quantity-based Volume Pricing
        ↓
Account-based Strategic Pricing
        ↓
Additional / Manual Discount
        ↓
Final Net Price
```

---

## BR-007 — Discount Governance

Commercial discounts must be governed according to the maximum effective discount across Quote Lines.

Policy:

| Effective Discount | Required Action |
| ---: | --- |
| 0%–10% | No approval |
| >10%–20% | Sales Manager approval |
| >20%–30% | Commercial Director approval |
| >30% | Blocked |

Exactly 30.000% is permitted; values above 30% are rejected.

### Business value

Protects margin and prevents approval rules from being bypassed through alternative price-entry methods.

### Implemented solution

- immutable approval pricing basis
- effective-discount calculation
- maximum line discount rollup
- Flow-based routing logic
- Salesforce Approval Process
- validation rule enforcing the hard 30% cap

---

## BR-008 — Discount Justification

Any effective commercial discount must include a valid Discount Reason / justification.

### Business value

Improves auditability and gives approvers the context required to make a decision.

### Implemented solution

Validation logic on Quote Lines and governance fields on Quote.

---

## BR-009 — Approval Integrity

Commercial Quote Lines must not be modified while the Quote is in the approval process.

### Business value

Ensures the approver reviews the same commercial terms that are ultimately approved.

### Implemented solution

Apex Quote Line handler blocks commercial inserts, updates, deletes, and undeletes while the Quote is under review.

---

## BR-010 — Reapproval After Commercial Change

An approved Quote must require approval again when commercially meaningful terms change.

Commercial changes include, for example:

- Product
- Quantity
- Unit Price
- Discount
- Discount Reason
- Service Date
- approval pricing basis

### Business value

Prevents an approved quote from being changed silently after approval.

### Implemented solution

Commercial Revision control invalidates approval, returns the Quote to Draft, increments the commercial revision, and requires resubmission.

---

## BR-011 — Customer Proposal

After a commercially valid quote is prepared, Sales must be able to generate a customer-facing proposal containing relevant commercial line information.

### Business value

Provides a repeatable quote-to-proposal process and reduces manual document preparation.

### Implemented solution

VoltEdge Commercial Proposal quote template.

---

# User Stories & Acceptance Criteria

## US-001 — Configure a Valid Charging Package

**As a Sales Representative, I want to configure a complete EV charging package so that I can prepare a technically valid customer proposal without manually checking every compatibility rule.**

### Acceptance Criteria

**AC-001.1**

```gherkin
Given a Sales Representative is configuring the VoltEdge Commercial Charging Package
When the representative selects a 150 kW charger
Then Premium Installation must be required by the configuration
```

**AC-001.2**

```gherkin
Given a Sales Representative is configuring the package
When Enterprise / 24x7 Support is selected
Then the compatible Premium Software configuration must be required
And an incompatible Basic Software combination must not be accepted
```

---

## US-002 — Receive Automatic Volume Pricing

**As a Sales Representative, I want eligible charger quantities to receive the correct volume pricing automatically so that I do not calculate quantity discounts manually.**

### Acceptance Criteria

**AC-002.1**

```gherkin
Given eligible charger products exist on the quote
When their eligible quantity reaches a configured discount tier
Then the applicable volume discount must be calculated automatically
```

**AC-002.2**

```gherkin
Given eligible charger quantities are distributed across relevant quote lines
When CPQ calculates the quote
Then the pricing logic must use the intended aggregate quantity rather than treating each eligible line as an unrelated commercial purchase
```

---

## US-003 — Apply Strategic Customer Pricing

**As a Sales Representative, I want Salesforce to recognize strategic customers automatically so that their agreed commercial treatment is consistently reflected in pricing.**

### Acceptance Criteria

**AC-003.1**

```gherkin
Given the Account is classified for strategic pricing
When the quote is calculated
Then the account-driven Price Rule must apply the configured strategic pricing adjustment
```

**AC-003.2**

```gherkin
Given the Account is not eligible for strategic pricing
When the quote is calculated
Then the strategic pricing adjustment must not be applied
```

---

## US-004 — Govern Manual Discounts

**As a Commercial Manager, I want higher discounts to require the correct approval so that VoltEdge protects margin and follows commercial policy.**

### Acceptance Criteria

**AC-004.1**

```gherkin
Given the maximum effective discount on the Quote is 8%
When approval routing is recalculated
Then approval must not be required
```

**AC-004.2**

```gherkin
Given the maximum effective discount is 15%
When approval routing is recalculated
Then Sales Manager approval must be required
```

**AC-004.3**

```gherkin
Given the maximum effective discount is 25%
When approval routing is recalculated
Then Commercial Director approval must be required
```

**AC-004.4**

```gherkin
Given the effective discount is exactly 30.000%
When the Quote Line is saved
Then the value must be permitted
```

**AC-004.5**

```gherkin
Given the effective discount is greater than 30%
When the Quote Line is saved
Then the save must be blocked
```

**AC-004.6**

```gherkin
Given an effective commercial discount is applied
When the Quote Line is saved without a Discount Reason
Then the save must be blocked
```

---

## US-005 — Protect Approved Commercial Terms

**As an Approver, I want approved or in-review commercial terms to be protected so that the quote I review cannot be changed without another approval cycle.**

### Acceptance Criteria

**AC-005.1**

```gherkin
Given a Quote is currently under approval
When a user attempts to change a commercial Quote Line field
Then the commercial write must be blocked
```

**AC-005.2**

```gherkin
Given a Quote has already been approved
When a commercially meaningful Quote Line field changes
Then the current approval must be invalidated
And the Quote must return to Draft
And Commercial Revision must increase
And a new approval must be required when applicable
```

**AC-005.3**

```gherkin
Given a Quote has already been approved
When a non-commercial internal description is changed
Then the existing commercial approval must remain valid
```

---

## US-006 — Generate a Customer Proposal

**As a Sales Representative, I want to generate a professional proposal from the configured Quote so that the customer receives a consistent commercial document.**

### Acceptance Criteria

```gherkin
Given the Quote contains the configured commercial solution
When the Sales Representative generates the VoltEdge Commercial Proposal
Then the proposal must contain the relevant quote-line pricing information
And the document must reflect the current commercial Quote
```

---

# Functional Solution Mapping

| Requirement | Salesforce Capability | VoltEdge Implementation |
| --- | --- | --- |
| Configurable solution | CPQ Bundle / Product Options | VoltEdge Commercial Charging Package |
| Charger compatibility | Product Rule | 150 kW → Premium Installation |
| Support compatibility | Product Rule | Enterprise Support → Premium Software |
| Aggregate quantity | Summary Variable | Eligible charger quantity aggregation |
| Volume pricing | Discount Schedule | VE Charger Volume Discount |
| Customer-specific pricing | Price Rule | Account-driven Strategic Pricing |
| Pricing sequence | CPQ calculation + pricing controls | Volume → Strategic → Additional discount → Net Price |
| Discount threshold routing | Flow + Approval Process | Manager / Commercial Director routing |
| Hard discount maximum | Validation Rule | >30% blocked |
| Approval baseline integrity | Apex / custom field | Approval_Basis_Unit_Price__c |
| Maximum discount aggregation | Apex service | VEQuoteDiscountRollupService |
| Approval write protection | Apex Trigger / Handler | VEQuoteLineItemTrigger / VEQuoteLineItemHandler |
| Reapproval after changes | Apex + Flow | Commercial Revision lifecycle |
| Customer document | Quote Template | VoltEdge Commercial Proposal |

---

# UAT Plan

## UAT Objective

Validate the complete CPQ commercial process from product configuration through pricing and approval governance using realistic Sales personas and business scenarios.

## Entry Criteria

- CPQ products and bundle available
- required Product Rules active
- Summary Variable configured
- Discount Schedule active
- strategic-pricing Account field available
- Price Rules active
- approval hierarchy available for test users
- Quote approval process active
- test Price Books available

---

# UAT Scenarios

| ID | Scenario | Test Steps | Expected Result |
| --- | --- | --- | --- |
| UAT-01 | Standard bundle | Configure standard charger + compatible installation/software/support | Configuration accepted |
| UAT-02 | 150 kW dependency | Select 150 kW charger without Premium Installation | CPQ requires/prevents invalid installation configuration |
| UAT-03 | Enterprise Support dependency | Select Enterprise Support with Basic Software | Invalid configuration prevented; Premium Software required |
| UAT-04 | Volume pricing | Configure charger quantity meeting a volume tier | Correct `VE Charger Volume Discount` applied |
| UAT-05 | Multi-line aggregate volume | Split eligible quantity across relevant quote lines | Intended aggregate quantity drives pricing |
| UAT-06 | Strategic Account pricing | Quote an Account eligible for strategic pricing | Account-driven Price Rule applies |
| UAT-07 | Non-strategic Account | Quote a standard Account | Strategic adjustment not applied |
| UAT-08 | No-approval discount | Set maximum effective discount to 8% | Approval Required = No |
| UAT-09 | Manager approval | Set maximum effective discount to 15% | Routed to Sales Manager |
| UAT-10 | Director approval | Set maximum effective discount to 25% | Routed to Commercial Director |
| UAT-11 | 30% boundary | Set effective discount to exactly 30.000% | Save permitted |
| UAT-12 | Maximum discount guardrail | Set effective discount above 30% | Save blocked |
| UAT-13 | Missing discount reason | Apply commercial discount without reason | Save blocked |
| UAT-14 | Approval locking | Submit Quote for approval, then modify commercial Quote Line | Change blocked |
| UAT-15 | Approval + commercial revision | Approve Quote, then change Unit Price | Approval invalidated, Quote returns to Draft, revision increments |
| UAT-16 | Non-commercial edit | Approve Quote, then change internal Description only | Approval remains valid |
| UAT-17 | Proposal generation | Generate VoltEdge Commercial Proposal | Customer-facing proposal generated using current quote values |

---

# UAT Evidence to Capture

For each UAT scenario, capture where useful:

- Quote number
- Account / strategic pricing status
- configured bundle selections
- eligible quantity
- list price
- automated pricing adjustment
- manual / additional discount
- final net price
- maximum effective discount
- approval level
- approval status
- Commercial Revision value
- screenshot or generated proposal evidence
- pass / fail result
- defect reference if failed

---

# Requirements Traceability Matrix

| Business Requirement | User Story | Acceptance Criteria | UAT |
| --- | --- | --- | --- |
| BR-001 Configurable package | US-001 | AC-001.1, AC-001.2 | UAT-01–03 |
| BR-002 High-power compatibility | US-001 | AC-001.1 | UAT-02 |
| BR-003 Support compatibility | US-001 | AC-001.2 | UAT-03 |
| BR-004 Volume pricing | US-002 | AC-002.1, AC-002.2 | UAT-04–05 |
| BR-005 Strategic pricing | US-003 | AC-003.1, AC-003.2 | UAT-06–07 |
| BR-006 Pricing waterfall | US-002, US-003, US-004 | Pricing + discount ACs | UAT-04–12 |
| BR-007 Discount governance | US-004 | AC-004.1–AC-004.6 | UAT-08–13 |
| BR-008 Discount justification | US-004 | AC-004.6 | UAT-13 |
| BR-009 Approval integrity | US-005 | AC-005.1 | UAT-14 |
| BR-010 Reapproval after change | US-005 | AC-005.2, AC-005.3 | UAT-15–16 |
| BR-011 Customer proposal | US-006 | Proposal AC | UAT-17 |

---

# Definition of Done

The CPQ feature set is considered complete for this scope when:

- agreed business requirements are mapped to Salesforce capabilities
- Product Rules prevent known invalid combinations
- volume pricing and strategic pricing behave as agreed
- pricing remains explainable from list price to net price
- discount thresholds route to the correct approver
- discounts above policy maximum are blocked
- discount justification is enforced
- commercial Quote Lines are protected during approval
- material post-approval changes invalidate the approval state
- customer proposal generation works using the current Quote
- automated regression tests pass for implemented Apex governance
- UAT scenarios are executed and accepted
- release documentation is updated

---

# Consultant Talking Points

This implementation can be explained in an interview as a consulting lifecycle rather than only a configuration exercise:

```text
Business policy
      ↓
Discovery questions
      ↓
Requirements
      ↓
User stories + acceptance criteria
      ↓
CPQ solution design
      ↓
Configuration + Apex governance
      ↓
Technical tests
      ↓
UAT
      ↓
Release / support
```

A useful example is the discount process. The business requirement was not simply "create an approval process". The actual problem was to control the real effective commercial discount even when users could alter both Unit Price and the Discount field. The implemented solution therefore introduced a frozen approval pricing basis, effective-discount calculation, Quote-level maximum discount aggregation, approval routing, write protection, and approval invalidation after commercial changes.

This is the key distinction between configuring an isolated Salesforce feature and designing an end-to-end business process.
