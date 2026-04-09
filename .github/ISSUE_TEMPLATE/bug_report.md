---
name: Bug Report
description: Report a bug or issue
title: "[BUG] "
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: |
        Thank you for reporting a bug! Please fill out the details below. Use `@github-copilot fix` in comments to get an AI-generated fix.

  - type: dropdown
    id: severity
    attributes:
      label: Severity
      description: How severe is this bug?
      options:
        - Low - Minor UI issue, no impact on functionality
        - Medium - Feature works but with issues
        - High - Feature broken or significant performance issue
        - Critical - System down, data loss, security vulnerability
      default: 1

  - type: textarea
    id: description
    attributes:
      label: Description
      description: Clear description of the bug
      placeholder: |
        What happened?
        What did you expect to happen?
        What actually happened?
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      description: How can we reproduce this?
      placeholder: |
        1. Go to...
        2. Click...
        3. Observe error...
    validations:
      required: true

  - type: textarea
    id: environment
    attributes:
      label: Environment
      placeholder: |
        - Backend Version: [e.g. 1.0.0]
        - Frontend Version: [e.g. 1.0.0]
        - OS: [e.g. iOS 17, Android 14]
        - Device: [e.g. iPhone 15, Pixel 8]
      value: |
        - Backend Version:
        - Frontend Version:
        - OS:
        - Device:

  - type: textarea
    id: logs
    attributes:
      label: Error Logs / Stack Trace
      description: Paste error messages, stack traces, or logs
      render: bash

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots
      description: Add screenshots showing the issue (if applicable)

  - type: checkboxes
    id: checks
    attributes:
      label: Verification
      options:
        - label: I have checked existing issues to avoid duplicates
          required: true
        - label: I have provided enough details to reproduce
          required: true
        - label: I have included relevant logs/screenshots
          required: false

  - type: markdown
    attributes:
      value: |
        ## 🤖 Copilot Commands
        Once this issue is created, you can:
        - Use `@github-copilot suggest` to get implementation suggestions
        - Use `@github-copilot fix` to automatically create a PR with a fix
        - Use `@github-copilot explain` for detailed analysis
        - Use `@github-copilot generate-test` to create test cases
