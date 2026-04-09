---
name: Feature Request
description: Suggest a new feature or enhancement
title: "[FEATURE] "
labels: ["enhancement"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for suggesting a feature! Use `@github-copilot suggest` to get implementation ideas.

  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: What problem does this feature solve?
      placeholder: "As a [user type], I want [feature] so that [benefit]"
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: How would you like this feature to work?
      placeholder: |
        Describe the feature in detail:
        - User flow
        - UI/UX approach
        - Technical approach
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternative Solutions
      description: Any alternative approaches you've considered?

  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria
      placeholder: |
        - [ ] Users can do X
        - [ ] System validates Y
        - [ ] Performance meets Z requirements

  - type: dropdown
    id: component
    attributes:
      label: Component
      options:
        - Backend (Django)
        - Frontend (Flutter)
        - Mobile (iOS/Android)
        - Database
        - Infrastructure
        - DevOps/CI-CD

  - type: checkboxes
    id: checks
    attributes:
      label: Verification
      options:
        - label: This feature aligns with project goals
        - label: I have checked for duplicate feature requests

  - type: markdown
    attributes:
      value: |
        ## 🤖 Copilot Assistance
        - `@github-copilot suggest` - Get implementation suggestions
        - `@github-copilot explain` - Detailed technical analysis
        - `@github-copilot generate-test` - Create test plans
