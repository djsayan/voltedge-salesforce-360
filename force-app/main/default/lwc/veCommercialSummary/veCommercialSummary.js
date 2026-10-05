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

    get maximumLineDiscountDisplay() {
        const value = this.summary?.maximumLineDiscount;
        return value === null || value === undefined ? '—' : `${Number(value).toFixed(2)}%`;
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
