---
name: Incident Report
description: Report a critical incident or system outage
title: "[INCIDENT] "
labels: ["incident", "critical"]
body:
  - type: markdown
    attributes:
      value: |
        🚨 **CRITICAL INCIDENT REPORT** 🚨
        
        This form is for critical issues affecting production. For regular bugs, use the Bug Report template.

  - type: textarea
    id: summary
    attributes:
      label: Incident Summary
      description: Brief description of the incident
      placeholder: "System/feature that is affected and the impact"
    validations:
      required: true

  - type: textarea
    id: impact
    attributes:
      label: Business Impact
      description: How many users are affected? What functionality is down?
      placeholder: |
        - Users affected: [number]
        - Services down: [list]
        - Revenue impact: [estimate]
        - Data loss risk: [yes/no]
    validations:
      required: true

  - type: textarea
    id: timeline
    attributes:
      label: Timeline
      description: When did it start? When was it noticed?
      placeholder: |
        - Started: [time]
        - Detected: [time]
        - Current status: [status]

  - type: textarea
    id: root_cause
    attributes:
      label: Initial Root Cause (if known)
      description: What do you think caused this?

  - type: textarea
    id: reproduction
    attributes:
      label: Reproduction Steps
      description: How can we reproduce the issue?

  - type: textarea
    id: workaround
    attributes:
      label: Temporary Workaround
      description: Is there a workaround users can apply?

  - type: checkboxes
    id: notifications
    attributes:
      label: Notifications Sent
      options:
        - label: CEO/Leadership notified
        - label: Customers notified
        - label: Support team notified
        - label: On-call engineer contacted

  - type: checkboxes
    id: actions
    attributes:
      label: Immediate Actions
      options:
        - label: Incident declared
        - label: War room opened
        - label: Incident commander assigned
        - label: Rollback plan prepared

  - type: markdown
    attributes:
      value: |
        ## 🤖 Copilot for Incident Response
        - `@github-copilot suggest` - Get quick fix suggestions
        - `@github-copilot fix` - Create emergency PR
        - `@github-copilot explain` - Root cause analysis
