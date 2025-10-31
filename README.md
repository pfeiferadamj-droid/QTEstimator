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

- **Standard Pricebook Integration**: Uses Salesforce PricebookEntry for product pricing
- Supports custom pricebook selection or defaults to standard pricebook
- Responsive UI design
- Real-time price calculation
- Quantity-based discounting (5-20% based on volume)
- ZIP code-based shipping calculation (3 zones)
- Clear line-item breakdown
- Validation and error handling

## Prerequisites

Before deploying, ensure:
1. Products have active PricebookEntry records in the Standard Pricebook
2. For Experience Cloud, products should be in the appropriate community pricebook
3. Decoration pricing metadata is configured (default records included)

## Deployment

This is a Salesforce DX project. Deploy using:

```bash
sfdx force:source:deploy -p force-app -u <your-org-alias>
```

## Usage

Add the **quickTurnHeadwearEstimator** component to your Product Record Page in Experience Builder or Lightning App Builder.

### Configuration Options

The component supports the following optional properties:
- **recordId**: Auto-populated on Product Record Pages
- **productName**: Optional override for product display name
- **pricebookId**: Optional Pricebook2 ID (defaults to Standard Pricebook)
