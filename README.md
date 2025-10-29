# Quick Turn Headwear Estimator

A Salesforce Lightning Web Component (LWC) for estimating quick-turn headwear orders with decoration placement pricing and shipping calculations.

## Overview

This LWC provides a standalone estimator that:
- Accepts a Product2 record as input from the Product Detail Page (PDP)
- Allows users to select up to 3 decoration placements (1 main + 2 additional)
- Captures quantity input with MOQ rules (72, 96, 144, 288, 432, 576, 1008, 2880, 5760)
- Optionally captures shipping ZIP code
- Applies real-time pricing logic with line-item breakdown
- Includes defensive fallbacks for invalid ZIP and no decorations

## Components

### Lightning Web Component
- **quickTurnHeadwearEstimator**: Main component for Product Record Pages

### Apex Classes
- **QuickTurnEstimatorController**: Controller for fetching decoration prices and calculating totals

### Custom Metadata
- **Decoration_Price__mdt**: Stores decoration placement pricing information

## Features

- Responsive UI design
- Real-time price calculation
- Quantity-based discounting
- ZIP code-based shipping calculation
- Clear line-item breakdown
- Validation and error handling

## Deployment

This is a Salesforce DX project. Deploy using:

```bash
sfdx force:source:deploy -p force-app -u <your-org-alias>
```

## Usage

Add the **quickTurnHeadwearEstimator** component to your Product Record Page in Experience Builder or Lightning App Builder.
