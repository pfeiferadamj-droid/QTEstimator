public with sharing class QuickTurnEstimatorController {

    /**
     * Fetches all decoration pricing options from Custom Metadata
     * @return List of decoration pricing records
     */
    @AuraEnabled(cacheable=true)
    public static List<DecorationOption> getDecorationOptions() {
        List<DecorationOption> options = new List<DecorationOption>();

        try {
            for (Decoration_Price__mdt deco : [
                SELECT Placement__c, Label__c, Flat_UpCharge__c
                FROM Decoration_Price__mdt
                ORDER BY Label__c ASC
            ]) {
                options.add(new DecorationOption(
                    deco.Placement__c,
                    deco.Label__c,
                    deco.Flat_UpCharge__c
                ));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching decoration options: ' + e.getMessage());
        }

        return options;
    }

    /**
     * Calculates the total price estimate with breakdown
     * @param productId Product2 record ID
     * @param quantity Quantity ordered
     * @param mainDecoration Main decoration placement
     * @param additionalDecorations List of additional decoration placements
     * @param zipCode Optional shipping ZIP code
     * @return PriceEstimate object with breakdown
     */
    @AuraEnabled
    public static PriceEstimate calculateEstimate(
        Id productId,
        Integer quantity,
        String mainDecoration,
        List<String> additionalDecorations,
        String zipCode
    ) {
        try {
            // Validate inputs
            if (quantity == null || quantity < 72) {
                throw new AuraHandledException('Minimum order quantity is 72.');
            }

            if (String.isBlank(mainDecoration)) {
                throw new AuraHandledException('Please select a main decoration placement.');
            }

            // Get product base price
            Product2 product = [
                SELECT Id, Name, UnitPrice__c
                FROM Product2
                WHERE Id = :productId
                LIMIT 1
            ];

            Decimal basePrice = product.UnitPrice__c != null ? product.UnitPrice__c : 0;

            // Apply quantity discounts
            Decimal discountedPrice = applyQuantityDiscount(basePrice, quantity);

            // Get decoration prices
            Map<String, Decimal> decorationPrices = getDecorationPriceMap();

            // Calculate decoration charges
            Decimal mainDecorationCharge = decorationPrices.containsKey(mainDecoration)
                ? decorationPrices.get(mainDecoration)
                : 0;

            Decimal additionalDecorationCharge = 0;
            if (additionalDecorations != null) {
                for (String decoration : additionalDecorations) {
                    if (decorationPrices.containsKey(decoration)) {
                        additionalDecorationCharge += decorationPrices.get(decoration);
                    }
                }
            }

            // Calculate per-unit price with decorations
            Decimal perUnitPrice = discountedPrice + mainDecorationCharge + additionalDecorationCharge;

            // Calculate subtotal
            Decimal subtotal = perUnitPrice * quantity;

            // Calculate shipping
            ShippingCalculation shipping = calculateShipping(zipCode, quantity);

            // Calculate total
            Decimal total = subtotal + shipping.amount;

            // Build estimate
            PriceEstimate estimate = new PriceEstimate();
            estimate.basePrice = basePrice;
            estimate.discountedPrice = discountedPrice;
            estimate.quantity = quantity;
            estimate.mainDecorationCharge = mainDecorationCharge;
            estimate.additionalDecorationCharge = additionalDecorationCharge;
            estimate.perUnitPrice = perUnitPrice;
            estimate.subtotal = subtotal;
            estimate.shippingAmount = shipping.amount;
            estimate.shippingMessage = shipping.message;
            estimate.total = total;

            return estimate;

        } catch (Exception e) {
            throw new AuraHandledException('Error calculating estimate: ' + e.getMessage());
        }
    }

    /**
     * Gets decoration price map from custom metadata
     */
    private static Map<String, Decimal> getDecorationPriceMap() {
        Map<String, Decimal> priceMap = new Map<String, Decimal>();

        for (Decoration_Price__mdt deco : [
            SELECT Placement__c, Flat_UpCharge__c
            FROM Decoration_Price__mdt
        ]) {
            priceMap.put(deco.Placement__c, deco.Flat_UpCharge__c);
        }

        return priceMap;
    }

    /**
     * Applies quantity-based discounts
     * @param basePrice Base unit price
     * @param quantity Quantity ordered
     * @return Discounted unit price
     */
    private static Decimal applyQuantityDiscount(Decimal basePrice, Integer quantity) {
        // Quantity discount tiers
        // This is a simplified example - in production, you might query PricebookEntry or custom discount rules
        Decimal discount = 0;

        if (quantity >= 5760) {
            discount = 0.20; // 20% off
        } else if (quantity >= 2880) {
            discount = 0.15; // 15% off
        } else if (quantity >= 1008) {
            discount = 0.12; // 12% off
        } else if (quantity >= 576) {
            discount = 0.10; // 10% off
        } else if (quantity >= 288) {
            discount = 0.08; // 8% off
        } else if (quantity >= 144) {
            discount = 0.05; // 5% off
        }

        return basePrice * (1 - discount);
    }

    /**
     * Calculates shipping based on ZIP code and quantity
     * @param zipCode 5-digit ZIP code
     * @param quantity Quantity ordered
     * @return ShippingCalculation with amount and message
     */
    private static ShippingCalculation calculateShipping(String zipCode, Integer quantity) {
        ShippingCalculation result = new ShippingCalculation();

        // Validate ZIP code format
        if (String.isBlank(zipCode) || !Pattern.matches('^\\d{5}$', zipCode)) {
            result.amount = 0;
            result.message = 'ZIP code invalid or not provided. Shipping not included.';
            return result;
        }

        // Get first digit of ZIP for zone calculation
        Integer firstDigit = Integer.valueOf(zipCode.substring(0, 1));

        Decimal baseShipping = 0;
        Decimal perUnitShipping = 0;

        // Zone-based shipping rates
        if (firstDigit >= 0 && firstDigit <= 3) {
            // Zone A (East Coast)
            baseShipping = 25.00;
            perUnitShipping = 0.15;
        } else if (firstDigit >= 4 && firstDigit <= 6) {
            // Zone B (Central)
            baseShipping = 35.00;
            perUnitShipping = 0.20;
        } else if (firstDigit >= 7 && firstDigit <= 9) {
            // Zone C (West Coast)
            baseShipping = 45.00;
            perUnitShipping = 0.25;
        }

        Decimal calculatedShipping = baseShipping + (perUnitShipping * quantity);

        // Apply min/max caps
        Decimal minShipping = 12.00;
        Decimal maxShipping = 250.00;

        result.amount = Math.max(minShipping, Math.min(maxShipping, calculatedShipping));
        result.message = 'Shipping to ZIP ' + zipCode;

        return result;
    }

    // Wrapper classes

    public class DecorationOption {
        @AuraEnabled public String placement { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Decimal upcharge { get; set; }

        public DecorationOption(String placement, String label, Decimal upcharge) {
            this.placement = placement;
            this.label = label;
            this.upcharge = upcharge;
        }
    }

    public class PriceEstimate {
        @AuraEnabled public Decimal basePrice { get; set; }
        @AuraEnabled public Decimal discountedPrice { get; set; }
        @AuraEnabled public Integer quantity { get; set; }
        @AuraEnabled public Decimal mainDecorationCharge { get; set; }
        @AuraEnabled public Decimal additionalDecorationCharge { get; set; }
        @AuraEnabled public Decimal perUnitPrice { get; set; }
        @AuraEnabled public Decimal subtotal { get; set; }
        @AuraEnabled public Decimal shippingAmount { get; set; }
        @AuraEnabled public String shippingMessage { get; set; }
        @AuraEnabled public Decimal total { get; set; }
    }

    private class ShippingCalculation {
        public Decimal amount { get; set; }
        public String message { get; set; }
    }
}
