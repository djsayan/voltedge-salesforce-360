import { LightningElement, api, wire } from 'lwc';
import getSummary from '@salesforce/apex/VECommercialSummaryController.getSummary';

export default class VeCommercialSummary extends LightningElement {
    @api recordId;

    summary;
    error;
    isLoading = true;

    @wire(getSummary, { opportunityId: '$recordId' })
    wiredSummary({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.summary = data;
            this.error = undefined;
        } else if (error) {
            this.summary = undefined;
            this.error = error;
        }
    }

    get quoteUrl() {
        return this.summary?.quoteId ? `/lightning/r/Quote/${this.summary.quoteId}/view` : undefined;
    }

    get quoteStatusDisplay() {
        return this.summary?.quoteStatus || '—';
    }

    get approvalStatusDisplay() {
        return this.summary?.approvalStatus || '—';
    }

    get approvalStatusClass() {
        const status = this.summary?.approvalStatus;
        const baseClass = 'slds-badge approval-badge';

        switch (status) {
            case 'Approved':
                return `${baseClass} slds-theme_success`;
            case 'Rejected':
                return `${baseClass} slds-theme_error`;
            case 'Required':
            case 'Pending':
                return `${baseClass} slds-theme_warning`;
            case 'Not Required':
                return `${baseClass} slds-theme_shade`;
            default:
                return baseClass;
        }
    }

    get maximumLineDiscountDisplay() {
        const value = this.summary?.maximumLineDiscount;
        return value === null || value === undefined ? '—' : `${Number(value).toFixed(2)}%`;
    }

    get maximumLineDiscountClass() {
        const value = this.summary?.maximumLineDiscount;

        if (value === null || value === undefined) {
            return 'discount-value';
        }

        const numericValue = Number(value);

        if (numericValue >= 25) {
            return 'discount-value discount-critical';
        }

        if (numericValue >= 15) {
            return 'discount-value discount-warning';
        }

        return 'discount-value';
    }

    get commercialRevisionDisplay() {
        const value = this.summary?.commercialRevision;
        return value === null || value === undefined ? '—' : String(value);
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }

        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }

        return this.error.body?.message || this.error.message || 'Unable to load commercial summary.';
    }
}
