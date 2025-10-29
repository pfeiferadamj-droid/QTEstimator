@isTest
private class QuickTurnEstimatorControllerTest {

    @testSetup
    static void setup() {
        // Create test product
        Product2 testProduct = new Product2(
            Name = 'Test Headwear',
            IsActive = true,
            UnitPrice__c = 10.00
        );
        insert testProduct;
    }

    @isTest
    static void testGetDecorationOptions() {
        // Test fetching decoration options
        Test.startTest();
        List<QuickTurnEstimatorController.DecorationOption> options =
            QuickTurnEstimatorController.getDecorationOptions();
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, options, 'Options should not be null');
        // Note: Actual count depends on custom metadata records
    }

    @isTest
    static void testCalculateEstimateBasic() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test basic calculation with minimum inputs
        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                72,
                'Center_Front',
                null,
                null
            );
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assertEquals(72, estimate.quantity, 'Quantity should match');
        System.assertNotEquals(null, estimate.total, 'Total should be calculated');
        System.assertEquals(0, estimate.shippingAmount, 'Shipping should be 0 without ZIP');
    }

    @isTest
    static void testCalculateEstimateWithAdditionalDecorations() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test calculation with additional decorations
        List<String> additionalDecorations = new List<String>{'Left_Side', 'Right_Side'};

        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                144,
                'Center_Front',
                additionalDecorations,
                null
            );
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assertEquals(144, estimate.quantity, 'Quantity should match');
        System.assert(estimate.additionalDecorationCharge > 0, 'Additional decoration charge should be greater than 0');
    }

    @isTest
    static void testCalculateEstimateWithShipping() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test calculation with valid ZIP code
        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                288,
                'Center_Front',
                null,
                '10001' // Zone A ZIP
            );
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assert(estimate.shippingAmount > 0, 'Shipping should be calculated for valid ZIP');
        System.assert(estimate.shippingMessage.contains('ZIP'), 'Shipping message should mention ZIP');
    }

    @isTest
    static void testCalculateEstimateWithInvalidZip() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test calculation with invalid ZIP code
        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                72,
                'Center_Front',
                null,
                'ABC' // Invalid ZIP
            );
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assertEquals(0, estimate.shippingAmount, 'Shipping should be 0 for invalid ZIP');
        System.assert(estimate.shippingMessage.contains('invalid'), 'Message should indicate invalid ZIP');
    }

    @isTest
    static void testCalculateEstimateQuantityDiscount() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test calculation with high quantity to trigger discount
        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                2880, // High quantity for discount
                'Center_Front',
                null,
                null
            );
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assert(estimate.discountedPrice < estimate.basePrice, 'Discounted price should be less than base price');
    }

    @isTest
    static void testCalculateEstimateInvalidQuantity() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test with quantity below minimum
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                50, // Below MOQ
                'Center_Front',
                null,
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Minimum'), 'Error should mention minimum quantity');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for invalid quantity');
    }

    @isTest
    static void testCalculateEstimateMissingDecoration() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test with missing main decoration
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                72,
                '', // Empty decoration
                null,
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('decoration'), 'Error should mention decoration');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for missing decoration');
    }

    @isTest
    static void testShippingZones() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test different shipping zones
        List<String> zipCodes = new List<String>{'10001', '50001', '90001'}; // Zone A, B, C
        List<Decimal> shippingAmounts = new List<Decimal>();

        Test.startTest();
        for (String zip : zipCodes) {
            QuickTurnEstimatorController.PriceEstimate estimate =
                QuickTurnEstimatorController.calculateEstimate(
                    product.Id,
                    72,
                    'Center_Front',
                    null,
                    zip
                );
            shippingAmounts.add(estimate.shippingAmount);
        }
        Test.stopTest();

        // Verify different zones have different rates
        System.assertNotEquals(shippingAmounts[0], shippingAmounts[1], 'Zone A and B should have different rates');
        System.assertNotEquals(shippingAmounts[1], shippingAmounts[2], 'Zone B and C should have different rates');
    }

    @isTest
    static void testCompleteScenario() {
        // Get test product
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        // Test complete scenario with all features
        List<String> additionalDecorations = new List<String>{'Left_Side'};

        Test.startTest();
        QuickTurnEstimatorController.PriceEstimate estimate =
            QuickTurnEstimatorController.calculateEstimate(
                product.Id,
                576, // Mid-tier quantity for discount
                'Center_Front',
                additionalDecorations,
                '12345' // Zone A ZIP
            );
        Test.stopTest();

        // Verify all components are calculated
        System.assertNotEquals(null, estimate, 'Estimate should not be null');
        System.assertEquals(576, estimate.quantity, 'Quantity should match');
        System.assert(estimate.mainDecorationCharge > 0, 'Main decoration charge should be present');
        System.assert(estimate.additionalDecorationCharge > 0, 'Additional decoration charge should be present');
        System.assert(estimate.shippingAmount > 0, 'Shipping should be calculated');
        System.assert(estimate.total > 0, 'Total should be calculated');

        // Verify total calculation
        Decimal expectedTotal = estimate.subtotal + estimate.shippingAmount;
        System.assertEquals(expectedTotal, estimate.total, 'Total should equal subtotal + shipping');
    }
}
