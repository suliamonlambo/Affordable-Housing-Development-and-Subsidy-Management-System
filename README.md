# Affordable Housing Development and Subsidy Management System

A comprehensive blockchain-based system for managing affordable housing developments, built on the Stacks blockchain using Clarity smart contracts.

## System Overview

This system provides a complete solution for affordable housing management, from initial eligibility verification through long-term compliance monitoring. It consists of five interconnected smart contracts that handle different aspects of the housing development lifecycle.

## Core Components

### 1. Housing Registry Contract (`housing-registry.clar`)
- Central registry for all housing developments
- Tracks development status, location, and basic information
- Manages developer registrations and permissions
- Stores development milestones and completion status

### 2. Eligibility Verification Contract (`eligibility-verification.clar`)
- Processes and validates applicant eligibility
- Manages income verification and family size requirements
- Tracks application status and approval workflow
- Maintains waitlists and priority scoring

### 3. Construction Monitoring Contract (`construction-monitoring.clar`)
- Tracks construction progress and milestones
- Manages quality assurance inspections
- Records compliance with building codes and standards
- Handles contractor payments tied to milestone completion

### 4. Subsidy Management Contract (`subsidy-management.clar`)
- Distributes government subsidies and grants
- Tracks subsidy allocation and usage
- Manages compliance with subsidy requirements
- Handles subsidy recapture and enforcement

### 5. Tenant Management Contract (`tenant-management.clar`)
- Manages tenant selection and lease agreements
- Tracks rent payments and affordability compliance
- Monitors long-term affordability requirements
- Handles lease renewals and tenant transitions

## Key Features

### Eligibility Verification and Application Processing
- Automated income verification against area median income (AMI)
- Family size and composition validation
- Priority scoring based on need and local preferences
- Application status tracking and notifications

### Construction Progress Monitoring
- Milestone-based progress tracking
- Quality assurance checkpoint management
- Compliance verification with affordable housing requirements
- Integration with payment release mechanisms

### Subsidy Distribution and Compliance
- Automated subsidy calculation and distribution
- Real-time compliance monitoring
- Violation detection and enforcement
- Recapture mechanisms for non-compliance

### Tenant Selection and Lease Management
- Fair and transparent tenant selection process
- Lease term management and renewals
- Rent calculation based on income and affordability requirements
- Long-term monitoring of tenant eligibility

### Long-term Affordability Monitoring
- Continuous monitoring of affordability compliance
- Automated alerts for potential violations
- Enforcement mechanisms for maintaining affordability
- Reporting and audit trail capabilities

## Data Types and Structures

### Development Record
```clarity
{
  id: uint,
  developer: principal,
  location: (string-ascii 100),
  total-units: uint,
  affordable-units: uint,
  status: (string-ascii 20),
  created-at: uint,
  completion-date: (optional uint)
}
