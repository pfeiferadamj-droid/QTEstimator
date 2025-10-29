import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getDecorationOptions from '@salesforce/apex/QuickTurnEstimatorController.getDecorationOptions';
import calculateEstimate from '@salesforce/apex/QuickTurnEstimatorController.calculateEstimate';

// Product2 fields to fetch
const PRODUCT_FIELDS = [
    'Product2.Id',
    'Product2.Name',
    'Product2.UnitPrice__c'
];

// Valid quantity options (MOQ = 72, then specific increments)
const QUANTITY_OPTIONS = [72, 96, 144, 288, 432, 576, 1008, 2880, 5760];

export default class QuickTurnHeadwearEstimator extends LightningElement {
    @api recordId; // Product2 record ID from page context
    @api productName; // Optional override

    @track decorationOptions = [];
    @track selectedMainDecoration = '';
    @track selectedAdditionalDecorations = [];
    @track quantity = 72;
    @track zipCode = '';
    @track estimate = null;
    @track error = null;
    @track isLoading = false;

    // Wire to fetch product details
    @wire(getRecord, { recordId: '$recordId', fields: PRODUCT_FIELDS })
    product;

    // Wire to fetch decoration options
    @wire(getDecorationOptions)
    wiredDecorationOptions({ error, data }) {
        if (data) {
            this.decorationOptions = data.map(option => ({
                ...option,
                value: option.placement
            }));
            this.error = null;

            // Auto-select first option as default main decoration
            if (this.decorationOptions.length > 0 && !this.selectedMainDecoration) {
                this.selectedMainDecoration = this.decorationOptions[0].placement;
                this.calculatePrice();
            }
        } else if (error) {
            this.error = 'Error loading decoration options: ' + this.reduceErrors(error);
            this.decorationOptions = [];
        }
    }

    // Computed properties

    get quantityOptions() {
        return QUANTITY_OPTIONS.map(qty => ({
            label: qty.toLocaleString(),
            value: qty
        }));
    }

    get mainDecorationOptions() {
        return this.decorationOptions.map(option => ({
            label: `${option.label} (+$${option.upcharge.toFixed(2)})`,
            value: option.placement
        }));
    }

    get additionalDecorationOptions() {
        // Exclude main decoration from additional options
        return this.decorationOptions
            .filter(option => option.placement !== this.selectedMainDecoration)
            .map(option => ({
                label: `${option.label} (+$${option.upcharge.toFixed(2)})`,
                value: option.placement
            }));
    }

    get canSelectAdditionalDecorations() {
        return this.selectedAdditionalDecorations.length < 2;
    }

    get additionalDecorationsDisabled() {
        return !this.canSelectAdditionalDecorations;
    }

    get productDisplayName() {
        if (this.productName) {
            return this.productName;
        }
        if (this.product && this.product.data) {
            return this.product.data.fields.Name.value;
        }
        return 'Product';
    }

    get hasEstimate() {
        return this.estimate !== null;
    }

    get formattedBasePrice() {
        return this.estimate ? this.formatCurrency(this.estimate.basePrice) : '$0.00';
    }

    get formattedDiscountedPrice() {
        return this.estimate ? this.formatCurrency(this.estimate.discountedPrice) : '$0.00';
    }

    get formattedMainDecorationCharge() {
        return this.estimate ? this.formatCurrency(this.estimate.mainDecorationCharge) : '$0.00';
    }

    get formattedAdditionalDecorationCharge() {
        return this.estimate ? this.formatCurrency(this.estimate.additionalDecorationCharge) : '$0.00';
    }

    get formattedPerUnitPrice() {
        return this.estimate ? this.formatCurrency(this.estimate.perUnitPrice) : '$0.00';
    }

    get formattedSubtotal() {
        return this.estimate ? this.formatCurrency(this.estimate.subtotal) : '$0.00';
    }

    get formattedShipping() {
        return this.estimate ? this.formatCurrency(this.estimate.shippingAmount) : '$0.00';
    }

    get formattedTotal() {
        return this.estimate ? this.formatCurrency(this.estimate.total) : '$0.00';
    }

    get hasQuantityDiscount() {
        return this.estimate && this.estimate.discountedPrice < this.estimate.basePrice;
    }

    get quantityDiscountAmount() {
        if (this.hasQuantityDiscount) {
            const discount = (this.estimate.basePrice - this.estimate.discountedPrice) * this.quantity;
            return this.formatCurrency(discount);
        }
        return '$0.00';
    }

    get hasAdditionalDecorations() {
        return this.estimate && this.estimate.additionalDecorationCharge > 0;
    }

    get hasShipping() {
        return this.estimate && this.estimate.shippingAmount > 0;
    }

    get shippingMessage() {
        return this.estimate ? this.estimate.shippingMessage : '';
    }

    // Event handlers

    handleQuantityChange(event) {
        this.quantity = parseInt(event.detail.value, 10);
        this.calculatePrice();
    }

    handleMainDecorationChange(event) {
        const previousMain = this.selectedMainDecoration;
        this.selectedMainDecoration = event.detail.value;

        // If the new main decoration was in additional decorations, remove it
        this.selectedAdditionalDecorations = this.selectedAdditionalDecorations.filter(
            deco => deco !== this.selectedMainDecoration
        );

        this.calculatePrice();
    }

    handleAdditionalDecorationsChange(event) {
        this.selectedAdditionalDecorations = event.detail.value;

        // Enforce max 2 additional decorations
        if (this.selectedAdditionalDecorations.length > 2) {
            this.selectedAdditionalDecorations = this.selectedAdditionalDecorations.slice(0, 2);
        }

        this.calculatePrice();
    }

    handleZipCodeChange(event) {
        this.zipCode = event.target.value;

        // Auto-calculate when ZIP is 5 digits
        if (this.zipCode.length === 5) {
            this.calculatePrice();
        } else if (this.zipCode.length === 0) {
            // Recalculate without shipping if ZIP is cleared
            this.calculatePrice();
        }
    }

    handleCalculate() {
        this.calculatePrice();
    }

    // Calculation method

    async calculatePrice() {
        // Validate inputs
        if (!this.recordId) {
            this.error = 'Product record ID is required.';
            return;
        }

        if (!this.selectedMainDecoration) {
            this.error = 'Please select a main decoration placement.';
            return;
        }

        this.isLoading = true;
        this.error = null;

        try {
            const result = await calculateEstimate({
                productId: this.recordId,
                quantity: this.quantity,
                mainDecoration: this.selectedMainDecoration,
                additionalDecorations: this.selectedAdditionalDecorations,
                zipCode: this.zipCode
            });

            this.estimate = result;
            this.error = null;

        } catch (error) {
            this.error = 'Error calculating estimate: ' + this.reduceErrors(error);
            this.estimate = null;
        } finally {
            this.isLoading = false;
        }
    }

    // Utility methods

    formatCurrency(value) {
        if (value === null || value === undefined) {
            return '$0.00';
        }
        return '$' + parseFloat(value).toFixed(2);
    }

    reduceErrors(errors) {
        if (!errors) {
            return 'Unknown error';
        }

        if (Array.isArray(errors)) {
            return errors.map(e => e.message).join(', ');
        }

        if (typeof errors === 'string') {
            return errors;
        }

        if (errors.body) {
            if (Array.isArray(errors.body)) {
                return errors.body.map(e => e.message).join(', ');
            }
            if (errors.body.message) {
                return errors.body.message;
            }
        }

        if (errors.message) {
            return errors.message;
        }

        return JSON.stringify(errors);
    }
}
