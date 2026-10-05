import { createElement } from 'lwc';
import VeCommercialSummary from 'c/veCommercialSummary';
import getSummary from '@salesforce/apex/VECommercialSummaryController.getSummary';

jest.mock(
    '@salesforce/apex/VECommercialSummaryController.getSummary',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

const flushPromises = () => Promise.resolve();

const SUMMARY_WITH_QUOTE = {
    opportunityName: 'VoltEdge Demo Opportunity',
    currencyIsoCode: 'USD',
    totalContractValue: 125000,
    recurringTcv: 45000,
    arr: 18000,
    mrr: 1500,
    oneTimeRevenue: 80000,
    hasQuote: true,
    quoteId: '0Q0000000000001AAA',
    quoteName: 'Q-00042',
    quoteStatus: 'Draft',
    approvalStatus: 'Approved',
    maximumLineDiscount: 25,
    commercialRevision: 3
};

describe('c-ve-commercial-summary', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders commercial metrics and latest Quote governance', async () => {
        const element = createElement('c-ve-commercial-summary', {
            is: VeCommercialSummary
        });
        element.recordId = '006000000000001AAA';
        document.body.appendChild(element);

        getSummary.emit(SUMMARY_WITH_QUOTE);
        await flushPromises();

        expect(element.shadowRoot.querySelectorAll('.metric-tile')).toHaveLength(5);
        expect(element.shadowRoot.textContent).toContain('Q-00042');
        expect(element.shadowRoot.textContent).toContain('Approved');
        expect(element.shadowRoot.textContent).toContain('25.00%');
        expect(element.shadowRoot.textContent).toContain('3');

        const approvalStatus = element.shadowRoot.querySelector('[data-testid="approval-status"]');
        const maximumDiscount = element.shadowRoot.querySelector('[data-testid="maximum-line-discount"]');

        expect(approvalStatus.classList.contains('slds-theme_success')).toBe(true);
        expect(maximumDiscount.classList.contains('discount-critical')).toBe(true);
    });

    it('highlights approval-required discounts as warning governance states', async () => {
        const element = createElement('c-ve-commercial-summary', {
            is: VeCommercialSummary
        });
        element.recordId = '006000000000003AAA';
        document.body.appendChild(element);

        getSummary.emit({
            ...SUMMARY_WITH_QUOTE,
            approvalStatus: 'Required',
            maximumLineDiscount: 18
        });
        await flushPromises();

        const approvalStatus = element.shadowRoot.querySelector('[data-testid="approval-status"]');
        const maximumDiscount = element.shadowRoot.querySelector('[data-testid="maximum-line-discount"]');

        expect(approvalStatus.classList.contains('slds-theme_warning')).toBe(true);
        expect(maximumDiscount.classList.contains('discount-warning')).toBe(true);
        expect(maximumDiscount.textContent).toContain('18.00%');
    });

    it('renders a graceful state when the Opportunity has no Quote', async () => {
        const element = createElement('c-ve-commercial-summary', {
            is: VeCommercialSummary
        });
        element.recordId = '006000000000002AAA';
        document.body.appendChild(element);

        getSummary.emit({
            ...SUMMARY_WITH_QUOTE,
            hasQuote: false,
            quoteId: null,
            quoteName: null,
            quoteStatus: null,
            approvalStatus: null,
            maximumLineDiscount: null,
            commercialRevision: null
        });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain(
            'No Quote is currently linked to this Opportunity.'
        );
    });
});
